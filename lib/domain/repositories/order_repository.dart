import '../entities/order.dart';
import '../../core/models/user_model.dart';

/// Result of a server-side order placement via the placeOrder Cloud Function.
class PlaceOrderResult {
  final bool isSuccess;
  final String? orderId;
  final String? otp;

  /// Server-computed grand total (subtotal + delivery fee). The client's own
  /// cart total is only a preview; show this one once the order exists.
  final double? totalAmount;
  final String? errorMessage;

  const PlaceOrderResult.success({
    required this.orderId,
    required this.otp,
    this.totalAmount,
  })  : isSuccess = true,
        errorMessage = null;

  const PlaceOrderResult.failure(this.errorMessage)
      : isSuccess = false,
        orderId = null,
        otp = null,
        totalAmount = null;
}

abstract class OrderRepository {
  Stream<Order> streamOrder(String orderId);
  Stream<List<Order>> streamCustomerOrders(String customerId);
  Stream<List<Order>> streamDeliveryBoyOrders(String deliveryBoyId);
  /// [limit] bounds admin-console read cost as order history grows —
  /// the queue only needs recent orders, not the full lifetime history.
  Stream<List<Order>> streamAllOrders({int limit = 300});
  Stream<List<UserModel>> streamAllDeliveryBoys({int limit = 200});

  /// Blinkit-style broadcast feed: pending orders not yet claimed by any
  /// rider. Any on-duty rider may stream and accept from this — visibility
  /// isn't restricted to their village (see firestore.rules), only the
  /// push-notification priority is. Backed by the PII-free /orderOffers copy:
  /// the returned orders carry a first name and village but no phone, street
  /// address or GPS pin. The full order is readable only after acceptOrder.
  Stream<List<Order>> streamIncomingOffers({int limit = 30});

  /// Places an order through the placeOrder Cloud Function. The server
  /// re-prices items, checks stock, and generates the delivery OTP.
  ///
  /// [requestId] makes the call idempotent: retrying with the same id after a
  /// lost response returns the order that was already created.
  Future<PlaceOrderResult> placeOrder({
    required List<OrderItem> items,
    required String deliveryAddress,
    String? deliveryInstructions,
    double? latitude,
    double? longitude,
    String? requestId,
  });

  /// Cancels a customer order while in 'pending' or 'assigned' state.
  /// Returns null on success, or an error message string on failure.
  Future<String?> cancelOrder(String orderId, {String? reason});

  /// Verifies the customer's delivery OTP via the verifyDeliveryOtp Cloud
  /// Function and records the cash the rider confirms collecting
  /// ([collectedAmount] must equal the order total). Returns null on success,
  /// or a user-readable error message.
  Future<String?> verifyDeliveryOtp(String orderId, String otp, double collectedAmount);

  /// Reads the delivery OTP for one of the customer's own orders.
  /// Only callable by the ordering customer (Firestore rules enforce this).
  /// Riders must get the OTP verbally from the customer.
  Future<String?> getOrderOtp(String orderId);

  Future<void> updateOrderStatus(String orderId, String status);

  /// Customer-submitted 1-5 star rating for a delivered order. Write-once,
  /// enforced by Firestore rules (rejected if the order isn't 'delivered'
  /// or already has a rating).
  Future<void> submitOrderRating(String orderId, int rating, String? comment);

  /// Rider claims a pending, unassigned order via the acceptOrder Cloud
  /// Function — the only way an order is ever assigned now that manual
  /// admin assignment has been replaced by this broadcast/accept flow.
  /// Returns null on success, or a user-readable error message (e.g. if
  /// another rider already accepted it first).
  Future<String?> acceptOrder(String orderId);

  /// Rider reports that an assigned/picked-up/out-for-delivery order could
  /// not be handed over (customer unreachable, refused COD, bad address).
  /// The only way to get such an order out of an in-progress state — there
  /// is no other path back once a rider has accepted it besides delivering
  /// it. Returns null on success, or a user-readable error message.
  Future<String?> reportDeliveryFailure(String orderId, String reason);

  /// Admin-only: cancels an order that is still active. Reserved stock is
  /// released server-side by the order trigger. Returns null on success, or a
  /// user-readable error message.
  Future<String?> adminCancelOrder(String orderId, String adminId, String reason);

  /// Admin-only: takes an assigned / picked-up / out-for-delivery order away
  /// from its rider and returns it to the pending pool, where the broadcast
  /// re-offers it to riders. For a rider who went dark after accepting.
  Future<String?> adminUnassignOrder(String orderId);

  /// Admin-only: clears the delivery-OTP attempt counter and lockout for an
  /// order (resetOtpAttempts Cloud Function).
  Future<String?> resetOtpAttempts(String orderId);
  Future<void> updateDeliveryBoyActiveStatus(String riderId, bool isActive);

  /// Rider's own on/off-duty availability toggle — distinct from [updateDeliveryBoyActiveStatus],
  /// which is the admin-only enable/disable flag. Riders may write this field
  /// themselves (see firestore.rules `deliveryBoys` update allowlist).
  Future<void> updateDeliveryBoyDutyStatus(String riderId, bool onDuty);
  /// Returns the server-generated temporary password for the rider's first
  /// login — the admin must relay it to the rider, as it is shown only once.
  Future<String> whitelistDeliveryBoy(
      String name, String email, String phone, String village,
      {String? vehicleNo, String? licenseNo});
  Future<void> updateDeliveryBoyDetails({
    required String docId,
    required String name,
    required String email,
    required String phone,
    required String village,
    String? vehicleNo,
    String? licenseNo,
  });
  Future<void> deleteDeliveryBoy(String docId);
}
