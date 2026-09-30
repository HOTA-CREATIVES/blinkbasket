import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

/// Address details for a pinned point, used to pre-fill the address form.
class AddressSuggestion {
  final String road;
  final String mandal;
  final String district;
  final String pincode;
  final String label;

  const AddressSuggestion({
    this.road = '',
    this.mandal = '',
    this.district = '',
    this.pincode = '',
    this.label = '',
  });

  factory AddressSuggestion.fromMap(Map<String, dynamic> map) => AddressSuggestion(
        road: (map['road'] as String?) ?? '',
        mandal: (map['mandal'] as String?) ?? '',
        district: (map['district'] as String?) ?? '',
        pincode: (map['pincode'] as String?) ?? '',
        label: (map['label'] as String?) ?? '',
      );

  bool get isEmpty =>
      road.isEmpty && mandal.isEmpty && district.isEmpty && pincode.isEmpty;
}

/// A place returned by an address search.
class PlaceSuggestion {
  final String label;
  final double lat;
  final double lng;

  /// The delivery zone the place is in, or null when it is outside them all.
  final String? zone;

  const PlaceSuggestion({
    required this.label,
    required this.lat,
    required this.lng,
    this.zone,
  });

  bool get isDeliverable => zone != null;

  static PlaceSuggestion? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final label = raw['label'];
    final lat = raw['lat'];
    final lng = raw['lng'];
    if (label is! String || label.isEmpty || lat is! num || lng is! num) return null;
    return PlaceSuggestion(
      label: label,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      zone: raw['zone'] as String?,
    );
  }
}

/// Outcome of an address search: either places or a message for the user.
class PlaceSearchResult {
  final List<PlaceSuggestion> places;
  final String? error;

  const PlaceSearchResult.success(this.places) : error = null;
  const PlaceSearchResult.failure(this.error) : places = const [];

  bool get isSuccess => error == null;
}

/// Address lookup through the `reverseGeocode` / `searchAddress` Cloud
/// Functions, which cache results and identify the app to the geocoder. The
/// app never calls a public geocoder directly.
class GeocodingService {
  static const Duration timeout = Duration(seconds: 10);

  /// Invokes a callable and returns its map result. Injectable for tests.
  final Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data) _call;

  GeocodingService({
    Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data)? call,
  }) : _call = call ?? _callFunction;

  static Future<Map<String, dynamic>> _callFunction(
      String name, Map<String, dynamic> data) async {
    final result = await FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable(name)
        .call<dynamic>(data)
        .timeout(timeout);
    return Map<String, dynamic>.from(result.data as Map);
  }

  /// Address details for a point, or null when the lookup fails for any reason
  /// (offline, geocoder down, nothing found). Pre-filling is a convenience —
  /// the caller always leaves the fields editable.
  Future<AddressSuggestion?> reverse(double lat, double lng) async {
    try {
      final map = await _call('reverseGeocode', {'lat': lat, 'lng': lng});
      final suggestion = AddressSuggestion.fromMap(map);
      return suggestion.isEmpty ? null : suggestion;
    } catch (_) {
      return null;
    }
  }

  /// Searches for an address or landmark inside the delivery area.
  Future<PlaceSearchResult> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      return const PlaceSearchResult.success([]);
    }
    try {
      final map = await _call('searchAddress', {'query': trimmed});
      final raw = map['places'];
      final places = <PlaceSuggestion>[
        if (raw is List)
          for (final item in raw)
            if (PlaceSuggestion.tryParse(item) case final place?) place,
      ];
      return PlaceSearchResult.success(places);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return const PlaceSearchResult.failure(
            'Search is unavailable right now. Pin your spot on the map instead.');
      }
      if (e.code == 'resource-exhausted') {
        return const PlaceSearchResult.failure('Too many searches. Wait a moment and try again.');
      }
      return const PlaceSearchResult.failure("Couldn't search. Please try again.");
    } on TimeoutException {
      return const PlaceSearchResult.failure(
          'Search is taking too long. Check your connection and try again.');
    } catch (_) {
      return const PlaceSearchResult.failure("Couldn't search. Please try again.");
    }
  }
}
