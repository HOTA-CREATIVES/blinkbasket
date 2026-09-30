import '../repositories/order_repository.dart';
import '../entities/rider_location.dart';

class VerifyDeliveryOtpUseCase {
  final OrderRepository repository;
  VerifyDeliveryOtpUseCase(this.repository);

  /// [collectedAmount] is the cash the rider confirms taking from the
  /// customer; the server requires it to equal the order total.
  /// Returns null on success, or a user-readable error message.
  Future<String?> call(String orderId, String otp, double collectedAmount,
          {RiderLocation? location}) =>
      repository.verifyDeliveryOtp(orderId, otp, collectedAmount, location: location);
}
