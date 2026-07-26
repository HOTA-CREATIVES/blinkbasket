import 'package:flutter/foundation.dart';
import '../../domain/entities/app_config.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/repositories/config_repository.dart';
import '../../data/repositories/firebase_config_repository.dart';

class ConfigProvider with ChangeNotifier {
  final ConfigRepository _configRepository;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ConfigProvider({ConfigRepository? repository})
      : _configRepository = repository ?? FirebaseConfigRepository();

  Stream<AppConfig> streamAppConfig() {
    return _configRepository.streamAppConfig();
  }

  Stream<DashboardStats> streamDashboardStats() {
    return _configRepository.streamDashboardStats();
  }

  Future<bool> updateAppConfig(AppConfig config) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _configRepository.updateAppConfig(config);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
