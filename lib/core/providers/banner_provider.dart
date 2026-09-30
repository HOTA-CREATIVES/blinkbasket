import 'package:flutter/foundation.dart';
import '../../domain/entities/banner_item.dart';
import '../../domain/repositories/banner_repository.dart';
import '../../data/repositories/firebase_banner_repository.dart';
import '../utils/shared_stream.dart';
import '../utils/app_exception.dart';

class BannerProvider with ChangeNotifier {
  final BannerRepository _bannerRepository;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  BannerProvider({BannerRepository? repository})
      : _bannerRepository = repository ?? FirebaseBannerRepository();

  late final SharedStream<List<BannerItem>> _activeBanners =
      SharedStream(() => _bannerRepository.streamActiveBanners());
  late final SharedStream<List<BannerItem>> _allBanners =
      SharedStream(() => _bannerRepository.streamAllBanners());

  /// Stable, shared streams: safe to read from build().
  Stream<List<BannerItem>> streamActiveBanners() => _activeBanners.stream;

  Stream<List<BannerItem>> streamAllBanners() => _allBanners.stream;

  /// Banners are readable only when signed in, so the listeners die on
  /// sign-out; drop them so the next login reconnects.
  void resetSession() {
    _activeBanners.reset();
    _allBanners.reset();
  }

  @override
  void dispose() {
    _activeBanners.dispose();
    _allBanners.dispose();
    super.dispose();
  }

  Future<bool> addBanner(BannerItem b) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _bannerRepository.addBanner(b);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = userMessageFor(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBanner(BannerItem b) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _bannerRepository.updateBanner(b);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = userMessageFor(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBanner(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _bannerRepository.deleteBanner(id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = userMessageFor(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
