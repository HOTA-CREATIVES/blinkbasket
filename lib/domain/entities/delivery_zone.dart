class DeliveryZone {
  final String zoneId;
  final List<String> villageIds;
  final double deliveryFee;
  final double minimumOrder;
  final double freeDeliveryAbove;
  final String estimatedTime;
  final List<String> activeRiders;
  final bool isActive;

  DeliveryZone({
    required this.zoneId,
    required this.villageIds,
    this.deliveryFee = 20.0,
    this.minimumOrder = 0.0,
    this.freeDeliveryAbove = 199.0,
    this.estimatedTime = '30 mins',
    this.activeRiders = const [],
    this.isActive = true,
  });

  factory DeliveryZone.fromMap(Map<String, dynamic> map, String docId) {
    return DeliveryZone(
      zoneId: map['zoneId'] as String? ?? docId,
      villageIds: map['villageIds'] != null
          ? List<String>.from(map['villageIds'] as List)
          : const [],
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 20.0,
      minimumOrder: (map['minimumOrder'] as num?)?.toDouble() ?? 0.0,
      freeDeliveryAbove: (map['freeDeliveryAbove'] as num?)?.toDouble() ?? 199.0,
      estimatedTime: map['estimatedTime'] ?? '30 mins',
      activeRiders: map['activeRiders'] != null
          ? List<String>.from(map['activeRiders'] as List)
          : const [],
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'zoneId': zoneId,
      'villageIds': villageIds,
      'deliveryFee': deliveryFee,
      'minimumOrder': minimumOrder,
      'freeDeliveryAbove': freeDeliveryAbove,
      'estimatedTime': estimatedTime,
      'activeRiders': activeRiders,
      'isActive': isActive,
    };
  }
}
