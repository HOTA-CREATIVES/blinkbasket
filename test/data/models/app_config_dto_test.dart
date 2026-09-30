import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/data/models/app_config_dto.dart';

void main() {
  group('AppConfigDto legal text', () {
    test('reads admin-authored privacy policy and terms', () {
      final c = AppConfigDto.fromMap({
        'privacyPolicy': '  # Privacy\n\nWe keep little.  ',
        'termsAndConditions': 'Be kind.',
      });
      expect(c.privacyPolicy, '# Privacy\n\nWe keep little.');
      expect(c.termsAndConditions, 'Be kind.');
    });

    test('blank or missing text means "not configured" (so the bundled default shows)', () {
      final blank = AppConfigDto.fromMap({'privacyPolicy': '   ', 'termsAndConditions': ''});
      expect(blank.privacyPolicy, isNull);
      expect(blank.termsAndConditions, isNull);
      final missing = AppConfigDto.fromMap({});
      expect(missing.privacyPolicy, isNull);
      expect(missing.termsAndConditions, isNull);
    });

    test('a non-string value is ignored rather than crashing', () {
      final c = AppConfigDto.fromMap({'privacyPolicy': 42, 'termsAndConditions': ['x']});
      expect(c.privacyPolicy, isNull);
      expect(c.termsAndConditions, isNull);
    });
  });

  group('AppConfigDto.fromMap', () {
    test('parses all fields', () {
      final ts = Timestamp.fromDate(DateTime(2025, 8, 1, 12, 0));
      final map = <String, dynamic>{
        'storeOpen': true,
        'deliveryFee': 25.0,
        'freeDeliveryAbove': 500.0,
        'updatedAt': ts,
        'etaLabel': '30-45 mins',
        'riderPayoutPerDelivery': 40.0,
        'supportPhone': '9999999999',
        'supportWhatsapp': '8888888888',
        'categories': ['Dairy', 'Bakery'],
        'maintenanceMode': true,
        'minimumOrderAmount': 100.0,
        'maxOrdersPerSlot': 10,
        'serviceZones': [
          {'name': 'Springfield', 'lat': 12.97, 'lng': 77.59, 'radiusKm': 5.0},
        ],
      };

      final config = AppConfigDto.fromMap(map);

      expect(config.storeOpen, true);
      expect(config.deliveryFee, 25.0);
      expect(config.freeDeliveryAbove, 500.0);
      expect(config.updatedAt, ts.toDate());
      expect(config.etaLabel, '30-45 mins');
      expect(config.riderPayoutPerDelivery, 40.0);
      expect(config.supportPhone, '9999999999');
      expect(config.supportWhatsapp, '8888888888');
      expect(config.categories, ['Dairy', 'Bakery']);
      expect(config.maintenanceMode, true);
      expect(config.minimumOrderAmount, 100.0);
      expect(config.maxOrdersPerSlot, 10);
      expect(config.serviceZones.length, 1);
      expect(config.serviceZones[0].name, 'Springfield');
    });

    test('applies defaults for missing optional fields', () {
      final map = <String, dynamic>{
        'storeOpen': false,
        'deliveryFee': 30.0,
        'freeDeliveryAbove': 300.0,
      };

      final config = AppConfigDto.fromMap(map);

      expect(config.maintenanceMode, false);
      expect(config.minimumOrderAmount, 0.0);
      expect(config.maxOrdersPerSlot, 20);
      expect(config.riderPayoutPerDelivery, 30.0);
      expect(config.categories, isEmpty);
      expect(config.serviceZones, isEmpty);
      expect(config.etaLabel, isNull);
      expect(config.supportPhone, isNull);
      expect(config.supportWhatsapp, isNull);
    });

    test('etaLabel is null when empty string', () {
      final map = <String, dynamic>{
        'storeOpen': true,
        'deliveryFee': 30.0,
        'freeDeliveryAbove': 300.0,
        'etaLabel': '',
      };

      final config = AppConfigDto.fromMap(map);

      expect(config.etaLabel, isNull);
    });

    test('etaLabel is null when whitespace only', () {
      final map = <String, dynamic>{
        'storeOpen': true,
        'deliveryFee': 30.0,
        'freeDeliveryAbove': 300.0,
        'etaLabel': '   ',
      };

      final config = AppConfigDto.fromMap(map);

      expect(config.etaLabel, isNull);
    });

    test('etaLabel trimmed when valid', () {
      final map = <String, dynamic>{
        'storeOpen': true,
        'deliveryFee': 30.0,
        'freeDeliveryAbove': 300.0,
        'etaLabel': '  30-45 mins  ',
      };

      final config = AppConfigDto.fromMap(map);

      expect(config.etaLabel, '30-45 mins');
    });

    test('supportPhone is null when empty string', () {
      final map = <String, dynamic>{
        'storeOpen': true,
        'deliveryFee': 30.0,
        'freeDeliveryAbove': 300.0,
        'supportPhone': '',
      };

      final config = AppConfigDto.fromMap(map);

      expect(config.supportPhone, isNull);
    });

    test('supportWhatsapp is null when empty string', () {
      final map = <String, dynamic>{
        'storeOpen': true,
        'deliveryFee': 30.0,
        'freeDeliveryAbove': 300.0,
        'supportWhatsapp': '',
      };

      final config = AppConfigDto.fromMap(map);

      expect(config.supportWhatsapp, isNull);
    });

    test('handles null updatedAt gracefully', () {
      final map = <String, dynamic>{
        'storeOpen': true,
        'deliveryFee': 30.0,
        'freeDeliveryAbove': 300.0,
        'updatedAt': null,
      };

      final config = AppConfigDto.fromMap(map);

      expect(config.updatedAt, isNotNull);
    });

    test('filters out serviceZones with empty name', () {
      final map = <String, dynamic>{
        'storeOpen': true,
        'deliveryFee': 30.0,
        'freeDeliveryAbove': 300.0,
        'serviceZones': [
          {'name': 'Springfield', 'lat': 12.97, 'lng': 77.59, 'radiusKm': 5.0},
          {'name': '', 'lat': 0, 'lng': 0, 'radiusKm': 1.0},
        ],
      };

      final config = AppConfigDto.fromMap(map);

      expect(config.serviceZones.length, 1);
      expect(config.serviceZones[0].name, 'Springfield');
    });

    test('filters out empty categories', () {
      final map = <String, dynamic>{
        'storeOpen': true,
        'deliveryFee': 30.0,
        'freeDeliveryAbove': 300.0,
        'categories': ['Dairy', '', '  ', 'Bakery'],
      };

      final config = AppConfigDto.fromMap(map);

      expect(config.categories, ['Dairy', 'Bakery']);
    });
  });

  group('AppConfigDto.toMap', () {
    test('serializes all fields', () {
      final config = AppConfigDto(
        storeOpen: true,
        deliveryFee: 30.0,
        freeDeliveryAbove: 300.0,
        updatedAt: DateTime(2025, 8, 1),
        etaLabel: '30 mins',
        riderPayoutPerDelivery: 35.0,
        supportPhone: '9999999999',
        supportWhatsapp: '8888888888',
        categories: ['Dairy'],
        maintenanceMode: true,
        minimumOrderAmount: 100.0,
        maxOrdersPerSlot: 15,
      );

      final map = config.toMap();

      expect(map['storeOpen'], true);
      expect(map['deliveryFee'], 30.0);
      expect(map['freeDeliveryAbove'], 300.0);
      expect(map['etaLabel'], '30 mins');
      expect(map['riderPayoutPerDelivery'], 35.0);
      expect(map['supportPhone'], '9999999999');
      expect(map['supportWhatsapp'], '8888888888');
      expect(map['categories'], ['Dairy']);
      expect(map['maintenanceMode'], true);
      expect(map['minimumOrderAmount'], 100.0);
      expect(map['maxOrdersPerSlot'], 15);
    });
  });
}
