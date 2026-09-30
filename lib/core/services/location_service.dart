import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Why a location fix could not be produced.
enum LocationFailure {
  servicesOff,
  denied,
  deniedForever,
  timeout,
  mocked,
  weakSignal,
  unknown,
}

class LocationFix {
  final double latitude;
  final double longitude;

  /// Estimated horizontal error of the fix, in metres (smaller is better).
  final double accuracyMeters;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });
}

class LocationResult {
  final LocationFix? fix;
  final LocationFailure? failure;

  const LocationResult.success(LocationFix this.fix) : failure = null;
  const LocationResult.failure(LocationFailure this.failure) : fix = null;

  bool get isOk => fix != null;

  /// True when the only way forward is the user changing a system setting.
  bool get canOpenSettings =>
      failure == LocationFailure.servicesOff || failure == LocationFailure.deniedForever;

  /// User-facing explanation, with the next step.
  String get message {
    switch (failure) {
      case LocationFailure.servicesOff:
        return 'Location is turned off. Turn on GPS, or pin your spot on the map instead.';
      case LocationFailure.denied:
        return 'Location permission was denied. Allow it to use GPS, or pin your spot on the map instead.';
      case LocationFailure.deniedForever:
        return 'Location permission is blocked. Enable it in Settings, or pin your spot on the map instead.';
      case LocationFailure.timeout:
        return "Couldn't get a GPS fix in time. Move somewhere with a clear sky and try again, or pin your spot on the map.";
      case LocationFailure.mocked:
        return 'A mock-location app is active. Turn it off to use GPS, or pin your spot on the map.';
      case LocationFailure.weakSignal:
        return 'GPS signal is too weak to place you accurately. Try again outdoors, or pin your spot on the map.';
      case LocationFailure.unknown:
      case null:
        return "Couldn't read your location. Please try again, or pin your spot on the map.";
    }
  }

  /// Opens the right system settings screen for [failure].
  Future<void> openSettings() async {
    if (failure == LocationFailure.servicesOff) {
      await Geolocator.openLocationSettings();
    } else if (failure == LocationFailure.deniedForever) {
      await Geolocator.openAppSettings();
    }
  }
}

/// Single place that turns "where is the user?" into a validated result.
///
/// Replaces the same permission/position code that was copy-pasted into the
/// onboarding, add-address and edit-address screens — none of which limited how
/// long a fix could take, looked at its accuracy, rejected spoofed locations,
/// or offered a way to fix a blocked permission.
class LocationService {
  LocationService._();

  /// A fix worse than this is rejected: at ~100 m the pin can land on the wrong
  /// lane or the wrong side of a village boundary.
  static const double maxAcceptableAccuracyMeters = 100;

  static const Duration fixTimeout = Duration(seconds: 15);

  static Future<LocationResult> currentFix() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failure(LocationFailure.servicesOff);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.failure(LocationFailure.denied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: fixTimeout,
        ),
      );
      return evaluate(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        isMocked: position.isMocked,
      );
    } on TimeoutException {
      return const LocationResult.failure(LocationFailure.timeout);
    } catch (_) {
      return const LocationResult.failure(LocationFailure.unknown);
    }
  }

  /// Pure validation of a raw position — separated from the platform calls so
  /// it can be unit-tested.
  static LocationResult evaluate({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required bool isMocked,
  }) {
    if (isMocked) return const LocationResult.failure(LocationFailure.mocked);
    if (accuracyMeters > maxAcceptableAccuracyMeters) {
      return const LocationResult.failure(LocationFailure.weakSignal);
    }
    return LocationResult.success(
      LocationFix(latitude: latitude, longitude: longitude, accuracyMeters: accuracyMeters),
    );
  }
}
