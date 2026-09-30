import 'package:flutter/foundation.dart';
import '../../domain/entities/app_config.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/service_zone.dart';
import '../../domain/repositories/config_repository.dart';
import '../../data/repositories/firebase_config_repository.dart';
import '../utils/shared_stream.dart';

class ConfigProvider with ChangeNotifier {
  final ConfigRepository _configRepository;

  bool _isLoading = false;
  String? _errorMessage;

  /// Latest service zones cached from the config stream so that callers
  /// (e.g. checkout, address screens) can read them synchronously without
  /// awaiting a Future. Falls back to empty list until the stream fires.
  List<ServiceZone> _latestServiceZones = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Synchronous access to the most recently streamed service zones.
  /// Callers should fall back to [Villages.all] from [villages.dart] when
  /// this list is empty (i.e. the stream hasn't loaded yet).
  List<ServiceZone> get latestServiceZones => _latestServiceZones;

  ConfigProvider({ConfigRepository? repository})
      : _configRepository = repository ?? FirebaseConfigRepository();

  /// Single shared config listener, memoized for the provider's lifetime.
  /// Callers hit this from inside `build()` (and from a 1s countdown timer),
  /// so handing out a fresh Firestore listener per call churned billed reads
  /// and dropped the initial-data frame on every rebuild.
  late final SharedStream<AppConfig> _appConfig = SharedStream<AppConfig>(
    () => _configRepository.streamAppConfig().map((config) {
      // Keep the synchronous cache up to date whenever the stream emits.
      _latestServiceZones = config.serviceZones;
      return config;
    }),
  );

  // Was `.asBroadcastStream()`: no replay for late listeners, and once the
  // Firestore listener died (config is signed-in-only, so any sign-out kills
  // it) it stayed a finished stream — every screen after the next login saw no
  // fees, no store-open flag and no zones until the app restarted.
  Stream<AppConfig> streamAppConfig() => _appConfig.stream;

  /// Drops the cached config/stats listeners (see OrderProvider.resetSession).
  void resetSession() {
    _appConfig.reset();
    _dashboardStats.reset();
    _latestServiceZones = [];
  }

  // One shared listener with a stable Stream instance: the admin dashboard and
  // profile read this inside build(), and used to open a fresh Firestore
  // listener on every rebuild (tab switch, search keystroke, ...).
  late final SharedStream<DashboardStats> _dashboardStats =
      SharedStream<DashboardStats>(_configRepository.streamDashboardStats);

  Stream<DashboardStats> streamDashboardStats() => _dashboardStats.stream;

  @override
  void dispose() {
    _appConfig.dispose();
    _dashboardStats.dispose();
    super.dispose();
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

