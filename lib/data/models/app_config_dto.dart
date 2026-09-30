import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/app_config.dart';
import '../../domain/entities/service_zone.dart';

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
    super.maintenanceMode,
    super.minimumOrderAmount,
    super.maxOrdersPerSlot,
    super.serviceZones,
    super.privacyPolicy,
    super.termsAndConditions,
  });

  /// Blank / non-string values mean "not configured" so the bundled default
  /// text is used instead of an empty page.
  static String? _nonBlank(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

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
      maintenanceMode: map['maintenanceMode'] ?? false,
      minimumOrderAmount: (map['minimumOrderAmount'] ?? 0.0).toDouble(),
      maxOrdersPerSlot: (map['maxOrdersPerSlot'] as num?)?.toInt() ?? 20,
      serviceZones: (map['serviceZones'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ServiceZone.fromMap)
              .where((z) => z.name.isNotEmpty)
              .toList() ??
          const [],
      privacyPolicy: _nonBlank(map['privacyPolicy']),
      termsAndConditions: _nonBlank(map['termsAndConditions']),
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
      'maintenanceMode': maintenanceMode,
      'minimumOrderAmount': minimumOrderAmount,
      'maxOrdersPerSlot': maxOrdersPerSlot,
      'serviceZones': serviceZones.map((z) => z.toMap()).toList(),
      'privacyPolicy': privacyPolicy,
      'termsAndConditions': termsAndConditions,
    };
  }
}

