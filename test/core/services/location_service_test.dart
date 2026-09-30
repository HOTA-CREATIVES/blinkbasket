import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/services/location_service.dart';

void main() {
  _collectorTests();
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
      expect(fixable, {
        LocationFailure.servicesOff,
        LocationFailure.deniedForever,
        LocationFailure.approximateOnly,
      });
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

void _collectorTests() {
  group('FixCollector', () {
    LocationSample sample(double accuracy, {bool mocked = false, double lat = 16.5449}) =>
        LocationSample(latitude: lat, longitude: 81.5212, accuracyMeters: accuracy, isMocked: mocked);

    test('has no result before any reading arrives (caller reports a timeout)', () {
      final c = FixCollector();
      expect(c.isEmpty, isTrue);
      expect(c.hasGoodFix, isFalse);
      expect(c.result().failure, LocationFailure.timeout);
    });

    test('keeps the most accurate reading, not the first or the last', () {
      final c = FixCollector()
        ..add(sample(90, lat: 16.1))
        ..add(sample(35, lat: 16.2))
        ..add(sample(60, lat: 16.3));

      final result = c.result();
      expect(result.isOk, isTrue);
      expect(result.fix!.latitude, 16.2);
      expect(result.fix!.accuracyMeters, 35);
    });

    test('a coarse first reading followed by a tight one succeeds (single-shot would have failed)', () {
      final c = FixCollector()
        ..add(sample(400)) // network estimate
        ..add(sample(20)); // GPS locks
      expect(c.hasGoodFix, isTrue);
      expect(c.result().isOk, isTrue);
    });

    test('stops waiting only for a genuinely good, non-mocked reading', () {
      expect(FixCollector()..add(sample(80)), isA<FixCollector>());
      expect((FixCollector()..add(sample(80))).hasGoodFix, isFalse);
      expect((FixCollector()..add(sample(50))).hasGoodFix, isTrue);
      expect((FixCollector()..add(sample(10, mocked: true))).hasGoodFix, isFalse);
    });

    test('only coarse readings are reported as a weak signal, not accepted', () {
      final c = FixCollector()..add(sample(250))..add(sample(180));
      expect(c.result().failure, LocationFailure.weakSignal);
    });

    test('a reading at the acceptance limit is still accepted', () {
      final c = FixCollector()..add(sample(LocationService.maxAcceptableAccuracyMeters));
      expect(c.result().isOk, isTrue);
    });

    test('any spoofed reading fails the whole attempt, even alongside good ones', () {
      final c = FixCollector()..add(sample(10))..add(sample(15, mocked: true));
      expect(c.result().failure, LocationFailure.mocked);
    });
  });

  group('LocationResult for approximate-only permission', () {
    const result = LocationResult.failure(LocationFailure.approximateOnly);

    test('sends the user to settings and mentions precise location', () {
      expect(result.canOpenSettings, isTrue);
      expect(result.canRetry, isFalse);
      expect(result.message, contains('Precise location'));
      expect(result.message, contains('pin your spot on the map'));
    });
  });

  group('LocationResult.canRetry', () {
    test('is true only where trying again can help', () {
      const retry = [LocationFailure.timeout, LocationFailure.weakSignal, LocationFailure.unknown];
      for (final f in LocationFailure.values) {
        expect(LocationResult.failure(f).canRetry, retry.contains(f), reason: '$f');
      }
    });

    test('settings-fixable failures are not retryable', () {
      for (final f in [LocationFailure.servicesOff, LocationFailure.deniedForever]) {
        expect(LocationResult.failure(f).canOpenSettings, isTrue);
        expect(LocationResult.failure(f).canRetry, isFalse);
      }
    });
  });
}
