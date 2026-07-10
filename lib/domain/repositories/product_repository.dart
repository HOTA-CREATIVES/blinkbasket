import '../entities/product.dart';

abstract class ProductRepository {
  Stream<List<Product>> streamProducts();
  Future<void> addProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);
}
