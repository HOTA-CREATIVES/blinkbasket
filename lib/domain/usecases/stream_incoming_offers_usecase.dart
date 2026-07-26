import '../entities/order.dart';
import '../repositories/order_repository.dart';

class StreamIncomingOffersUseCase {
  final OrderRepository repository;
  StreamIncomingOffersUseCase(this.repository);

  Stream<List<Order>> call({int limit = 30}) => repository.streamIncomingOffers(limit: limit);
}
