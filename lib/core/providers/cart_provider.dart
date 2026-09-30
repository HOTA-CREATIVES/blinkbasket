import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/product_dto.dart';
import '../../data/repositories/firebase_cart_repository.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/cart_repository.dart';
import '../../domain/repositories/product_repository.dart';

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
      // Prune out-of-stock products. Fetched in parallel — a large cart
      // otherwise pays one round trip per item, sequentially.
      if (_productRepository != null && _items.isNotEmpty) {
        final repo = _productRepository;
        final entries = _items.entries.toList();
        final products = await Future.wait(
          entries.map((e) => repo.getProductById(e.key)),
        );
        final toRemove = <String>[];
        for (var i = 0; i < entries.length; i++) {
          final product = products[i];
          if (product == null || product.isOutOfStock) {
            toRemove.add(entries[i].key);
          } else if (entries[i].value.quantity > product.sellableStock) {
            entries[i].value.quantity = product.sellableStock;
          }
        }
        if (toRemove.isNotEmpty) {
          for (final id in toRemove) {
            _items.remove(id);
          }
          await _saveCart();
        }
      }
    } catch (e) {
      debugPrint('Error loading cart from Firestore: $e');
    } finally {
      _isLoaded = true;
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
