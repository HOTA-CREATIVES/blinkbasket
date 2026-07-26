import 'package:flutter/material.dart';

/// Design tokens: single source of truth for color, spacing, radius,
/// and motion values used across the app.
class AppTokens {
  AppTokens._();

  // ---- Brand color ----
  /// Fresh green — groceries, primary actions.
  static const Color primary = Color(0xFF16A34A);

  /// Teal — medicines & pharmacy accents.
  static const Color medicine = Color(0xFF0D9488);

  /// Warm amber — COD / delivery accents.
  static const Color accent = Color(0xFFF59E0B);

  /// Brand chrome yellow — app bar / ETA badge / promo banner backgrounds.
  /// Identity color, not a CTA color — actions still use [primary].
  static const Color brandChrome = Color(0xFFF8CB46);

  /// Near-black for text/icons drawn directly on [brandChrome] surfaces,
  /// where full-black reads harsh against the warm yellow.
  static const Color onBrandChrome = Color(0xFF1C1C1C);

  /// Status colors for the order lifecycle.
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusAssigned = Color(0xFF3B82F6);
  static const Color statusPickedUp = Color(0xFF6366F1);
  static const Color statusOutForDelivery = Color(0xFF8B5CF6);
  static const Color statusDelivered = Color(0xFF16A34A);
  static const Color statusCancelled = Color(0xFFDC2626);

  // ---- Spacing (4dp grid) ----
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  // ---- Corner radius ----
  static const double rSm = 8;
  static const double rMd = 12;
  static const double rLg = 16;
  static const double rXl = 24;
  static const double rPill = 100;

  // ---- Motion ----
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);

  /// Color for an order status string used across customer/admin/rider views.
  static Color statusColor(String status) {
    switch (status) {
      case 'pending':
        return statusPending;
      case 'assigned':
        return statusAssigned;
      case 'picked_up':
        return statusPickedUp;
      case 'out_for_delivery':
        return statusOutForDelivery;
      case 'delivered':
        return statusDelivered;
      case 'cancelled':
        return statusCancelled;
      default:
        return statusAssigned;
    }
  }

  /// Human-readable label for an order status.
  static String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Rider Assigned';
      case 'picked_up':
        return 'Picked Up';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
