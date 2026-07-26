import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/app_config.dart';

class AppConfigDto extends AppConfig {
  AppConfigDto({
    required super.storeOpen,
    required super.deliveryFee,
    required super.freeDeliveryAbove,
    required super.updatedAt,
    super.etaLabel,
    super.riderPayoutPerDelivery,
    super.supportPhone,
    super.supportWhatsapp,
    super.categories,
  });

  factory AppConfigDto.fromMap(Map<String, dynamic> map) {
    return AppConfigDto(
      storeOpen: map['storeOpen'] ?? true,
      deliveryFee: (map['deliveryFee'] ?? 30.0).toDouble(),
      freeDeliveryAbove: (map['freeDeliveryAbove'] ?? 300.0).toDouble(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      etaLabel: (map['etaLabel'] as String?)?.trim().isNotEmpty == true
          ? (map['etaLabel'] as String).trim()
          : null,
      riderPayoutPerDelivery: (map['riderPayoutPerDelivery'] ?? 30.0).toDouble(),
      supportPhone: (map['supportPhone'] as String?)?.trim().isNotEmpty == true
          ? (map['supportPhone'] as String).trim()
          : null,
      supportWhatsapp: (map['supportWhatsapp'] as String?)?.trim().isNotEmpty == true
          ? (map['supportWhatsapp'] as String).trim()
          : null,
      categories: (map['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => s.trim().isNotEmpty)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeOpen': storeOpen,
      'deliveryFee': deliveryFee,
      'freeDeliveryAbove': freeDeliveryAbove,
      'updatedAt': FieldValue.serverTimestamp(),
      'etaLabel': etaLabel,
      'riderPayoutPerDelivery': riderPayoutPerDelivery,
      'supportPhone': supportPhone,
      'supportWhatsapp': supportWhatsapp,
      'categories': categories,
    };
  }
}
