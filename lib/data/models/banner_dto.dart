import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/banner_item.dart';

class BannerItemDto extends BannerItem {
  const BannerItemDto({
    required super.id,
    required super.imageUrl,
    super.category,
    required super.isActive,
    required super.sortOrder,
    required super.createdAt,
  });

  factory BannerItemDto.fromMap(Map<String, dynamic> map, String documentId) {
    return BannerItemDto(
      id: documentId,
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] as String?,
      isActive: map['isActive'] ?? true,
      sortOrder: map['sortOrder'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'category': category,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BannerItemDto.fromEntity(BannerItem banner) {
    return BannerItemDto(
      id: banner.id,
      imageUrl: banner.imageUrl,
      category: banner.category,
      isActive: banner.isActive,
      sortOrder: banner.sortOrder,
      createdAt: banner.createdAt,
    );
  }
}
