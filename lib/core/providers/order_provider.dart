import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/usecases/place_order_usecase.dart';
import '../../domain/usecases/verify_delivery_otp_usecase.dart';
import '../../domain/usecases/stream_customer_orders_usecase.dart';
import '../../domain/usecases/stream_delivery_orders_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';
import '../../domain/usecases/stream_incoming_offers_usecase.dart';
import '../../domain/usecases/accept_order_usecase.dart';
import '../../data/repositories/firebase_order_repository.dart';
import '../models/user_model.dart';
import '../utils/shared_stream.dart';

class OrderProvider with ChangeNotifier {
  final OrderRepository _orderRepository;

  late final PlaceOrderUseCase _placeOrderUseCase;
  late final VerifyDeliveryOtpUseCase _verifyDeliveryOtpUseCase;
  late final StreamCustomerOrdersUseCase _streamCustomerOrdersUseCase;
  late final StreamDeliveryOrdersUseCase _streamDeliveryOrdersUseCase;
  late final UpdateOrderStatusUseCase _updateOrderStatusUseCase;
  late final StreamIncomingOffersUseCase _streamIncomingOffersUseCase;
  late final AcceptOrderUseCase _acceptOrderUseCase;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Single shared listener on the (limit-capped) orders collection. The admin
  // console mounts three streamAllOrders() StreamBuilders at once — two order
  // tabs plus the riders tab — which previously opened three separate
  // snapshots() listeners over up to 300 orders each.
  StreamSubscription<List<Order>>? _allOrdersSub;
  final StreamController<List<Order>> _allOrdersController =
      StreamController<List<Order>>.broadcast();
  List<Order>? _latestAllOrders;

  OrderProvider({OrderRepository? repository})
      : _orderRepository = repository ?? FirebaseOrderRepository() {
    _placeOrderUseCase = PlaceOrderUseCase(_orderRepository);
    _verifyDeliveryOtpUseCase = VerifyDeliveryOtpUseCase(_orderRepository);
    _streamCustomerOrdersUseCase = StreamCustomerOrdersUseCase(_orderRepository);
    _streamDeliveryOrdersUseCase = StreamDeliveryOrdersUseCase(_orderRepository);
    _updateOrderStatusUseCase = UpdateOrderStatusUseCase(_orderRepository);
    _streamIncomingOffersUseCase = StreamIncomingOffersUseCase(_orderRepository);
    _acceptOrderUseCase = AcceptOrderUseCase(_orderRepository);
  }
  // Streams
  Stream<Order> streamOrder(String orderId) {
    return _orderRepository.streamOrder(orderId);
  }

  Stream<List<Order>> streamCustomerOrders(String customerId) {
    return _streamCustomerOrdersUseCase(customerId);
  }

  Stream<List<Order>> streamDeliveryBoyOrders(String deliveryBoyId) {
    return _streamDeliveryOrdersUseCase(deliveryBoyId);
  }

  static const int _allOrdersLimit = 300;

  /// Shared admin orders stream. Callers using the default limit fan out from
  /// one underlying listener; a non-default limit falls back to a fresh stream.
  Stream<List<Order>> streamAllOrders({int limit = _allOrdersLimit}) {
    if (limit != _allOrdersLimit) {
      return _orderRepository.streamAllOrders(limit: limit);
    }
    return _sharedAllOrders();
  }

  Stream<List<Order>> _sharedAllOrders() async* {
    _allOrdersSub ??= _orderRepository
        .streamAllOrders(limit: _allOrdersLimit)
        .listen(
          (orders) {
            _latestAllOrders = orders;
            _allOrdersController.add(orders);
          },
          onError: (Object error, StackTrace stack) {
            _allOrdersController.addError(error, stack);
            // Dead listener (e.g. permission denied after sign-out): drop it
            // so the next streamAllOrders() call reconnects instead of
            // handing out a stream that never emits again.
            _allOrdersSub?.cancel();
            _allOrdersSub = null;
            _latestAllOrders = null;
          },
        );
    if (_latestAllOrders != null) yield _latestAllOrders!;
    yield* _allOrdersController.stream;
  }

  /// Drops every cached listener and value tied to the signed-in user. Called
  /// when the user signs out or a different account signs in: the shared admin
  /// listeners are killed by Firestore on sign-out, and would otherwise stay
  /// dead (and hold the previous user's orders in memory) for the next login.
  void resetSession() {
    _allOrdersSub?.cancel();
    _allOrdersSub = null;
    _latestAllOrders = null;
    _deliveryBoys.reset();
  }

  @override
  void dispose() {
    _allOrdersSub?.cancel();
    _allOrdersController.close();
    _deliveryBoys.dispose();
    super.dispose();
  }

  /// Blinkit-style broadcast feed of pending, unassigned orders any on-duty
  /// rider can accept. See streamIncomingOffers on the repository for why
  /// visibility isn't village-gated.
  Stream<List<Order>> streamIncomingOffers({int limit = 30}) {
    return _streamIncomingOffersUseCase(limit: limit);
  }

