import '../entities/banner_item.dart';

abstract class BannerRepository {
  Stream<List<BannerItem>> streamActiveBanners();
  Stream<List<BannerItem>> streamAllBanners();
  Future<void> addBanner(BannerItem b);
  Future<void> updateBanner(BannerItem b);
  Future<void> deleteBanner(String id);
}
