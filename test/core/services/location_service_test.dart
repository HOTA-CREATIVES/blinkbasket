import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/services/location_service.dart';

void main() {
  group('LocationService.evaluate', () {
    LocationResult eval({double accuracy = 12, bool mocked = false}) => LocationService.evaluate(
          latitude: 16.546,
          longitude: 81.5225,
          accuracyMeters: accuracy,
          isMocked: mocked,
        );

    test('accepts an accurate, genuine fix and keeps its coordinates and accuracy', () {
      final r = eval();
      expect(r.isOk, isTrue);
      expect(r.fix!.latitude, 16.546);
      expect(r.fix!.longitude, 81.5225);
      expect(r.fix!.accuracyMeters, 12);
    });

    test('rejects a spoofed (mock-location) fix even if it is very accurate', () {
      final r = eval(accuracy: 3, mocked: true);
      expect(r.isOk, isFalse);
      expect(r.failure, LocationFailure.mocked);
    });

    test('rejects a fix that is too imprecise to place a delivery pin', () {
      final r = eval(accuracy: 350);
      expect(r.isOk, isFalse);
      expect(r.failure, LocationFailure.weakSignal);
    });

    test('accepts a fix exactly at the accuracy limit, rejects just past it', () {
      expect(eval(accuracy: LocationService.maxAcceptableAccuracyMeters).isOk, isTrue);
      expect(eval(accuracy: LocationService.maxAcceptableAccuracyMeters + 0.1).isOk, isFalse);
    });
  });

  group('LocationResult', () {
    test('every failure has a helpful, non-empty message that offers the map-pin fallback or a fix', () {
      for (final f in LocationFailure.values) {
        final msg = LocationResult.failure(f).message;
        expect(msg, isNotEmpty, reason: '$f');
        expect(msg.toLowerCase(), anyOf(contains('map'), contains('settings')), reason: '$f');
      }
    });

    test('only failures fixable in system settings offer the Settings shortcut', () {
      final fixable = LocationFailure.values
          .where((f) => LocationResult.failure(f).canOpenSettings)
          .toSet();
      expect(fixable, {LocationFailure.servicesOff, LocationFailure.deniedForever});
    });

    test('a success is never a failure and has no settings shortcut', () {
      const fix = LocationFix(latitude: 1, longitude: 2, accuracyMeters: 5);
      const r = LocationResult.success(fix);
      expect(r.isOk, isTrue);
      expect(r.failure, isNull);
      expect(r.canOpenSettings, isFalse);
    });
  });
}
