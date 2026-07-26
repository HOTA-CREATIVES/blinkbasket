import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:http/http.dart' as http;
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../../core/models/user_model.dart';
import '../../core/services/backend_config.dart';
import 'firebase_order_repository.dart';

class HttpOrderRepository implements OrderRepository {
  final FirebaseOrderRepository _delegate = FirebaseOrderRepository();

  @override
  Stream<Order> streamOrder(String orderId) => _delegate.streamOrder(orderId);

  @override
  Stream<List<Order>> streamCustomerOrders(String customerId) =>
      _delegate.streamCustomerOrders(customerId);

  @override
  Stream<List<Order>> streamDeliveryBoyOrders(String deliveryBoyId) =>
      _delegate.streamDeliveryBoyOrders(deliveryBoyId);

  @override
  Stream<List<Order>> streamAllOrders({int limit = 300}) =>
      _delegate.streamAllOrders(limit: limit);

  @override
  Stream<List<Order>> streamIncomingOffers({int limit = 30}) =>
      _delegate.streamIncomingOffers(limit: limit);

  @override
  Stream<List<UserModel>> streamAllDeliveryBoys({int limit = 200}) =>
      _delegate.streamAllDeliveryBoys(limit: limit);

  @override
  Future<PlaceOrderResult> placeOrder({
    required List<OrderItem> items,
    required String deliveryAddress,
    double? latitude,
    double? longitude,
  }) async {
    if (!BackendConfig.useNodeBackend) {
      return _delegate.placeOrder(
        items: items,
        deliveryAddress: deliveryAddress,
        latitude: latitude,
        longitude: longitude,
      );
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken() ?? '';

      final url = Uri.parse('${BackendConfig.baseUrl}/api/placeOrder');
      final body = jsonEncode({
        'items': items
            .map((item) => {
                  'productId': item.productId,
                  'quantity': item.quantity,
                })
            .toList(),
        'deliveryAddress': deliveryAddress,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: body,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PlaceOrderResult.success(
          orderId: data['orderId'] as String?,
          otp: data['otp'] as String?,
        );
      } else {
        return PlaceOrderResult.failure(data['error'] ?? 'Server error.');
      }
    } catch (e) {
      return PlaceOrderResult.failure('Failed to place order: $e');
    }
  }

  @override
  Future<String?> verifyDeliveryOtp(String orderId, String otp) async {
    if (!BackendConfig.useNodeBackend) {
      return _delegate.verifyDeliveryOtp(orderId, otp);
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken() ?? '';

      final url = Uri.parse('${BackendConfig.baseUrl}/api/verifyDeliveryOtp');
      final body = jsonEncode({
        'orderId': orderId,
        'otp': otp,
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        return null; // success, no error message
      } else {
        final data = jsonDecode(response.body);
        return data['error'] ?? 'Verification failed.';
      }
    } catch (e) {
      return 'Verification failed: $e';
    }
  }

  @override
  Future<String?> getOrderOtp(String orderId) => _delegate.getOrderOtp(orderId);

  @override
  Future<void> updateOrderStatus(String orderId, String status) =>
      _delegate.updateOrderStatus(orderId, status);

  @override
  Future<void> submitOrderRating(String orderId, int rating, String? comment) =>
      _delegate.submitOrderRating(orderId, rating, comment);

  @override
  Future<String?> acceptOrder(String orderId) => _delegate.acceptOrder(orderId);

  @override
  Future<void> updateDeliveryBoyActiveStatus(String riderId, bool isActive) =>
      _delegate.updateDeliveryBoyActiveStatus(riderId, isActive);

  @override
  Future<void> updateDeliveryBoyDutyStatus(String riderId, bool onDuty) =>
      _delegate.updateDeliveryBoyDutyStatus(riderId, onDuty);

  @override
  Future<String> whitelistDeliveryBoy(
      String name, String email, String phone, String village,
      {String? vehicleNo, String? licenseNo}) async {
    if (!BackendConfig.useNodeBackend) {
      return _delegate.whitelistDeliveryBoy(
        name,
        email,
        phone,
        village,
        vehicleNo: vehicleNo,
        licenseNo: licenseNo,
      );
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken() ?? '';

      final url = Uri.parse('${BackendConfig.baseUrl}/api/createRiderLogin');
      final body = jsonEncode({
        'name': name,
        'email': email,
        'phone': phone,
        'village': village,
        if (vehicleNo != null) 'vehicleNo': vehicleNo,
        if (licenseNo != null) 'licenseNo': licenseNo,
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: body,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(data['error'] ?? 'Failed to whitelist rider.');
      }
      return data['temporaryPassword'] as String? ?? '';
    } catch (e) {
      throw Exception('Rider whitelisting failed: $e');
    }
  }

  @override
  Future<void> updateDeliveryBoyDetails({
    required String docId,
    required String name,
    required String email,
    required String phone,
    required String village,
    String? vehicleNo,
    String? licenseNo,
  }) =>
      _delegate.updateDeliveryBoyDetails(
        docId: docId,
        name: name,
        email: email,
        phone: phone,
        village: village,
        vehicleNo: vehicleNo,
        licenseNo: licenseNo,
      );

  @override
  Future<void> deleteDeliveryBoy(String docId) => _delegate.deleteDeliveryBoy(docId);
}
