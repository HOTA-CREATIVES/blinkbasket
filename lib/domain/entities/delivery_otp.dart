/// The 4-digit code a customer gives the rider to complete a delivery.
class DeliveryOtp {
  final String code;

  /// When the code stops working, or null while it has no expiry (before the
  /// order is out for delivery, and on orders that predate expiry).
  final DateTime? expiresAt;

  const DeliveryOtp({required this.code, this.expiresAt});

  bool isExpiredAt(DateTime now) => expiresAt != null && expiresAt!.isBefore(now);
}
