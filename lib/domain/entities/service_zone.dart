/// A single admin-configurable delivery zone defined by a centroid point and
/// a radius circle. Stored in Firestore under `/config/app.serviceZones`.
///
/// The [name] is also used as the "village" label everywhere in the app
/// (customer dropdown, rider assignment matching in Cloud Functions) so it
/// must be kept consistent when updated.
class ServiceZone {
  final String name;
  final double lat;
  final double lng;

  /// Service radius in kilometres.
  final double radiusKm;

  const ServiceZone({
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusKm,
  });

  factory ServiceZone.fromMap(Map<String, dynamic> map) {
    return ServiceZone(
      name: (map['name'] as String?) ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      radiusKm: (map['radiusKm'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lat': lat,
      'lng': lng,
      'radiusKm': radiusKm,
    };
  }

  ServiceZone copyWith({
    String? name,
    double? lat,
    double? lng,
    double? radiusKm,
  }) {
    return ServiceZone(
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusKm: radiusKm ?? this.radiusKm,
    );
  }

  @override
  String toString() => 'ServiceZone($name, $lat, $lng, r=${radiusKm}km)';
}
