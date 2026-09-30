import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/inventory_ledger.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/stream_products_usecase.dart';
import '../../domain/usecases/add_product_usecase.dart';
import '../../domain/usecases/update_product_usecase.dart';
import '../../domain/usecases/delete_product_usecase.dart';
import '../../data/repositories/firebase_product_repository.dart';

class ProductProvider with ChangeNotifier {
  final ProductRepository _productRepository;

  late final StreamProductsUseCase _streamProductsUseCase;
  late final AddProductUseCase _addProductUseCase;
  late final UpdateProductUseCase _updateProductUseCase;
  late final DeleteProductUseCase _deleteProductUseCase;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // A single, app-lifetime Firestore listener on the whole catalog, fanned
  // out to every screen via a broadcast controller. Previously each
  // StreamBuilder that called streamProducts() attached its own
  // collection('products').snapshots() listener — re-downloading the entire
  // catalog per screen (and per rebuild on screens that called it in build()).
  StreamSubscription<List<Product>>? _productsSub;
  final StreamController<List<Product>> _productsController =
      StreamController<List<Product>>.broadcast();
  List<Product>? _latestProducts;

  ProductProvider({ProductRepository? repository})
      : _productRepository = repository ?? FirebaseProductRepository() {
    _streamProductsUseCase = StreamProductsUseCase(_productRepository);
    _addProductUseCase = AddProductUseCase(_productRepository);
    _updateProductUseCase = UpdateProductUseCase(_productRepository);
    _deleteProductUseCase = DeleteProductUseCase(_productRepository);
  }

  /// Shared catalog stream. All callers subscribe to one underlying Firestore
  /// listener; late subscribers replay the most recent snapshot immediately so
  /// they don't sit on a spinner until the next catalog change.
  Stream<List<Product>> streamProducts() async* {
    _ensureProductsSubscription();
    if (_latestProducts != null) yield _latestProducts!;
    yield* _productsController.stream;
  }

  void _ensureProductsSubscription() {
    _productsSub ??= _streamProductsUseCase().listen(
      (products) {
        _latestProducts = products;
        _productsController.add(products);
      },
      onError: (Object error, StackTrace stack) {
        _productsController.addError(error, stack);
        // A failed Firestore listener never recovers by itself — drop it so
        // the next streamProducts() call (i.e. the next rebuild) reconnects.
        _productsSub?.cancel();
        _productsSub = null;
        _latestProducts = null;
      },
    );
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    _productsController.close();
    super.dispose();
  }

  /// One-off live lookup (current price/stock), for flows like reorder that
  /// must not trust a possibly stale snapshot.
  Future<Product?> getProductById(String id) => _productRepository.getProductById(id);

  Future<bool> addProduct(Product product) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _addProductUseCase(product);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _updateProductUseCase(product);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _deleteProductUseCase(id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Stream<List<InventoryLedger>> streamInventoryLogs(String productId) {
    return _productRepository.streamInventoryLogs(productId);
  }

  Stream<List<InventoryLedger>> streamAllInventoryLogs({int limit = 50}) {
    return _productRepository.streamAllInventoryLogs(limit: limit);
  }

  Future<bool> adjustStock({
    required String productId,
    required int physicalDelta,
    required int reservedDelta,
    required String changeType,
    required String notes,
    required String adminId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _productRepository.adjustStock(
        productId: productId,
        physicalDelta: physicalDelta,
        reservedDelta: reservedDelta,
        changeType: changeType,
        notes: notes,
        adminId: adminId,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
