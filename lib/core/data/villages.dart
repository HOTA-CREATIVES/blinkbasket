/// A single serviceable village with its delivery-centroid coordinates
/// and the default mandal/district it sits in. Defaults are used by
/// onboarding (before the user edits them) and by the admin seeder.
class Village {
  final String name;
  final double latitude;
  final double longitude;
  final String mandal;
  final String district;
  final String defaultPincode;
  final String deliveryZoneId;

  const Village({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.mandal,
    required this.district,
    required this.defaultPincode,
    required this.deliveryZoneId,
  });
}

/// Single source of truth for the serviceable villages and their centroid
/// coordinates. Previously duplicated across [VillageDropdown], the cart
/// checkout fallback, the address-book reverse-geocoding match, and
/// [CustomerHelper.findClosestVillage] — any new village only needs to be
/// added here.
class Villages {
  Villages._();

  static const String defaultDistrict = 'West Godavari';
  static const String defaultZoneId = 'zone_west_godavari_1';

  static const List<Village> all = [
    Village(
      name: 'Bhimavaram',
      latitude: 16.5449,
      longitude: 81.5212,
      mandal: 'Bhimavaram',
      district: defaultDistrict,
      defaultPincode: '534201',
      deliveryZoneId: defaultZoneId,
    ),
    Village(
      name: 'Veeravasaram',
      latitude: 16.5050,
      longitude: 81.6062,
      mandal: 'Veeravasaram',
      district: defaultDistrict,
      defaultPincode: '534245',
      deliveryZoneId: defaultZoneId,
    ),
    Village(
      name: 'Rayakuduru',
      latitude: 16.5861,
      longitude: 81.5034,
      mandal: 'Bhimavaram',
      district: defaultDistrict,
      defaultPincode: '534208',
      deliveryZoneId: defaultZoneId,
    ),
    Village(
      name: 'Srungavruksham',
      latitude: 16.5015,
      longitude: 81.5492,
      mandal: 'Bhimavaram',
      district: defaultDistrict,
      defaultPincode: '534204',
      deliveryZoneId: defaultZoneId,
    ),
    Village(
      name: 'Mentada',
      latitude: 16.6341,
      longitude: 81.6500,
      mandal: 'Veeravasaram',
      district: defaultDistrict,
      defaultPincode: '534250',
      deliveryZoneId: defaultZoneId,
    ),
  ];

  static List<String> get names => all.map((v) => v.name).toList(growable: false);

  /// Case- and whitespace-insensitive: the village string stored on a user
  /// doc drifts in casing across onboarding/checkout, and an exact match
  /// silently defeats the coordinate fallback at checkout.
  static Village? byName(String name) {
    final needle = name.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final v in all) {
      if (v.name.trim().toLowerCase() == needle) return v;
    }
    return null;
  }
}