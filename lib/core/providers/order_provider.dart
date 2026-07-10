import 'package:flutter/foundation.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/usecases/place_order_usecase.dart';
import '../../domain/usecases/stream_customer_orders_usecase.dart';
import '../../domain/usecases/stream_delivery_orders_usecase.dart';
import '../../domain/usecases/update_order_status_usecase.dart';
import '../../domain/usecases/assign_rider_usecase.dart';
import '../../data/repositories/firebase_order_repository.dart';
import '../models/user_model.dart';

class OrderProvider with ChangeNotifier {
  final OrderRepository _orderRepository = FirebaseOrderRepository();

  late final PlaceOrderUseCase _placeOrderUseCase;
  late final StreamCustomerOrdersUseCase _streamCustomerOrdersUseCase;
  late final StreamDeliveryOrdersUseCase _streamDeliveryOrdersUseCase;
  late final UpdateOrderStatusUseCase _updateOrderStatusUseCase;
  late final AssignRiderUseCase _assignRiderUseCase;

  OrderProvider() {
    _placeOrderUseCase = PlaceOrderUseCase(_orderRepository);
    _streamCustomerOrdersUseCase = StreamCustomerOrdersUseCase(_orderRepository);
    _streamDeliveryOrdersUseCase = StreamDeliveryOrdersUseCase(_orderRepository);
    _updateOrderStatusUseCase = UpdateOrderStatusUseCase(_orderRepository);
    _assignRiderUseCase = AssignRiderUseCase(_orderRepository);
  }

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Streams
  Stream<List<Order>> streamCustomerOrders(String customerId) {
    return _streamCustomerOrdersUseCase(customerId);
  }

  Stream<List<Order>> streamDeliveryBoyOrders(String deliveryBoyId) {
    return _streamDeliveryOrdersUseCase(deliveryBoyId);
  }

  Stream<List<Order>> streamAllOrders() {
    return _orderRepository.streamAllOrders();
  }

  Stream<List<UserModel>> streamDeliveryBoys() {
    return _orderRepository.streamDeliveryBoys();
  }

  Future<bool> createOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String village,
    required List<OrderItem> items,
    required double totalAmount,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final order = Order(
      id: '',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      village: village,
      items: items,
      totalAmount: totalAmount,
      paymentMethod: 'COD',
      status: 'pending',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await _placeOrderUseCase(order);
    _isLoading = false;
    if (!success) {
      _errorMessage = 'Failed to place order. Out of stock or connection issue.';
    }
    notifyListeners();
    return success;
  }

  Future<void> updateStatus(String orderId, String status) async {
    await _updateOrderStatusUseCase(orderId, status);
  }

  Future<void> assignRider(String orderId, String riderId, String riderName) async {
    await _assignRiderUseCase(orderId, riderId, riderName);
  }
}
