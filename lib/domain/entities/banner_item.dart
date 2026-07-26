class BannerItem {
  final String id;
  final String imageUrl;
  final String? category;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  const BannerItem({
    required this.id,
    required this.imageUrl,
    this.category,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
  });
}
