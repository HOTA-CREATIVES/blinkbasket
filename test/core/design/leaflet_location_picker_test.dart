import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/design/widgets/leaflet_location_picker.dart';
import 'package:hypermart/core/services/geocoding_service.dart';
import 'package:hypermart/domain/entities/service_zone.dart';

/// A 1x1 transparent PNG, so tiles "load" without touching the network.
final _blankPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class _BlankTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_blankPng);
}

// Inside the built-in Bhimavaram zone (12 km) / far outside every zone.
const _inside = (lat: 16.546, lng: 81.5225);
const _outside = (lat: 18.5, lng: 83.5);

class _Harness {
  final List<(double, double)> confirmed = [];
  final List<String> queries = [];
  Future<PlaceSearchResult> Function(String query)? onSearch;

  GeocodingService get geocoder => GeocodingService(call: (name, data) async {
        final query = data['query'] as String;
        queries.add(query);
        final result = await (onSearch ?? (_) async => const PlaceSearchResult.success([]))(query);
        if (!result.isSuccess) throw StateError(result.error!);
        return {
          'places': [
            for (final p in result.places)
              {'label': p.label, 'lat': p.lat, 'lng': p.lng, 'zone': p.zone},
          ],
        };
      });
}

Future<void> _pump(
  WidgetTester tester,
  _Harness h, {
  ({double lat, double lng}) at = _inside,
  bool pinned = false,
  List<ServiceZone> zones = const [],
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: LeafletLocationPicker(
        initialLat: at.lat,
        initialLng: at.lng,
        initialIsPinned: pinned,
        zones: zones,
        geocoder: h.geocoder,
        tileProvider: _BlankTiles(),
        onConfirmed: (lat, lng) => h.confirmed.add((lat, lng)),
      ),
    ),
  ));
  await tester.pump();
}

ElevatedButton _confirm(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton));

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

