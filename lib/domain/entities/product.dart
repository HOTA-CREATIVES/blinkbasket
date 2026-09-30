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

  /// What the customer pays per unit: the discount when it is valid
  /// (`0 < discountedPrice < price`), otherwise the list price. Mirrors
  /// `effectivePrice` in the placeOrder Cloud Function, so the price shown is
  /// the price charged.
  double get effectivePrice {
    final discounted = discountedPrice;
    if (discounted != null && discounted > 0 && discounted < price) {
      return discounted;
    }
    return price;
  }

  /// Whether a valid discount is active.
  bool get hasDiscount => effectivePrice < price;

  /// Whole-number discount percentage, or 0 without a discount.
  int get discountPercent =>
      hasDiscount ? (((price - effectivePrice) / price) * 100).round() : 0;

  /// Units that can be ordered right now: none when the admin switched the
  /// product off, otherwise the non-negative available stock.
  int get sellableStock => !isAvailable
      ? 0
      : (availableStock > 0 ? availableStock : 0);

  /// True when nothing can be ordered (out of stock or switched off).
  bool get isOutOfStock => sellableStock <= 0;
}
