import '../entities/product.dart';
import '../entities/inventory_ledger.dart';

abstract class ProductRepository {
  Stream<List<Product>> streamProducts();
  /// Fetches the current state of a single product (live price/stock),
  /// or null if it no longer exists. Used by reorder.
  Future<Product?> getProductById(String id);
  Future<void> addProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);

  Stream<List<InventoryLedger>> streamInventoryLogs(String productId, {int limit = 200});
  Stream<List<InventoryLedger>> streamAllInventoryLogs({int limit = 50});
  Future<void> adjustStock({
    required String productId,
    required int physicalDelta,
    required int reservedDelta,
    required String changeType,
    required String notes,
    required String adminId,
  });
}
