import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/banner_item.dart';
import '../../domain/repositories/banner_repository.dart';
import '../models/banner_dto.dart';

class FirebaseBannerRepository implements BannerRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<List<BannerItem>> streamActiveBanners() {
    // Stream active banners, sorted by sortOrder client-side to avoid extra indices.
    return _db
        .collection('banners')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => BannerItemDto.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    });
  }

  @override
  Stream<List<BannerItem>> streamAllBanners() {
    return _db
        .collection('banners')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BannerItemDto.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Future<void> addBanner(BannerItem b) async {
    try {
      final dto = BannerItemDto.fromEntity(b);
      await _db.collection('banners').add(dto.toMap());
    } catch (e) {
      throw Exception("Failed to add banner: $e");
    }
  }

  @override
  Future<void> updateBanner(BannerItem b) async {
    try {
      final dto = BannerItemDto.fromEntity(b);
      await _db.collection('banners').doc(b.id).update(dto.toMap());
    } catch (e) {
      throw Exception("Failed to update banner: $e");
    }
  }

  @override
  Future<void> deleteBanner(String id) async {
    try {
      await _db.collection('banners').doc(id).delete();
    } catch (e) {
      throw Exception("Failed to delete banner: $e");
    }
  }
}
