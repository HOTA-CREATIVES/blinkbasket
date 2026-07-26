class Product {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> imageUrls;
  final String imageUrl; // fallback/primary image URL
  final double price;
  final double? discountedPrice;
  final String unit;
  final int stock;

  /// Real-time calculated stock counters
  final int physicalStock;
  final int reservedStock;
  final int availableStock;
  final int lowStockThreshold;

  final bool isAvailable;
  final bool isFeatured;
  final List<String> tags;
  final bool requiresPrescription;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.imageUrls = const [],
    required this.imageUrl,
    required this.price,
    this.discountedPrice,
    required this.unit,
    required this.stock,
    int? physicalStock,
    int? reservedStock,
    int? availableStock,
    this.lowStockThreshold = 10,
    this.isAvailable = true,
    this.isFeatured = false,
    this.tags = const [],
    this.requiresPrescription = false,
  })  : physicalStock = physicalStock ?? stock,
        reservedStock = reservedStock ?? 0,
        availableStock = availableStock ?? (physicalStock ?? stock) - (reservedStock ?? 0);
}
