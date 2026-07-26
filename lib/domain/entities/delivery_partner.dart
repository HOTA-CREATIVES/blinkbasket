import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryPartner {
  final String uid;
  final String name;
  final String phone;
  final String? avatarUrl;
  final String? vehicleDetails;
  final String? vehicleNo;
  final String? licenseNo;
  final bool onDuty;
  final List<String> currentOrders;
  final int completedOrders;
  final double earnings;
  final String? currentVillage;
  final List<String> deliveryZones;
  final bool isActive;
  final List<String> fcmTokens;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeliveryPartner({
    required this.uid,
    required this.name,
    required this.phone,
    this.avatarUrl,
    this.vehicleDetails,
    this.vehicleNo,
    this.licenseNo,
    this.onDuty = true,
    this.currentOrders = const [],
    this.completedOrders = 0,
    this.earnings = 0.0,
    this.currentVillage,
    this.deliveryZones = const [],
    this.isActive = true,
    this.fcmTokens = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeliveryPartner.fromMap(Map<String, dynamic> map, String documentId) {
    return DeliveryPartner(
      uid: map['uid'] as String? ?? documentId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      vehicleDetails: map['vehicleDetails'] as String?,
      vehicleNo: map['vehicleNo'] as String?,
      licenseNo: map['licenseNo'] as String?,
      onDuty: map['onDuty'] ?? true,
      currentOrders: map['currentOrders'] != null
          ? List<String>.from(map['currentOrders'] as List)
          : const [],
      completedOrders: (map['completedOrders'] as num?)?.toInt() ?? 0,
      earnings: (map['earnings'] as num?)?.toDouble() ?? 0.0,
      currentVillage: map['currentVillage'] as String?,
      deliveryZones: map['deliveryZones'] != null
          ? List<String>.from(map['deliveryZones'] as List)
          : const [],
      isActive: map['isActive'] ?? true,
      fcmTokens: map['fcmTokens'] != null
          ? List<String>.from(map['fcmTokens'] as List)
          : const [],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (vehicleDetails != null) 'vehicleDetails': vehicleDetails,
      if (vehicleNo != null) 'vehicleNo': vehicleNo,
      if (licenseNo != null) 'licenseNo': licenseNo,
      'onDuty': onDuty,
      'currentOrders': currentOrders,
      'completedOrders': completedOrders,
      'earnings': earnings,
      if (currentVillage != null) 'currentVillage': currentVillage,
      'deliveryZones': deliveryZones,
      'isActive': isActive,
      'fcmTokens': fcmTokens,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DeliveryPartner copyWith({
    String? uid,
    String? name,
    String? phone,
    String? avatarUrl,
    String? vehicleDetails,
    String? vehicleNo,
    String? licenseNo,
    bool? onDuty,
    List<String>? currentOrders,
    int? completedOrders,
    double? earnings,
    String? currentVillage,
    List<String>? deliveryZones,
    bool? isActive,
    List<String>? fcmTokens,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryPartner(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      vehicleDetails: vehicleDetails ?? this.vehicleDetails,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      licenseNo: licenseNo ?? this.licenseNo,
      onDuty: onDuty ?? this.onDuty,
      currentOrders: currentOrders ?? this.currentOrders,
      completedOrders: completedOrders ?? this.completedOrders,
      earnings: earnings ?? this.earnings,
      currentVillage: currentVillage ?? this.currentVillage,
      deliveryZones: deliveryZones ?? this.deliveryZones,
      isActive: isActive ?? this.isActive,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
