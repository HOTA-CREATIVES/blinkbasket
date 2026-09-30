import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../app.dart';
import '../../data/models/order_dto.dart';
import '../utils/route_generator.dart';

/// Handles FCM notification taps — both cold-start (getInitialMessage) and
/// background (onMessageOpenedApp). Resolves the user's role from the live
/// auth state and pushes the appropriate screen.
class NotificationHandler {
  /// Process a notification message tap. [role] is the current user's role
  /// (from AuthProvider.currentUserModel.role).
  static Future<void> handleMessageTap(
    RemoteMessage message,
    String? role,
  ) async {
    final data = message.data;
    final orderId = data['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) return;

    final navigator = JCMartApp.navigatorKey.currentState;
    if (navigator == null) return;

    // If the user is not authenticated, ignore — they'll see the notification
    // after login.
    if (role == null) return;

    switch (role) {
      case 'customer':
        _navigateToCustomerOrder(orderId);
        break;
      case 'delivery':
        await _navigateToRiderTask(orderId, data['type'] as String?);
        break;
      case 'admin':
        // Admins don't have a per-order detail screen — just open the app.
        break;
    }
  }

  static void _navigateToCustomerOrder(String orderId) {
    final navigator = JCMartApp.navigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushNamed(
      RouteGenerator.orderTracking,
      arguments: orderId,
    );
  }

  static Future<void> _navigateToRiderTask(String orderId, String? type) async {
    final navigator = JCMartApp.navigatorKey.currentState;
    if (navigator == null) return;

    // A broadcast offer isn't assigned to this rider yet — TaskDetailScreen
    // assumes an owned order (its swipe slider treats 'pending' as ready to
    // deliver). Offers live inline on the rider's home Tasks tab instead, so
    // just surface that screen rather than pushing the wrong detail view.
    if (type == 'new_order_offer') {
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      if (!doc.exists) return;

      final order = OrderDto.fromMap(doc.data() ?? {}, doc.id);
      navigator.pushNamed(
        RouteGenerator.taskDetail,
        arguments: order,
      );
    } catch (e) {
      debugPrint('NotificationHandler: failed to fetch order $orderId: $e');
    }
  }
}