  // Shared listener + stable Stream instance for the default limit, so the
  // admin Riders tab (which reads this inside build()) doesn't re-subscribe —
  // and swap its whole UI for a spinner — on every rebuild.
  late final SharedStream<List<UserModel>> _deliveryBoys =
      SharedStream<List<UserModel>>(() => _orderRepository.streamAllDeliveryBoys());

  Stream<List<UserModel>> streamAllDeliveryBoys({int limit = 200}) {
    if (limit != 200) return _orderRepository.streamAllDeliveryBoys(limit: limit);
    return _deliveryBoys.stream;
  }

  /// Places the order via the placeOrder Cloud Function.
  /// Returns the [PlaceOrderResult] (order ID + OTP) on success, or a
  /// failed result on failure (see [errorMessage] for the reason).
  Future<PlaceOrderResult> createOrder({
    required List<OrderItem> items,
    required String deliveryAddress,
    String? deliveryInstructions,
    double? latitude,
    double? longitude,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _placeOrderUseCase(
      items: items,
      deliveryAddress: deliveryAddress,
      deliveryInstructions: deliveryInstructions,
      latitude: latitude,
      longitude: longitude,
    );

    _isLoading = false;
    if (!result.isSuccess) {
      _errorMessage = result.errorMessage ?? 'Failed to place order.';
    }
    notifyListeners();
    return result;
  }

  /// Cancels an active customer order while in 'pending' or 'assigned' state.
  Future<String?> cancelOrder(String orderId, {String? reason}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final error = await _orderRepository.cancelOrder(orderId, reason: reason);
    _isLoading = false;
    if (error != null) {
      _errorMessage = error;
    }
    notifyListeners();
    return error;
  }

  /// Rider-side delivery confirmation. Returns null on success,
  /// or a user-readable error message.
  Future<String?> verifyDelivery(String orderId, String otp) async {
    return _verifyDeliveryOtpUseCase(orderId, otp);
  }

  /// Customer-side OTP lookup for an active order.
  Future<String?> getOrderOtp(String orderId) {
    return _orderRepository.getOrderOtp(orderId);
  }

  Future<String?> updateStatus(String orderId, String status) async {
    try {
      await _updateOrderStatusUseCase(orderId, status);
      return null;
    } catch (e) {
      debugPrint("Failed to update status: $e");
      // Never surface the raw exception text; the usual cause is the order
      // having changed underneath the rider (e.g. cancelled by the customer).
      return "This order may have been cancelled or changed. Go back and check its latest status.";
    }
  }

  Future<void> submitRating(String orderId, int rating, String? comment) async {
    await _orderRepository.submitOrderRating(orderId, rating, comment);
  }

  /// Rider claims a pending order via the acceptOrder Cloud Function.
  /// Returns null on success, or a user-readable error (e.g. another rider
  /// already took it).
  Future<String?> acceptOrder(String orderId) => _acceptOrderUseCase(orderId);

  /// Rider reports an assigned/picked-up/out-for-delivery order as
  /// undeliverable (customer unreachable, refused COD, bad address). Returns
  /// null on success, or a user-readable error.
  Future<String?> reportDeliveryFailure(String orderId, String reason) =>
      _orderRepository.reportDeliveryFailure(orderId, reason);

  /// Admin order interventions — each returns null on success or a
  /// user-readable error. See the repository for semantics.
  Future<String?> adminCancelOrder(String orderId, String adminId, String reason) =>
      _orderRepository.adminCancelOrder(orderId, adminId, reason);

  Future<String?> adminUnassignOrder(String orderId) =>
      _orderRepository.adminUnassignOrder(orderId);

  Future<String?> resetOtpAttempts(String orderId) =>
      _orderRepository.resetOtpAttempts(orderId);

  Future<void> updateDeliveryBoyActiveStatus(String riderId, bool isActive) async {
    await _orderRepository.updateDeliveryBoyActiveStatus(riderId, isActive);
  }

  Future<void> updateDeliveryBoyDutyStatus(String riderId, bool onDuty) async {
    await _orderRepository.updateDeliveryBoyDutyStatus(riderId, onDuty);
  }

  /// Returns the server-generated temporary password for the rider's first
  /// login, to be relayed to them by the admin.
  Future<String> whitelistRider(String name, String email, String phone, String village,
      {String? vehicleNo, String? licenseNo}) async {
    return _orderRepository.whitelistDeliveryBoy(name, email, phone, village,
        vehicleNo: vehicleNo, licenseNo: licenseNo);
  }

  Future<void> updateRiderDetails({
    required String docId,
    required String name,
    required String email,
    required String phone,
    required String village,
    String? vehicleNo,
    String? licenseNo,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _orderRepository.updateDeliveryBoyDetails(
        docId: docId,
        name: name,
        email: email,
        phone: phone,
        village: village,
        vehicleNo: vehicleNo,
        licenseNo: licenseNo,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteRider(String docId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _orderRepository.deleteDeliveryBoy(docId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
