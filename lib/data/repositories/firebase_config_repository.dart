import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/app_config.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/repositories/config_repository.dart';
import '../models/app_config_dto.dart';
import '../models/dashboard_stats_dto.dart';

class FirebaseConfigRepository implements ConfigRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<AppConfig> streamAppConfig() {
    return _db.collection('config').doc('app').snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      return AppConfigDto.fromMap(data);
    });
  }

  @override
  Stream<DashboardStats> streamDashboardStats() {
    return _db.collection('config').doc('dashboard_stats').snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      return DashboardStatsDto.fromMap(data);
    });
  }

  @override
  Future<void> updateAppConfig(AppConfig config) async {
    try {
      final dto = AppConfigDto(
        storeOpen: config.storeOpen,
        deliveryFee: config.deliveryFee,
        freeDeliveryAbove: config.freeDeliveryAbove,
        updatedAt: config.updatedAt,
        etaLabel: config.etaLabel,
        riderPayoutPerDelivery: config.riderPayoutPerDelivery,
        supportPhone: config.supportPhone,
        supportWhatsapp: config.supportWhatsapp,
        categories: config.categories,
        maintenanceMode: config.maintenanceMode,
        minimumOrderAmount: config.minimumOrderAmount,
        maxOrdersPerSlot: config.maxOrdersPerSlot,
        serviceZones: config.serviceZones,
        privacyPolicy: config.privacyPolicy,
        termsAndConditions: config.termsAndConditions,
      );
      await _db.collection('config').doc('app').set(dto.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw Exception("Failed to update config: $e");
    }
  }
}

