import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/dashboard_stats.dart';

class DashboardStatsDto extends DashboardStats {
  DashboardStatsDto({
    required super.activeOrdersCount,
    required super.activeRidersCount,
    required super.completedRevenue,
    required super.productCount,
    required super.lastUpdated,
  });

  factory DashboardStatsDto.fromMap(Map<String, dynamic> map) {
    return DashboardStatsDto(
      activeOrdersCount: map['activeOrdersCount'] ?? 0,
      activeRidersCount: map['activeRidersCount'] ?? 0,
      completedRevenue: (map['completedRevenue'] ?? map['totalRevenue'] ?? 0.0).toDouble(),
      productCount: map['productCount'] ?? 0,
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'activeOrdersCount': activeOrdersCount,
      'activeRidersCount': activeRidersCount,
      'completedRevenue': completedRevenue,
      'productCount': productCount,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }
}
