import '../entities/product.dart';
import '../repositories/product_repository.dart';

class StreamProductsUseCase {
  final ProductRepository repository;
  StreamProductsUseCase(this.repository);

  Stream<List<Product>> call() => repository.streamProducts();
}
