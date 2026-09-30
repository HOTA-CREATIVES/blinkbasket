import '../repositories/order_repository.dart';

class RejectOrderOfferUseCase {
  final OrderRepository repository;
  RejectOrderOfferUseCase(this.repository);

  Future<String?> call(String orderId) => repository.rejectOrderOffer(orderId);
}
