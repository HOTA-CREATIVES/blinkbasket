import '../repositories/order_repository.dart';

class UpdateOrderStatusUseCase {
  final OrderRepository repository;
  UpdateOrderStatusUseCase(this.repository);

  Future<void> call(String orderId, String status) => repository.updateOrderStatus(orderId, status);
}
