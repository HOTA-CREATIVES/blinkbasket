import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Registers this device's FCM token against the signed-in user's Firestore
/// doc so the `onOrderWritten` Cloud Function can push order-status updates.
///
/// Only customers (`/users/{uid}`) and riders (`/deliveryBoys/{uid}`) are
/// covered — the `/admins` collection is locked to `write: if false` in
/// firestore.rules, so admin devices are intentionally out of scope here.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSub;

  String? _collectionFor(String role) {
    if (role == 'customer') return 'users';
    if (role == 'delivery') return 'deliveryBoys';
    return null;
  }

  /// Requests notification permission and stores this device's token on the
  /// user's doc. Safe to call repeatedly (e.g. on every sign-in) — it's a
  /// no-op if permission was already granted/denied.
  Future<void> registerForUser(UserModel user) async {
    final collection = _collectionFor(user.role);
    if (collection == null) return;

    try {
      final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(collection, user.uid, token);
      }

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
        _saveToken(collection, user.uid, newToken);
      });
    } catch (e) {
      // Push registration must never block sign-in — log and move on.
      debugPrint('PushNotificationService.registerForUser failed: $e');
    }
  }

  Future<void> _saveToken(String collection, String uid, String token) async {
    await FirebaseFirestore.instance.collection(collection).doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  /// Best-effort removal of this device's token on logout, so a shared or
  /// reset device doesn't keep receiving another account's notifications.
  Future<void> unregisterCurrentDevice(UserModel? user) async {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    if (user == null) return;

    final collection = _collectionFor(user.role);
    if (collection == null) return;

    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection(collection).doc(user.uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (e) {
      debugPrint('PushNotificationService.unregisterCurrentDevice failed: $e');
    }
  }
}
