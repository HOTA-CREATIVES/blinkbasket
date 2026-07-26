import '../repositories/order_repository.dart';

class AcceptOrderUseCase {
  final OrderRepository repository;
  AcceptOrderUseCase(this.repository);

  Future<String?> call(String orderId) => repository.acceptOrder(orderId);
}
