/// Where a rider was when they took an action (picked up, set off, handed over).
/// Sent with the action so the server can record it as proof.
class RiderLocation {
  final double lat;
  final double lng;

  /// Estimated error of the reading in metres, when the device reports it.
  final double? accuracyMeters;

  const RiderLocation({
    required this.lat,
    required this.lng,
    this.accuracyMeters,
  });

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        if (accuracyMeters != null) 'accuracy': accuracyMeters,
      };
}