void main() {
  testWidgets('says the spot is deliverable, naming the zone, and waits for the pin to move',
      (tester) async {
    final h = _Harness();
    await _pump(tester, h);

    expect(find.text('We deliver here (Bhimavaram)'), findsOneWidget);
    expect(find.text('Move the map to your exact spot'), findsOneWidget);
    expect(_confirm(tester).onPressed, isNull);

    await tester.drag(find.byType(FlutterMap), const Offset(20, 0));
    await tester.pump();

    expect(find.text('Confirm Pinned Location'), findsOneWidget);
    expect(_confirm(tester).onPressed, isNotNull);
  });

  testWidgets('blocks Confirm and explains when the pin is outside every delivery zone',
      (tester) async {
    final h = _Harness();
    await _pump(tester, h, at: _outside, pinned: true);

    expect(find.text("We don't deliver to this spot yet"), findsOneWidget);
    expect(find.text('Move the pin inside the delivery area'), findsOneWidget);
    expect(_confirm(tester).onPressed, isNull);
  });

  testWidgets('uses the admin-configured zones (and their radius) rather than the built-in villages',
      (tester) async {
    final h = _Harness();
    const zone = ServiceZone(name: 'Palakollu', lat: 16.52, lng: 81.73, radiusKm: 4);

    // Deliverable only because the admin added this zone.
    await _pump(tester, h, at: (lat: 16.5205, lng: 81.7305), pinned: true, zones: const [zone]);
    expect(find.text('We deliver here (Palakollu)'), findsOneWidget);
  });

  testWidgets('a village dropped from the admin zones is no longer deliverable', (tester) async {
    final h = _Harness();
    const zone = ServiceZone(name: 'Palakollu', lat: 16.52, lng: 81.73, radiusKm: 4);

    await _pump(tester, h, at: _inside, pinned: true, zones: const [zone]);
    expect(find.text("We don't deliver to this spot yet"), findsOneWidget);
  });

  testWidgets('Confirm reports the pin position and closes', (tester) async {
    final h = _Harness();
    await _pump(tester, h, pinned: true);

    await tester.tap(find.text('Confirm Pinned Location'));
    await tester.pump();

    expect(h.confirmed, hasLength(1));
    expect(h.confirmed.single.$1, closeTo(_inside.lat, 1e-6));
    expect(h.confirmed.single.$2, closeTo(_inside.lng, 1e-6));
  });

  group('address search', () {
    const temple = PlaceSuggestion(
        label: 'Sri Rama Temple, Bhimavaram', lat: 16.5470, lng: 81.5230, zone: 'Bhimavaram');
    const far = PlaceSuggestion(label: 'Far Temple', lat: 18.5, lng: 83.5);

    testWidgets('does not query for fewer than 3 characters', (tester) async {
      final h = _Harness();
      await _pump(tester, h);

      await _type(tester, 'te');
      await tester.pump(const Duration(seconds: 1));

      expect(h.queries, isEmpty);
    });

    testWidgets('debounces typing into a single query', (tester) async {
      final h = _Harness()..onSearch = (q) async => const PlaceSearchResult.success([temple]);
      await _pump(tester, h);

      await _type(tester, 'tem');
      await tester.pump(const Duration(milliseconds: 100));
      await _type(tester, 'temp');
      await tester.pump(const Duration(milliseconds: 100));
      await _type(tester, 'temple');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(h.queries, ['temple']);
    });

    testWidgets('picking a deliverable result moves the pin there and enables Confirm',
        (tester) async {
      final h = _Harness()..onSearch = (q) async => const PlaceSearchResult.success([temple, far]);
      await _pump(tester, h, at: (lat: 16.50, lng: 81.50));

      await _type(tester, 'temple');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.text('Sri Rama Temple, Bhimavaram'), findsOneWidget);
      expect(find.text('Outside our delivery area'), findsOneWidget);

      await tester.tap(find.text('Sri Rama Temple, Bhimavaram'));
      await tester.pump();
      await tester.pump();

      expect(find.text('We deliver here (Bhimavaram)'), findsOneWidget);
      expect(_confirm(tester).onPressed, isNotNull);

      await tester.tap(find.text('Confirm Pinned Location'));
      await tester.pump();
      expect(h.confirmed.single.$1, closeTo(temple.lat, 1e-4));
      expect(h.confirmed.single.$2, closeTo(temple.lng, 1e-4));
    });

    testWidgets('picking a result outside the delivery area does not allow Confirm', (tester) async {
      final h = _Harness()..onSearch = (q) async => const PlaceSearchResult.success([far]);
      await _pump(tester, h);

      await _type(tester, 'far');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.tap(find.text('Far Temple'));
      await tester.pump();
      await tester.pump();

      expect(find.text("We don't deliver to this spot yet"), findsOneWidget);
      expect(_confirm(tester).onPressed, isNull);
    });

    testWidgets('tells the user when nothing matches', (tester) async {
      final h = _Harness();
      await _pump(tester, h);

      await _type(tester, 'zzzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.textContaining('No matches in our delivery area'), findsOneWidget);
    });

    testWidgets('shows a search failure and leaves the map usable', (tester) async {
      final h = _Harness()..onSearch = (q) async => const PlaceSearchResult.failure('boom');
      await _pump(tester, h, pinned: true);

      await _type(tester, 'temple');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.textContaining("Couldn't search"), findsOneWidget);
      expect(_confirm(tester).onPressed, isNotNull);
    });

    testWidgets('ignores a slow earlier search that finishes after a newer one', (tester) async {
      final slow = Completer<PlaceSearchResult>();
      final h = _Harness();
      h.onSearch = (q) => q == 'temple' ? slow.future : Future.value(const PlaceSearchResult.success([far]));
      await _pump(tester, h);

      await _type(tester, 'temple');
      await tester.pump(const Duration(milliseconds: 500));
      await _type(tester, 'temples');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Far Temple'), findsOneWidget);

      slow.complete(const PlaceSearchResult.success([temple]));
      await tester.pump();
      await tester.pump();

      expect(find.text('Sri Rama Temple, Bhimavaram'), findsNothing);
      expect(find.text('Far Temple'), findsOneWidget);
    });

    testWidgets('clearing the search removes the suggestions', (tester) async {
      final h = _Harness()..onSearch = (q) async => const PlaceSearchResult.success([temple]);
      await _pump(tester, h);

      await _type(tester, 'temple');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Sri Rama Temple, Bhimavaram'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();

      expect(find.text('Sri Rama Temple, Bhimavaram'), findsNothing);
    });
  });
}
