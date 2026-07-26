import '../entities/product.dart';
import '../repositories/product_repository.dart';

class UpdateProductUseCase {
  final ProductRepository repository;
  UpdateProductUseCase(this.repository);

  Future<void> call(Product product) {
    if (product.price <= 0) {
      throw ArgumentError('Product price must be greater than 0.');
    }
    if (product.physicalStock < 0 || product.reservedStock < 0) {
      throw ArgumentError('Product stock cannot be negative.');
    }
    return repository.updateProduct(product);
  }
}
