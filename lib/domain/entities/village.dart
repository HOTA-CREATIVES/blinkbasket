import 'package:cloud_firestore/cloud_firestore.dart';

class Village {
  final String villageId;
  final String villageName;
  final String mandal;
  final String district;
  final bool isActive;
  final bool deliveryAvailable;
  final double deliveryFee;
  final String estimatedTime;
  final double minimumOrder;
  final List<String> riderIds;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  Village({
    required this.villageId,
    required this.villageName,
    required this.mandal,
    required this.district,
    this.isActive = true,
    this.deliveryAvailable = true,
    this.deliveryFee = 20.0,
    this.estimatedTime = '30 mins',
    this.minimumOrder = 0.0,
    this.riderIds = const [],
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory Village.fromMap(Map<String, dynamic> map, String docId) {
    return Village(
      villageId: map['villageId'] as String? ?? docId,
      villageName: map['villageName'] ?? map['name'] ?? '',
      mandal: map['mandal'] ?? '',
      district: map['district'] ?? 'West Godavari',
      isActive: map['isActive'] ?? true,
      deliveryAvailable: map['deliveryAvailable'] ?? true,
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 20.0,
      estimatedTime: map['estimatedTime'] ?? '30 mins',
      minimumOrder: (map['minimumOrder'] as num?)?.toDouble() ?? 0.0,
      riderIds: map['riderIds'] != null
          ? List<String>.from(map['riderIds'] as List)
          : const [],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'villageId': villageId,
      'villageName': villageName,
      'mandal': mandal,
      'district': district,
      'isActive': isActive,
      'deliveryAvailable': deliveryAvailable,
      'deliveryFee': deliveryFee,
      'estimatedTime': estimatedTime,
      'minimumOrder': minimumOrder,
      'riderIds': riderIds,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
