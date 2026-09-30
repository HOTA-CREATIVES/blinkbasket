import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/services/geocoding_service.dart';

GeocodingService serviceReturning(Map<String, dynamic> result, [List<(String, Map<String, dynamic>)>? log]) =>
    GeocodingService(call: (name, data) async {
      log?.add((name, data));
      return result;
    });

GeocodingService serviceThrowing(Object error) =>
    GeocodingService(call: (name, data) async => throw error);

void main() {
  group('reverse', () {
    test('maps the callable result and sends the coordinates', () async {
      final log = <(String, Map<String, dynamic>)>[];
      final service = serviceReturning({
        'road': 'Main Road',
        'mandal': 'Bhimavaram Mandal',
        'district': 'West Godavari',
        'pincode': '534201',
        'label': 'Main Road, Bhimavaram',
      }, log);

      final result = await service.reverse(16.5449, 81.5212);

      expect(result?.road, 'Main Road');
      expect(result?.mandal, 'Bhimavaram Mandal');
      expect(result?.district, 'West Godavari');
      expect(result?.pincode, '534201');
      expect(log.single.$1, 'reverseGeocode');
      expect(log.single.$2, {'lat': 16.5449, 'lng': 81.5212});
    });

    test('is null when the geocoder found nothing', () async {
      final service = serviceReturning({'road': '', 'mandal': '', 'district': '', 'pincode': '', 'label': ''});
      expect(await service.reverse(16.5, 81.5), isNull);
    });

    test('is null, not an exception, on any failure (pre-fill is best effort)', () async {
      expect(await serviceThrowing(StateError('offline')).reverse(16.5, 81.5), isNull);
      expect(
        await serviceThrowing(FirebaseFunctionsException(message: 'x', code: 'unavailable'))
            .reverse(16.5, 81.5),
        isNull,
      );
      expect(await serviceThrowing(TimeoutException('slow')).reverse(16.5, 81.5), isNull);
    });
  });

  group('search', () {
    test('parses places and their delivery zone', () async {
      final service = serviceReturning({
        'places': [
          {'label': 'Temple, Bhimavaram', 'lat': 16.546, 'lng': 81.5225, 'zone': 'Bhimavaram'},
          {'label': 'Far Temple', 'lat': 17.5, 'lng': 82.5, 'zone': null},
        ],
      });

      final result = await service.search('temple');

      expect(result.isSuccess, isTrue);
      expect(result.places, hasLength(2));
      expect(result.places[0].isDeliverable, isTrue);
      expect(result.places[0].zone, 'Bhimavaram');
      expect(result.places[1].isDeliverable, isFalse);
    });

    test('skips malformed entries instead of failing the whole search', () async {
      final service = serviceReturning({
        'places': [
          {'label': 'Good', 'lat': 16.5, 'lng': 81.5, 'zone': 'Bhimavaram'},
          {'label': '', 'lat': 16.5, 'lng': 81.5},
          {'label': 'No coords'},
          {'label': 'Bad types', 'lat': '16.5', 'lng': 81.5},
          'not a map',
        ],
      });

      final result = await service.search('good');
      expect(result.places.map((p) => p.label), ['Good']);
    });

    test('does not call the server for a query under 3 characters', () async {
      final log = <(String, Map<String, dynamic>)>[];
      final service = serviceReturning({'places': []}, log);

      final result = await service.search(' ab ');

      expect(result.isSuccess, isTrue);
      expect(result.places, isEmpty);
      expect(log, isEmpty);
    });

    test('trims the query it sends', () async {
      final log = <(String, Map<String, dynamic>)>[];
      await serviceReturning({'places': []}, log).search('  main road  ');
      expect(log.single.$2, {'query': 'main road'});
    });

    test('turns server failures into a message for the user', () async {
      Future<String?> errorFor(Object e) async => (await serviceThrowing(e).search('temple')).error;

      expect(
        await errorFor(FirebaseFunctionsException(message: 'x', code: 'unavailable')),
        contains('unavailable'),
      );
      expect(
        await errorFor(FirebaseFunctionsException(message: 'x', code: 'resource-exhausted')),
        contains('Too many'),
      );
      expect(await errorFor(TimeoutException('slow')), contains('too long'));
      expect(await errorFor(StateError('boom')), "Couldn't search. Please try again.");
      expect((await serviceThrowing(StateError('boom')).search('temple')).places, isEmpty);
    });
  });
}
