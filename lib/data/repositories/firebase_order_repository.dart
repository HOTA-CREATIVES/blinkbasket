import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../../core/models/user_model.dart';
import '../models/order_dto.dart';

class FirebaseOrderRepository implements OrderRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // Functions are deployed to Mumbai (asia-south1), closest to the service area.
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  @override
  Stream<Order> streamOrder(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw Exception("Order not found: $orderId");
      }
      return OrderDto.fromMap(snapshot.data() ?? {}, snapshot.id);
    });
  }

  @override
  Stream<List<Order>> streamCustomerOrders(String customerId) {
    return _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderDto.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<Order>> streamDeliveryBoyOrders(String deliveryBoyId) {
    return _db
        .collection('orders')
        .where('deliveryBoyId', isEqualTo: deliveryBoyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderDto.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<Order>> streamAllOrders({int limit = 300}) {
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderDto.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<Order>> streamIncomingOffers({int limit = 30}) {
    return _db
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .where('deliveryBoyId', isEqualTo: null)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderDto.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<UserModel>> streamAllDeliveryBoys({int limit = 200}) {
    return _db
        .collection('deliveryPartners')
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) => doc.data()['isDeleted'] != true)
            .map((doc) =>
                UserModel.fromMap({...doc.data(), 'role': 'delivery'}, doc.id))
            .toList());
  }

  @override
  Future<PlaceOrderResult> placeOrder({
    required List<OrderItem> items,
    required String deliveryAddress,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final callable = _functions.httpsCallable('placeOrder');
      final response = await callable.call<dynamic>({
        'items': items
            .map((item) => <String, dynamic>{
                  'productId': item.productId,
                  'quantity': item.quantity,
                })
            .toList(),
        'deliveryAddress': deliveryAddress,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      return PlaceOrderResult.success(
        orderId: data['orderId'] as String?,
        otp: data['otp'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      return PlaceOrderResult.failure(
          e.message ?? 'Failed to place order. Please try again.');
    } catch (_) {
      return PlaceOrderResult.failure(
          'Failed to place order. Check your connection and try again.');
    }
  }

  @override
  Future<String?> verifyDeliveryOtp(String orderId, String otp) async {
    try {
      final callable = _functions.httpsCallable('verifyDeliveryOtp');
      await callable.call<dynamic>({'orderId': orderId, 'otp': otp});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'OTP verification failed. Please try again.';
    } catch (_) {
      return 'OTP verification failed. Check your connection and try again.';
    }
  }

  @override
  Future<String?> getOrderOtp(String orderId) async {
    try {
      final doc = await _db
          .collection('orders')
          .doc(orderId)
          .collection('private')
          .doc('delivery')
          .get();
      return doc.data()?['otp'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Failed to update order status: $e");
    }
  }

  @override
  Future<void> submitOrderRating(String orderId, int rating, String? comment) async {
    try {
      await _db.collection('orders').doc(orderId).update({
        'rating': rating,
        'ratingComment': comment,
        'ratedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Failed to submit order rating: $e");
    }
  }

  @override
  Future<String?> acceptOrder(String orderId) async {
    try {
      final callable = _functions.httpsCallable('acceptOrder');
      await callable.call<dynamic>({'orderId': orderId});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Failed to accept — it may already be taken.';
    } catch (_) {
      return 'Failed to accept order. Check your connection and try again.';
    }
  }

  @override
  Future<void> updateDeliveryBoyActiveStatus(String riderId, bool isActive) async {
    try {
      await _db.collection('deliveryPartners').doc(riderId).set({
        'isActive': isActive,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Failed to update rider active status: $e");
    }
  }

  @override
  Future<void> updateDeliveryBoyDutyStatus(String riderId, bool onDuty) async {
    try {
      await _db.collection('deliveryPartners').doc(riderId).set({
        'onDuty': onDuty,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Failed to update rider duty status: $e");
    }
  }

  @override
  Future<String> whitelistDeliveryBoy(
      String name, String email, String phone, String village,
      {String? vehicleNo, String? licenseNo}) async {
    try {
      final callable = _functions.httpsCallable('createRiderLogin');
      final result = await callable.call<dynamic>({
        'name': name,
        'email': email,
        'phone': phone,
        'village': village,
        'vehicleNo': vehicleNo ?? '',
        'licenseNo': licenseNo ?? '',
      });
      return result.data['temporaryPassword'] as String;
    } catch (e) {
      throw Exception("Failed to whitelist rider login: $e");
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
  }) async {
    try {
      await _db.collection('deliveryPartners').doc(docId).set({
        'name': name,
        'email': email,
        'phone': phone,
        'currentVillage': village,
        'vehicleNo': vehicleNo ?? '',
        'licenseNo': licenseNo ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Failed to update rider details: $e");
    }
  }

  @override
  Future<void> deleteDeliveryBoy(String docId) async {
    try {
      await _db.collection('deliveryPartners').doc(docId).set({
        'isActive': false,
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Failed to delete rider: $e");
    }
  }
}
