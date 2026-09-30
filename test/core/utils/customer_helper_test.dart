import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/utils/customer_helper.dart';
import 'package:hypermart/domain/entities/service_zone.dart';

void main() {
  group('CustomerHelper.nearestZone — static village fallback', () {
    test('a point near Bhimavaram is inside and named Bhimavaram', () {
      final m = CustomerHelper.nearestZone(16.546, 81.5225, const []);
      expect(m.isInside, isTrue);
      expect(m.name, 'Bhimavaram');
    });

    test('a point far outside every village is not inside', () {
      final m = CustomerHelper.nearestZone(19.076, 72.8777, const []);
      expect(m.isInside, isFalse);
    });
  });

  group('CustomerHelper.nearestZone — admin zones', () {
    // ~0.009 deg latitude ≈ 1 km.
    const near = ServiceZone(name: 'Near', lat: 16.527, lng: 81.5, radiusKm: 1); // ~3 km away, radius 1
    const wide = ServiceZone(name: 'Wide', lat: 16.536, lng: 81.5, radiusKm: 5); // ~4 km away, radius 5

    test('prefers a zone that actually contains the point over a nearer one that does not', () {
      final m = CustomerHelper.nearestZone(16.5, 81.5, const [near, wide]);
      expect(m.name, 'Wide');
      expect(m.isInside, isTrue);
    });

    test('outside every zone reports the closest zone with isInside false', () {
      final m = CustomerHelper.nearestZone(16.5, 81.5, const [near]);
      expect(m.name, 'Near');
      expect(m.isInside, isFalse);
    });

    test('honours each zone\'s own radius (not the static fallback radius)', () {
      // ~11 km from the centre: inside the 12 km static fallback, but this
      // zone is configured with a 2 km radius, so it must be outside.
      const tight = ServiceZone(name: 'Tight', lat: 16.5, lng: 81.5, radiusKm: 2);
      final m = CustomerHelper.nearestZone(16.6, 81.5, const [tight]);
      expect(m.isInside, isFalse);
    });
  });

  group('CustomerHelper.centerOf', () {
    const zone = ServiceZone(name: 'Zed', lat: 17.0, lng: 82.0, radiusKm: 3);

    test('uses a live zone by name first', () {
      final c = CustomerHelper.centerOf('Zed', const [zone]);
      expect((c.lat, c.lng), (17.0, 82.0));
    });

    test('falls back to the static village list by name', () {
      final c = CustomerHelper.centerOf('Bhimavaram', const []);
      expect((c.lat, c.lng), (16.5449, 81.5212));
    });

    test('unknown name falls back to the first zone, then the first village', () {
      expect(CustomerHelper.centerOf('Nowhere', const [zone]).lat, 17.0);
      expect(CustomerHelper.centerOf(null, const []).lat, 16.5449);
    });
  });
}
