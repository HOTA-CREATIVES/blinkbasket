import 'package:cloud_firestore/cloud_firestore.dart';

class AddressModel {
  final String id;
  final String name;
  final String addressLine1;
  final String? addressLine2;
  final String pinCode;
  final String village;
  final String mandal;
  final String? district;
  final String? landmark;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  AddressModel({
    required this.id,
    required this.name,
    required this.addressLine1,
    this.addressLine2,
    required this.pinCode,
    required this.village,
    required this.mandal,
    this.district,
    this.landmark,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      addressLine1: map['addressLine1'] ?? '',
      addressLine2: map['addressLine2'],
      pinCode: map['pinCode'] ?? map['pincode'] ?? '',
      village: map['village'] ?? '',
      mandal: map['mandal'] ?? '',
      district: map['district'],
      landmark: map['landmark'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isDefault: map['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'addressLine1': addressLine1,
      if (addressLine2 != null) 'addressLine2': addressLine2,
      'pinCode': pinCode,
      'pincode': pinCode,
      'village': village,
      'mandal': mandal,
      if (district != null) 'district': district,
      if (landmark != null) 'landmark': landmark,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'isDefault': isDefault,
    };
  }
}

class UserModel {
  final String uid;
  final String? docId;
  final String name;
  final String email;
  final String phone;
  final String role; // "customer", "admin", "delivery"
  final bool isActive;
  final bool onboardingCompleted;
  final int onboardingStep;

  // Location
  final String village;
  final String? mandal;
  final String? district;
  final bool deliveryAvailable;
  final String? deliveryZoneId;

  // Profile
  final String? avatarUrl;
  final bool notificationsEnabled;

  // Orders summary
  final int totalOrders;
  final double totalSpent;
  final bool firstOrderCompleted;
  final List<String> favoriteProductIds;

  // Device & Timestamps
  final List<String> fcmTokens;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AddressModel> addresses;

  // Delivery partner fields (stored in deliveryPartners/deliveryBoys collection)
  final String? vehicleDetails;
  final String? vehicleNo;
  final String? licenseNo;
  final bool onDuty;

  UserModel({
    required this.uid,
    this.docId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.isActive = true,
    this.onboardingCompleted = false,
    this.onboardingStep = 1,
    required this.village,
    this.mandal,
    this.district,
    this.deliveryAvailable = true,
    this.deliveryZoneId,
    this.avatarUrl,
    this.notificationsEnabled = true,
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    this.firstOrderCompleted = false,
    this.favoriteProductIds = const [],
    this.fcmTokens = const [],
    required this.createdAt,
    DateTime? updatedAt,
    this.addresses = const [],
    this.vehicleDetails,
    this.vehicleNo,
    this.licenseNo,
    this.onDuty = false,
  }) : updatedAt = updatedAt ?? createdAt;

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    final List<dynamic>? addressesRaw = map['addresses'];
    final List<AddressModel> addressesList = addressesRaw != null
        ? addressesRaw
            .map((a) => AddressModel.fromMap(Map<String, dynamic>.from(a)))
            .toList()
        : const [];

    return UserModel(
      uid: map['uid'] as String? ?? documentId,
      docId: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'customer',
      isActive: map['isActive'] ?? true,
      onboardingCompleted: map['onboardingCompleted'] ?? false,
      onboardingStep: (map['onboardingStep'] as num?)?.toInt() ?? 1,
      village: map['village'] ?? '',
      mandal: map['mandal'] as String?,
      district: map['district'] as String?,
      deliveryAvailable: map['deliveryAvailable'] ?? true,
      deliveryZoneId: map['deliveryZoneId'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      totalOrders: (map['totalOrders'] as num?)?.toInt() ?? 0,
      totalSpent: (map['totalSpent'] as num?)?.toDouble() ?? 0.0,
      firstOrderCompleted: map['firstOrderCompleted'] ?? false,
      favoriteProductIds: map['favoriteProductIds'] != null
          ? List<String>.from(map['favoriteProductIds'] as List)
          : const [],
      fcmTokens: map['fcmTokens'] != null
          ? List<String>.from(map['fcmTokens'] as List)
          : const [],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      addresses: addressesList,
      vehicleDetails: map['vehicleDetails'] as String?,
      vehicleNo: map['vehicleNo'] as String?,
      licenseNo: map['licenseNo'] as String?,
      onDuty: map['onDuty'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'isActive': isActive,
      'onboardingCompleted': onboardingCompleted,
      'onboardingStep': onboardingStep,
      'village': village,
      if (mandal != null) 'mandal': mandal,
      if (district != null) 'district': district,
      'deliveryAvailable': deliveryAvailable,
      if (deliveryZoneId != null) 'deliveryZoneId': deliveryZoneId,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'notificationsEnabled': notificationsEnabled,
      'totalOrders': totalOrders,
      'totalSpent': totalSpent,
      'firstOrderCompleted': firstOrderCompleted,
      'favoriteProductIds': favoriteProductIds,
      'fcmTokens': fcmTokens,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'addresses': addresses.map((a) => a.toMap()).toList(),
      if (vehicleDetails != null) 'vehicleDetails': vehicleDetails,
      if (vehicleNo != null) 'vehicleNo': vehicleNo,
      if (licenseNo != null) 'licenseNo': licenseNo,
      'onDuty': onDuty,
    };
  }

  UserModel copyWith({
    String? uid,
    String? docId,
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
    bool? onboardingCompleted,
    int? onboardingStep,
    String? village,
    String? mandal,
    String? district,
    bool? deliveryAvailable,
    String? deliveryZoneId,
    String? avatarUrl,
    bool? notificationsEnabled,
    int? totalOrders,
    double? totalSpent,
    bool? firstOrderCompleted,
    List<String>? favoriteProductIds,
    List<String>? fcmTokens,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AddressModel>? addresses,
    String? vehicleDetails,
    String? vehicleNo,
    String? licenseNo,
    bool? onDuty,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      docId: docId ?? this.docId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      village: village ?? this.village,
      mandal: mandal ?? this.mandal,
      district: district ?? this.district,
      deliveryAvailable: deliveryAvailable ?? this.deliveryAvailable,
      deliveryZoneId: deliveryZoneId ?? this.deliveryZoneId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      firstOrderCompleted: firstOrderCompleted ?? this.firstOrderCompleted,
      favoriteProductIds: favoriteProductIds ?? this.favoriteProductIds,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addresses: addresses ?? this.addresses,
      vehicleDetails: vehicleDetails ?? this.vehicleDetails,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      licenseNo: licenseNo ?? this.licenseNo,
      onDuty: onDuty ?? this.onDuty,
    );
  }
}
