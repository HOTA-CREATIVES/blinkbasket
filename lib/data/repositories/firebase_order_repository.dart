import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/foundation.dart' show debugPrint;
import '../../domain/entities/delivery_otp.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/rider_location.dart';
import '../../domain/repositories/order_repository.dart';
import '../../core/models/user_model.dart';
import '../models/order_dto.dart';
import '../../core/utils/app_exception.dart';

class FirebaseOrderRepository implements OrderRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // Functions are deployed to Mumbai (asia-south1), closest to the service area.
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-south1');

  @override
  Stream<Order> streamOrder(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw const AppException('Order not found.', code: 'not-found');
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
        // Most recent 100: history used to load (and re-download on every
        // change) every order the customer ever placed.
        .limit(100)
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
        // Most recent 200 — bounds the task list and the earnings screen that
        // sums it, instead of growing with every delivery the rider ever did.
        .limit(200)
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
    // Riders may not read the full order until they accept it (it holds the
    // customer's phone, address and GPS pin). /orderOffers is the PII-free
    // copy the onOrderWritten trigger keeps for every unclaimed order.
    return _db
        .collection('orderOffers')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderDto.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<UserModel>> streamAllDeliveryBoys({int limit = 200}) {
    return _db
        .collection('deliveryBoys')
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
    String? deliveryInstructions,
    double? latitude,
    double? longitude,
    String? requestId,
  }) async {
    try {
      final callable = _functions.httpsCallable('placeOrder');
      final payload = <String, dynamic>{
        'items': items
            .map((item) => <String, dynamic>{
                  'productId': item.productId,
                  'quantity': item.quantity,
                })
            .toList(),
        'deliveryAddress': deliveryAddress,
        if (deliveryInstructions != null && deliveryInstructions.isNotEmpty)
          'deliveryInstructions': deliveryInstructions,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (requestId != null && requestId.isNotEmpty) 'requestId': requestId,
      };
      HttpsCallableResult<dynamic> response;
      try {
        response = await callable.call<dynamic>(payload);
      } on FirebaseFunctionsException catch (e) {
        if (e.code != 'unauthenticated') rethrow;
        // A stale ID token or App Check token is the usual reason a signed-in
        // customer is refused. Refresh both and retry once; the same requestId
        // makes the retry safe (it can never create a second order).
        await _refreshCredentials();
        response = await callable.call<dynamic>(payload);
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      return PlaceOrderResult.success(
        orderId: data['orderId'] as String?,
        otp: data['otp'] as String?,
        totalAmount: (data['totalAmount'] as num?)?.toDouble(),
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        return PlaceOrderResult.failure(
            'We couldn\'t verify this device. Please close and reopen the app, then try again.');
      }
      return PlaceOrderResult.failure(
          e.message ?? 'Failed to place order. Please try again.');
    } catch (_) {
      return PlaceOrderResult.failure(
          'Failed to place order. Check your connection and try again.');
    }
  }

  Future<void> _refreshCredentials() async {
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (e) {
      debugPrint('ID token refresh failed: $e');
    }
    try {
      await FirebaseAppCheck.instance.getToken(true);
    } catch (e) {
      debugPrint('App Check token refresh failed: $e');
    }
  }

  @override
  Future<String?> cancelOrder(String orderId, {String? reason}) async {
    try {
      final callable = _functions.httpsCallable('cancelOrder');
      await callable.call<dynamic>({
        'orderId': orderId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Failed to cancel order (${e.code}). Please try again.';
    } catch (_) {
      return 'Failed to cancel order. Check your connection and try again.';
    }
  }

  @override
  Future<String?> verifyDeliveryOtp(String orderId, String otp, double collectedAmount,
      {RiderLocation? location}) async {
    try {
      final callable = _functions.httpsCallable('verifyDeliveryOtp');
      await callable.call<dynamic>({
        'orderId': orderId,
        'otp': otp,
        'collectedAmount': collectedAmount,
        if (location != null) 'location': location.toMap(),
      });
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
  Future<String?> advanceOrderStatus(String orderId, String nextStatus,
      {RiderLocation? location}) async {
    try {
      await _functions
          .httpsCallable('advanceOrderStatus')
          .call<dynamic>({
            'orderId': orderId,
            'status': nextStatus,
            if (location != null) 'location': location.toMap(),
          })
          .timeout(const Duration(seconds: 20));
      return null;
    } on TimeoutException {
      return 'Request timed out. Check your connection and try again.';
    } on FirebaseFunctionsException catch (e) {
      return userMessageFor(e,
          fallback: "Couldn't update this order. Go back and check its latest status.");
    } catch (_) {
      return "Couldn't update this order. Check your connection and try again.";
    }
  }

  @override
  Future<DeliveryOtp?> getDeliveryOtp(String orderId) async {
    try {
      final doc = await _db
          .collection('orders')
          .doc(orderId)
          .collection('private')
          .doc('delivery')
          .get();
      final data = doc.data();
      final code = data?['otp'];
      if (code is! String || code.isEmpty) return null;
      return DeliveryOtp(
        code: code,
        expiresAt: (data?['expiresAt'] as Timestamp?)?.toDate(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DeliveryOtp> regenerateDeliveryOtp(String orderId) async {
    try {
      final result = await _functions
          .httpsCallable('regenerateDeliveryOtp')
          .call<dynamic>({'orderId': orderId})
          .timeout(const Duration(seconds: 20));
      final data = Map<String, dynamic>.from(result.data as Map);
      final expiresAtMs = data['expiresAtMs'];
      return DeliveryOtp(
        code: data['otp'] as String,
        expiresAt: expiresAtMs is num
            ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs.toInt())
            : null,
      );
    } catch (e) {
      throw AppException(
        userMessageFor(e, fallback: "Couldn't get a new code. Please try again."),
        code: e is FirebaseFunctionsException ? e.code : null,
      );
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
      throw AppException.from(e, action: 'submit order rating');
    }
  }

  @override
  Future<String?> acceptOrder(String orderId) async {
    try {
      final callable = _functions.httpsCallable('acceptOrder');
      // The plugin's default callable timeout is long enough that a stuck
      // connection (e.g. Functions emulator not running, dead network) reads
      // as an infinite spinner to the rider. Bound it explicitly so the
      // caller always gets a result to reset its loading state on.
      await callable
          .call<dynamic>({'orderId': orderId})
          .timeout(const Duration(seconds: 20));
      return null;
    } on TimeoutException {
      return 'Request timed out. Check your connection and try again.';
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Failed to accept — it may already be taken.';
    } catch (_) {
      return 'Failed to accept order. Check your connection and try again.';
    }
  }

  @override
  Future<String?> rejectOrderOffer(String orderId) async {
    try {
      await _functions
          .httpsCallable('rejectOrderOffer')
          .call<dynamic>({'orderId': orderId}).timeout(const Duration(seconds: 20));
      return null;
    } on TimeoutException {
      return 'Request timed out. Check your connection and try again.';
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Could not reject the offer.';
    } catch (_) {
      return 'Could not reject the offer. Check your connection and try again.';
    }
  }

  @override
  Stream<Set<String>> streamRejectedOfferIds(String riderId) {
    return _db
        .collection('deliveryBoys')
        .doc(riderId)
        .collection('rejectedOffers')
        .snapshots()
        .map((snapshot) => {for (final doc in snapshot.docs) doc.id});
  }

  @override
  Future<String?> reportDeliveryFailure(String orderId, String reason) async {
    try {
      final callable = _functions.httpsCallable('reportDeliveryFailure');
      await callable
          .call<dynamic>({'orderId': orderId, 'reason': reason})
          .timeout(const Duration(seconds: 20));
      return null;
    } on TimeoutException {
      return 'Request timed out. Check your connection and try again.';
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Failed to report this order as undelivered.';
    } catch (_) {
      return 'Failed to report this order as undelivered. Check your connection and try again.';
    }
  }

  @override
  Future<String?> adminCancelOrder(String orderId, String adminId, String reason) async {
    try {
      final ref = _db.collection('orders').doc(orderId);
      return await _db.runTransaction<String?>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return 'Order not found.';
        final status = snap.data()?['status'];
        if (status == 'delivered' || status == 'cancelled') {
          return 'This order is already closed.';
        }
        tx.update(ref, {
          'status': 'cancelled',
          'cancelReason': reason,
          'cancelledBy': 'admin',
          'cancelledById': adminId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return null;
      });
    } catch (_) {
      return 'Failed to cancel the order. Check your connection and try again.';
    }
  }

  @override
  Future<String?> adminUnassignOrder(String orderId) async {
    try {
      final ref = _db.collection('orders').doc(orderId);
      return await _db.runTransaction<String?>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return 'Order not found.';
        final data = snap.data() ?? {};
        const unassignable = ['assigned', 'picked_up', 'out_for_delivery'];
        if (!unassignable.contains(data['status'])) {
          return 'Only an order that a rider is holding can be unassigned.';
        }
        tx.update(ref, {
          'status': 'pending',
          'deliveryBoyId': null,
          'deliveryBoyName': null,
          'deliveryBoyPhone': null,
          'unassignedFrom': data['deliveryBoyId'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return null;
      });
    } catch (_) {
      return 'Failed to unassign the order. Check your connection and try again.';
    }
  }

  @override
  Future<String?> resetOtpAttempts(String orderId) async {
    try {
      await _functions
          .httpsCallable('resetOtpAttempts')
          .call<dynamic>({'orderId': orderId})
          .timeout(const Duration(seconds: 20));
      return null;
    } on TimeoutException {
      return 'Request timed out. Check your connection and try again.';
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? 'Failed to reset OTP attempts.';
    } catch (_) {
      return 'Failed to reset OTP attempts. Check your connection and try again.';
    }
  }

  @override
  Future<void> updateDeliveryBoyActiveStatus(String riderId, bool isActive) async {
    try {
      await _db.collection('deliveryBoys').doc(riderId).set({
        'isActive': isActive,
      }, SetOptions(merge: true));
    } catch (e) {
      throw AppException.from(e, action: 'update rider active status');
    }
  }

  @override
  Future<void> updateDeliveryBoyDutyStatus(String riderId, bool onDuty) async {
    try {
      // `deliveryBoys` is the rules-protected collection; `deliveryPartners`
      // has no rule match and is implicitly write-locked by the catch-all.
      await _db.collection('deliveryBoys').doc(riderId).set({
        'onDuty': onDuty,
      }, SetOptions(merge: true));
    } catch (e) {
      throw AppException.from(e, action: 'update rider duty status');
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
      throw AppException.from(e, action: 'whitelist rider login');
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
      await _db.collection('deliveryBoys').doc(docId).set({
        'name': name,
        'email': email,
        'phone': phone,
        'village': village,
        'vehicleNo': vehicleNo ?? '',
        'licenseNo': licenseNo ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw AppException.from(e, action: 'update rider details');
    }
  }

  @override
  Future<void> deleteDeliveryBoy(String docId) async {
    try {
      await _db.collection('deliveryBoys').doc(docId).set({
        'isActive': false,
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw AppException.from(e, action: 'delete rider');
    }
  }
}
