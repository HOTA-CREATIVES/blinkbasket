import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/rider_location.dart';

/// Why a location fix could not be produced.
enum LocationFailure {
  servicesOff,
  denied,
  deniedForever,

  /// Permission is granted but only for approximate location (iOS "Precise
  /// Location" off / Android "Approximate" chosen), which is too coarse to
  /// find a house.
  approximateOnly,
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
      failure == LocationFailure.servicesOff ||
      failure == LocationFailure.deniedForever ||
      failure == LocationFailure.approximateOnly;

  /// True when trying again outdoors / a moment later can plausibly work.
  bool get canRetry =>
      failure == LocationFailure.timeout ||
      failure == LocationFailure.weakSignal ||
      failure == LocationFailure.unknown;

  /// User-facing explanation, with the next step.
  String get message {
    switch (failure) {
      case LocationFailure.servicesOff:
        return 'Location is turned off. Turn on GPS, or pin your spot on the map instead.';
      case LocationFailure.denied:
        return 'Location permission was denied. Allow it to use GPS, or pin your spot on the map instead.';
      case LocationFailure.deniedForever:
        return 'Location permission is blocked. Enable it in Settings, or pin your spot on the map instead.';
      case LocationFailure.approximateOnly:
        return 'Precise location is turned off for this app. Turn it on in Settings, or pin your spot on the map instead.';
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
    } else if (failure == LocationFailure.deniedForever ||
        failure == LocationFailure.approximateOnly) {
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

  /// A fix this good ends the search early — no reason to keep the radio on.
  static const double goodAccuracyMeters = 50;

  /// How long to keep listening for a better fix before settling for the best
  /// one seen. A single reading is often the coarse network estimate; GPS
  /// tightens over the next few seconds.
  static const Duration fixTimeout = Duration(seconds: 15);

  /// A cached position older than this is not used as a fallback.
  static const Duration lastKnownMaxAge = Duration(minutes: 2);

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

      if (await _isApproximateOnly()) {
        return const LocationResult.failure(LocationFailure.approximateOnly);
      }

      final collector = FixCollector();
      await _collect(collector);

      // Nothing arrived from the live stream: a very recent cached position
      // beats failing (the same accuracy and spoofing checks still apply).
      if (collector.isEmpty) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && DateTime.now().difference(last.timestamp) <= lastKnownMaxAge) {
          collector.add(_sampleOf(last));
        }
      }
      return collector.result();
    } catch (_) {
      return const LocationResult.failure(LocationFailure.unknown);
    }
  }

  /// How long [quickFix] may take. A rider mid-swipe must not wait for the
  /// 15-second accuracy search a customer's address needs.
  static const Duration quickFixTimeout = Duration(seconds: 4);

  /// A best-effort position to record with a rider's action (pickup, set off,
  /// handover). Never blocks past [quickFixTimeout], never fails the action —
  /// null just means "no location recorded" — and any accuracy is accepted
  /// because the server stores the accuracy alongside it. A spoofed position
  /// is not recorded at all.
  static Future<RiderLocation?> quickFix() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: quickFixTimeout,
        ),
      );
      return riderLocationFrom(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        isMocked: position.isMocked,
      );
    } catch (_) {
      return null;
    }
  }

  /// Pure conversion of a raw reading into what is sent to the server: nothing
  /// for a spoofed reading, otherwise the coordinates with their accuracy.
  static RiderLocation? riderLocationFrom({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required bool isMocked,
  }) {
    if (isMocked) return null;
    return RiderLocation(
      lat: latitude,
      lng: longitude,
      accuracyMeters: accuracyMeters >= 0 ? accuracyMeters : null,
    );
  }

  static LocationSample _sampleOf(Position p) => LocationSample(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracyMeters: p.accuracy,
        isMocked: p.isMocked,
      );

  /// Whether the OS only granted approximate location. Platforms that can't
  /// report it (older Android) are treated as precise.
  static Future<bool> _isApproximateOnly() async {
    try {
      return await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.reduced;
    } catch (_) {
      return false;
    }
  }

  /// Listens for positions until one is good enough or [fixTimeout] passes.
  static Future<void> _collect(FixCollector collector) {
    final done = Completer<void>();
    StreamSubscription<Position>? sub;
    Timer? timer;

    void finish() {
      timer?.cancel();
      sub?.cancel();
      if (!done.isCompleted) done.complete();
    }

    timer = Timer(fixTimeout, finish);
    sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen(
      (position) {
        collector.add(_sampleOf(position));
        if (collector.hasGoodFix) finish();
      },
      onError: (Object _) => finish(),
      onDone: finish,
    );
    return done.future;
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

/// One raw position reading, decoupled from the platform type so the
/// selection logic can be unit-tested.
class LocationSample {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final bool isMocked;

  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    this.isMocked = false,
  });
}

/// Accumulates readings during the fix window and picks the outcome: the most
/// accurate reading, unless any reading looks spoofed.
class FixCollector {
  final List<LocationSample> _samples = [];

  bool get isEmpty => _samples.isEmpty;

  void add(LocationSample sample) => _samples.add(sample);

  /// A genuine reading accurate enough to stop waiting.
  bool get hasGoodFix => _samples.any(
      (s) => !s.isMocked && s.accuracyMeters <= LocationService.goodAccuracyMeters);

  LocationResult result() {
    if (_samples.isEmpty) {
      return const LocationResult.failure(LocationFailure.timeout);
    }
    if (_samples.any((s) => s.isMocked)) {
      return const LocationResult.failure(LocationFailure.mocked);
    }
    final best = _samples.reduce((a, b) => b.accuracyMeters < a.accuracyMeters ? b : a);
    return LocationService.evaluate(
      latitude: best.latitude,
      longitude: best.longitude,
      accuracyMeters: best.accuracyMeters,
      isMocked: best.isMocked,
    );
  }
}
