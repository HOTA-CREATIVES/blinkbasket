import '../entities/order.dart';
import '../repositories/order_repository.dart';

class StreamCustomerOrdersUseCase {
  final OrderRepository repository;
  StreamCustomerOrdersUseCase(this.repository);

  Stream<List<Order>> call(String customerId) => repository.streamCustomerOrders(customerId);
}
