import 'package:flutter/foundation.dart';
import '../../domain/entities/banner_item.dart';
import '../../domain/repositories/banner_repository.dart';
import '../../data/repositories/firebase_banner_repository.dart';

class BannerProvider with ChangeNotifier {
  final BannerRepository _bannerRepository;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  BannerProvider({BannerRepository? repository})
      : _bannerRepository = repository ?? FirebaseBannerRepository();

  Stream<List<BannerItem>> streamActiveBanners() {
    return _bannerRepository.streamActiveBanners();
  }

  Stream<List<BannerItem>> streamAllBanners() {
    return _bannerRepository.streamAllBanners();
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
      _errorMessage = e.toString();
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
      _errorMessage = e.toString();
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
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
