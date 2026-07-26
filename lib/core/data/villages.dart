/// A single serviceable village with its delivery-centroid coordinates.
class Village {
  final String name;
  final double latitude;
  final double longitude;

  const Village({required this.name, required this.latitude, required this.longitude});
}

/// Single source of truth for the serviceable villages and their centroid
/// coordinates. Previously duplicated across [VillageDropdown], the cart
/// checkout fallback, the address-book reverse-geocoding match, and
/// [CustomerHelper.findClosestVillage] — any new village only needs to be
/// added here.
class Villages {
  Villages._();

  static const List<Village> all = [
    Village(name: 'Bhimavaram', latitude: 16.5449, longitude: 81.5212),
    Village(name: 'Veeravasaram', latitude: 16.5050, longitude: 81.6062),
    Village(name: 'Rayakuduru', latitude: 16.5861, longitude: 81.5034),
    Village(name: 'Srungavruksham', latitude: 16.5015, longitude: 81.5492),
    Village(name: 'Mentada', latitude: 16.6341, longitude: 81.6500),
  ];

  static List<String> get names => all.map((v) => v.name).toList(growable: false);

  static Village? byName(String name) {
    for (final v in all) {
      if (v.name == name) return v;
    }
    return null;
  }
}
