import '../entities/order.dart';
import '../repositories/order_repository.dart';

class StreamDeliveryOrdersUseCase {
  final OrderRepository repository;
  StreamDeliveryOrdersUseCase(this.repository);

  Stream<List<Order>> call(String deliveryBoyId) => repository.streamDeliveryBoyOrders(deliveryBoyId);
}
