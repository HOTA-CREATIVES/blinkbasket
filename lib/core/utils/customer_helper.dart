import 'dart:math';
import '../data/villages.dart';
import '../../domain/entities/service_zone.dart';

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

  /// Finds the name of the closest zone centroid from a live [ServiceZone]
  /// list to the given [lat]/[lng] coordinates.
  ///
  /// When [zones] is empty, falls back to [findClosestVillage] so cold-start
  /// (before Firestore loads) continues to work with the static village data.
  static String findClosestZoneName(double lat, double lng, List<ServiceZone> zones) {
    if (zones.isEmpty) return findClosestVillage(lat, lng);

    String closest = zones.first.name;
    double minDistance = double.infinity;

    for (final zone in zones) {
      final distance = calculateDistance(lat, lng, zone.lat, zone.lng);
      if (distance < minDistance) {
        minDistance = distance;
        closest = zone.name;
      }
    }

    return closest;
  }

  /// Radius used for the static [Villages] fallback — must match the server's
  /// SERVICE_RADIUS_METERS in functions/src/index.ts (the admin-configured
  /// [ServiceZone]s carry their own per-zone radius).
  static const double fallbackServiceRadiusMeters = 12000;

  /// Which zone a point belongs to, and whether it's inside the delivery area.
  ///
  /// Uses the live admin [zones] (per-zone `radiusKm`) when present, else the
  /// static villages. If several zones contain the point the closest wins; if
  /// none does, the closest zone is returned with [isInside] false.
  static ({String name, double distanceMeters, bool isInside}) nearestZone(
      double lat, double lng, List<ServiceZone> zones) {
    final candidates = zones.isNotEmpty
        ? [
            for (final z in zones)
              (name: z.name, lat: z.lat, lng: z.lng, radius: z.radiusKm * 1000)
          ]
        : [
            for (final v in Villages.all)
              (
                name: v.name,
                lat: v.latitude,
                lng: v.longitude,
                radius: fallbackServiceRadiusMeters
              )
          ];

    ({String name, double distance, bool inside})? best;
    for (final c in candidates) {
      final d = calculateDistance(lat, lng, c.lat, c.lng);
      final inside = d <= c.radius;
      final better = best == null ||
          (inside && !best.inside) ||
          (inside == best.inside && d < best.distance);
      if (better) best = (name: c.name, distance: d, inside: inside);
    }
    final b = best!;
    return (name: b.name, distanceMeters: b.distance, isInside: b.inside);
  }

  /// Map-centring point for a village/zone [name] (live zones first, then the
  /// static list, then the first configured zone/village).
  static ({double lat, double lng}) centerOf(String? name, List<ServiceZone> zones) {
    for (final z in zones) {
      if (z.name == name) return (lat: z.lat, lng: z.lng);
    }
    final v = name == null ? null : Villages.byName(name);
    if (v != null) return (lat: v.latitude, lng: v.longitude);
    if (zones.isNotEmpty) return (lat: zones.first.lat, lng: zones.first.lng);
    return (lat: Villages.all.first.latitude, lng: Villages.all.first.longitude);
  }

  /// Finds the closest village from the whitelisted villages based on coordinates.
  /// Kept as a static fallback for when live zone data is not yet available.
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

