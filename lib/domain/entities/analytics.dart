import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsModel {
  final int totalUsers;
  final int totalOrders;
  final double totalRevenue;
  final int totalProducts;
  final int totalVillages;
  final int totalRiders;
  final int completedOrders;
  final int cancelledOrders;
  final DateTime updatedAt;

  AnalyticsModel({
    this.totalUsers = 0,
    this.totalOrders = 0,
    this.totalRevenue = 0.0,
    this.totalProducts = 0,
    this.totalVillages = 0,
    this.totalRiders = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    required this.updatedAt,
  });

  factory AnalyticsModel.fromMap(Map<String, dynamic> map) {
    return AnalyticsModel(
      totalUsers: (map['totalUsers'] as num?)?.toInt() ?? 0,
      totalOrders: (map['totalOrders'] as num?)?.toInt() ?? 0,
      totalRevenue: (map['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalProducts: (map['totalProducts'] as num?)?.toInt() ?? 0,
      totalVillages: (map['totalVillages'] as num?)?.toInt() ?? 0,
      totalRiders: (map['totalRiders'] as num?)?.toInt() ?? 0,
      completedOrders: (map['completedOrders'] as num?)?.toInt() ?? 0,
      cancelledOrders: (map['cancelledOrders'] as num?)?.toInt() ?? 0,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalUsers': totalUsers,
      'totalOrders': totalOrders,
      'totalRevenue': totalRevenue,
      'totalProducts': totalProducts,
      'totalVillages': totalVillages,
      'totalRiders': totalRiders,
      'completedOrders': completedOrders,
      'cancelledOrders': cancelledOrders,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
