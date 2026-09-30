import '../entities/rider_location.dart';
import '../repositories/order_repository.dart';

/// Moves a rider's order to its next step (picked up, out for delivery).
class AdvanceOrderStatusUseCase {
  final OrderRepository repository;
  AdvanceOrderStatusUseCase(this.repository);

  /// [nextStatus] is the status the rider expects to move to; the server
  /// rejects it if the order is no longer at the step before. Returns null on
  /// success, or a message for the rider.
  Future<String?> call(String orderId, String nextStatus, {RiderLocation? location}) =>
      repository.advanceOrderStatus(orderId, nextStatus, location: location);
}
