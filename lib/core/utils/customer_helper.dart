import 'dart:math';
import '../data/villages.dart';

class CustomerHelper {
  /// Formats the phone number to be prefixed with +91 if it's a mobile number.
  static String formatPhone(String phone, String email) {
    if (phone.isEmpty) return email;
    if (phone.startsWith('+91')) {
      return phone;
    }
    if (phone.startsWith('+')) {
      return phone;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'\s+|-'), '');
    return '+91 $cleanPhone';
  }

  /// Calculates Haversine distance between two points in meters.
  /// Used for testability without relying on native geolocator package in tests.
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000; // Earth's radius in meters
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return r * c;
  }

  /// Finds the closest village from the whitelisted villages based on coordinates.
  static String findClosestVillage(double lat, double lng) {
    String closest = Villages.all.first.name;
    double minDistance = double.infinity;

    for (final village in Villages.all) {
      final distance = calculateDistance(lat, lng, village.latitude, village.longitude);
      if (distance < minDistance) {
        minDistance = distance;
        closest = village.name;
      }
    }

    return closest;
  }
}
