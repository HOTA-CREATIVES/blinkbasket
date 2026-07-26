import '../entities/order.dart';
import '../repositories/order_repository.dart';

class PlaceOrderUseCase {
  final OrderRepository repository;
  PlaceOrderUseCase(this.repository);

  Future<PlaceOrderResult> call({
    required List<OrderItem> items,
    required String deliveryAddress,
    double? latitude,
    double? longitude,
  }) =>
      repository.placeOrder(
        items: items,
        deliveryAddress: deliveryAddress,
        latitude: latitude,
        longitude: longitude,
      );
}
