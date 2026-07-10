import '../repositories/order_repository.dart';

class AssignRiderUseCase {
  final OrderRepository repository;
  AssignRiderUseCase(this.repository);

  Future<void> call(String orderId, String riderId, String riderName) => repository.assignDeliveryBoy(orderId, riderId, riderName);
}
