import '../repositories/order_repository.dart';

class VerifyDeliveryOtpUseCase {
  final OrderRepository repository;
  VerifyDeliveryOtpUseCase(this.repository);

  /// Returns null on success, or a user-readable error message.
  Future<String?> call(String orderId, String otp) =>
      repository.verifyDeliveryOtp(orderId, otp);
}
