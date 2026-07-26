import '../entities/app_config.dart';
import '../entities/dashboard_stats.dart';

abstract class ConfigRepository {
  Stream<AppConfig> streamAppConfig();
  Stream<DashboardStats> streamDashboardStats();
  Future<void> updateAppConfig(AppConfig config);
}
