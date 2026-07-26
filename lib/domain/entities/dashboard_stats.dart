class DashboardStats {
  final int activeOrdersCount;
  final int activeRidersCount;
  final double completedRevenue;
  final int productCount;
  final DateTime lastUpdated;

  DashboardStats({
    required this.activeOrdersCount,
    required this.activeRidersCount,
    required this.completedRevenue,
    required this.productCount,
    required this.lastUpdated,
  });
}
