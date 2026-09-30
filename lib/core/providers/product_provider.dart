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
import '../utils/shared_stream.dart';
import '../utils/app_exception.dart';

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

  // A single, app-lifetime Firestore listener on the whole catalog, shared by
  // every screen. Late subscribers get the latest snapshot immediately, so they
  // don't sit on a spinner until the next catalog change, and rebuilding a
  // screen never opens another listener.
  late final SharedStream<List<Product>> _products =
      SharedStream(() => _streamProductsUseCase());

  ProductProvider({ProductRepository? repository})
      : _productRepository = repository ?? FirebaseProductRepository() {
    _streamProductsUseCase = StreamProductsUseCase(_productRepository);
    _addProductUseCase = AddProductUseCase(_productRepository);
    _updateProductUseCase = UpdateProductUseCase(_productRepository);
    _deleteProductUseCase = DeleteProductUseCase(_productRepository);
  }

  /// The shared catalog stream — the same instance on every call.
  Stream<List<Product>> streamProducts() => _products.stream;

  /// Retry action for the catalog error state.
  void retryProducts() => _products.reconnect();

  @override
  void dispose() {
    _products.dispose();
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
      _errorMessage = userMessageFor(e);
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
      _errorMessage = userMessageFor(e);
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
      _errorMessage = userMessageFor(e);
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
      _errorMessage = userMessageFor(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
