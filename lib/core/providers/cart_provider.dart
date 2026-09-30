import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/product_dto.dart';
import '../../data/repositories/firebase_cart_repository.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/cart_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../utils/money.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'product': ProductDto.fromEntity(product).toMap()..['id'] = product.id,
      'quantity': quantity,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    final prodMap = Map<String, dynamic>.from(map['product'] ?? {});
    final id = prodMap['id'] as String? ?? '';
    final product = ProductDto.fromMap(prodMap, id);
    return CartItem(
      product: product,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

enum CartChangeKind { priceChanged, quantityReduced, removed }

/// One difference between the cart the customer built and what the shop offers
/// now — a price that moved, stock that ran down, or an item that is gone.
class CartChange {
  final CartChangeKind kind;
  final String productName;
  final double? oldPrice;
  final double? newPrice;
  final int? newQuantity;

  const CartChange.priceChanged({
    required this.productName,
    required double this.oldPrice,
    required double this.newPrice,
  })  : kind = CartChangeKind.priceChanged,
        newQuantity = null;

  const CartChange.quantityReduced({
    required this.productName,
    required int this.newQuantity,
  })  : kind = CartChangeKind.quantityReduced,
        oldPrice = null,
        newPrice = null;

  const CartChange.removed({required this.productName})
      : kind = CartChangeKind.removed,
        oldPrice = null,
        newPrice = null,
        newQuantity = null;

  /// One line for the customer.
  String get message {
    switch (kind) {
      case CartChangeKind.priceChanged:
        return '$productName: price changed from ${formatRupees(oldPrice!)} to ${formatRupees(newPrice!)}';
      case CartChangeKind.quantityReduced:
        return '$productName: only $newQuantity available, quantity reduced';
      case CartChangeKind.removed:
        return '$productName: no longer available, removed from your cart';
    }
  }
}

/// Result of checking the cart against the live catalogue.
class CartValidation {
  /// What changed (already applied to the cart).
  final List<CartChange> changes;

  /// True when at least one product could not be looked up (offline, error).
  /// Nothing was removed for those; the server re-checks at order time.
  final bool couldNotVerify;

  const CartValidation({this.changes = const [], this.couldNotVerify = false});

  bool get isClean => changes.isEmpty;
}

/// Cart persisted to Firestore only. Firestore offline persistence (enabled
/// in main.dart) handles offline reads/writes — the local cache is managed
/// by the SDK, not SharedPreferences. This eliminates the dual-source
/// desync bug where local cart and Firestore cart could diverge.
class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  String? _currentUserId;
  bool _isLoaded = false;
  final ProductRepository? _productRepository;
  final CartRepository _cartRepository;

  /// Debounce timer to coalesce rapid cart mutations into a single Firestore
  /// write, preventing last-write-wins races from concurrent _saveCart calls.
  Timer? _saveDebounce;

  /// Completer for the in-flight save so [clearCart] can await persistence.
  Completer<void>? _pendingSave;

  CartProvider({ProductRepository? productRepository, CartRepository? cartRepository})
      : _productRepository = productRepository,
        _cartRepository = cartRepository ?? FirebaseCartRepository() {
    loadCart();
  }

  Map<String, CartItem> get items => {..._items};

  final List<CartChange> _pendingChanges = [];
  bool _isValidating = false;

  /// Changes found while loading the cart, waiting for the customer to see
  /// them (the cart screen shows and then dismisses them).
  List<CartChange> get pendingChanges => List.unmodifiable(_pendingChanges);

  void dismissPendingChanges() {
    if (_pendingChanges.isEmpty) return;
    _pendingChanges.clear();
    notifyListeners();
  }

  /// True while [revalidate] is talking to the server.
  bool get isValidating => _isValidating;

  int quantityOf(String productId) => _items[productId]?.quantity ?? 0;

  int get itemCount => _items.values.fold(0, (acc, item) => acc + item.quantity);

  double get totalAmount => _items.values.fold(0.0, (acc, item) => acc + (item.product.effectivePrice * item.quantity));

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  /// Called by the auth layer when the user signs in/out so the cart is
  /// scoped to the right user. Replaces the old direct FirebaseAuth listener
  /// to respect clean architecture boundaries.
  Future<void> setUser(String? userId) async {
    if (userId == null && _items.isNotEmpty) {
      _items.clear();
      _pendingChanges.clear();
      _isLoaded = false;
      _currentUserId = null;
      notifyListeners();
      return;
    }
    if (_currentUserId == userId && _isLoaded) return;
    _currentUserId = userId;
    _isLoaded = false;
    await loadCart();
  }

  /// Loads cart from Firestore. With offline persistence enabled, this
  /// returns cached data instantly when offline.
  Future<void> loadCart([String? userId]) async {
    if (userId != null) {
      _currentUserId = userId;
    }
    try {
      _items.clear();
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        final remoteCart = await _cartRepository.getCart(_currentUserId!);
        remoteCart?.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _items[key] = CartItem.fromMap(value);
          }
        });
      }
      // Refresh prices/stock from the live catalogue and prune what is gone.
      // Anything that changed is kept for the cart screen to tell the customer.
      final result = await _applyLiveProducts();
      if (result.changes.isNotEmpty) {
        _pendingChanges
          ..clear()
          ..addAll(result.changes);
      }
    } catch (e) {
      debugPrint('Error loading cart from Firestore: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Compares every cart line with the live product: refreshes the stored
  /// price/stock snapshot, lowers quantities to what is available, and removes
  /// products that are gone or switched off. Persists if anything changed.
  Future<CartValidation> _applyLiveProducts() async {
    final repo = _productRepository;
    if (repo == null || _items.isEmpty) return const CartValidation();

    final entries = _items.entries.toList();
    var couldNotVerify = false;
    final live = await Future.wait(entries.map((e) async {
      try {
        return (ok: true, product: await repo.getProductById(e.key));
      } catch (_) {
        couldNotVerify = true;
        return (ok: false, product: null as Product?);
      }
    }));

    final changes = <CartChange>[];
    var mutated = false;
    for (var i = 0; i < entries.length; i++) {
      final id = entries[i].key;
      final line = entries[i].value;
      final fetched = live[i];
      if (!fetched.ok) continue; // can't tell: leave the line as it is
      final fresh = fetched.product;

      if (fresh == null || fresh.isOutOfStock) {
        changes.add(CartChange.removed(productName: line.product.name));
        _items.remove(id);
        mutated = true;
        continue;
      }
      final oldPrice = line.product.effectivePrice;
      var quantity = line.quantity;
      if (quantity > fresh.sellableStock) {
        quantity = fresh.sellableStock;
        changes.add(CartChange.quantityReduced(
            productName: fresh.name, newQuantity: quantity));
      }
      if (fresh.effectivePrice != oldPrice) {
        changes.add(CartChange.priceChanged(
          productName: fresh.name,
          oldPrice: oldPrice,
          newPrice: fresh.effectivePrice,
        ));
      }
      // Always store the fresh snapshot so totals use today's price and stock.
      _items[id] = CartItem(product: fresh, quantity: quantity);
      if (quantity != line.quantity || fresh.effectivePrice != oldPrice) mutated = true;
    }

    if (mutated) await _saveCart();
    return CartValidation(changes: changes, couldNotVerify: couldNotVerify);
  }

  /// Checks the cart against the live catalogue right now (before checkout or
  /// placing an order) so the customer sees today's prices and availability,
  /// and is told what changed. Prices are re-checked by the server at order
  /// time regardless; this makes that check unsurprising.
  Future<CartValidation> revalidate() async {
    if (_isValidating) return const CartValidation();
    _isValidating = true;
    notifyListeners();
    try {
      final result = await _applyLiveProducts();
      _pendingChanges.clear();
      return result;
    } finally {
      _isValidating = false;
      notifyListeners();
    }
  }

  Future<void> _saveCart() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      final Map<String, dynamic> rawMap = {};
      _items.forEach((key, item) {
        rawMap[key] = item.toMap();
      });
      await _cartRepository.saveCart(_currentUserId!, rawMap);
    } catch (e) {
      debugPrint('Error saving cart to Firestore: $e');
    }
  }

  /// Debounced save — coalesces rapid taps into a single write.
  void _scheduleSave() {
    _saveDebounce?.cancel();
    _pendingSave = Completer<void>();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _saveCart();
      _pendingSave?.complete();
      _pendingSave = null;
    });
  }

  /// Returns `true` if the item was added, `false` if stock is insufficient.
  bool addItem(Product product) {
    final currentQty = _items[product.id]?.quantity ?? 0;
    if (currentQty + 1 > product.sellableStock) {
      return false; // Stock exceeded — caller should show a message
    }
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity += 1;
    } else {
      _items[product.id] = CartItem(product: product);
    }
    notifyListeners();
    _scheduleSave();
    return true;
  }

  /// Returns `true` if the quantity was added, `false` if stock is insufficient.
  bool addItemQuantity(Product product, int quantity) {
    if (quantity <= 0) return false;
    final currentQty = _items[product.id]?.quantity ?? 0;
    if (currentQty + quantity > product.sellableStock) {
      return false; // Stock exceeded — caller should show a message
    }
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity += quantity;
    } else {
      _items[product.id] = CartItem(product: product, quantity: quantity);
    }
    notifyListeners();
    _scheduleSave();
    return true;
  }

  void decrementItem(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items[productId]!.quantity -= 1;
    } else {
      _items.remove(productId);
    }
    notifyListeners();
    _scheduleSave();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
    _scheduleSave();
  }

  /// Clears the cart and awaits persistence so the caller (e.g. checkout)
  /// can be sure the empty cart is committed before navigating away.
  Future<void> clearCart() async {
    _saveDebounce?.cancel();
    _items.clear();
    notifyListeners();
    await _saveCart();
  }
}
