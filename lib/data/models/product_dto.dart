import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product.dart';

class ProductDto extends Product {
  final String? brand;
  final double? rating;
  final int? reviewCount;

  ProductDto({
    required super.id,
    required super.name,
    required super.description,
    required super.price,
    super.discountedPrice,
    required super.imageUrl,
    super.imageUrls = const [],
    required super.category,
    required super.stock,
    required super.unit,
    super.requiresPrescription,
    super.physicalStock,
    super.reservedStock,
    super.availableStock,
    super.lowStockThreshold,
    super.isAvailable = true,
    super.isFeatured = false,
    super.tags = const [],
    this.brand,
    this.rating,
    this.reviewCount,
  });

  factory ProductDto.fromMap(Map<String, dynamic> map, String documentId) {
    final stockVal = map['stock'] ?? 0;
    final phys = map['physicalStock'] ?? stockVal;
    final res = map['reservedStock'] ?? 0;
    final avail = map['availableStock'] ?? (phys - res);

    return ProductDto(
      id: documentId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      discountedPrice: (map['discountedPrice'] as num?)?.toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      imageUrls: map['imageUrls'] != null ? List<String>.from(map['imageUrls']) : const [],
      category: map['category'] ?? '',
      stock: map['stock'] ?? 0,
      unit: map['unit'] ?? '',
      requiresPrescription: map['requiresPrescription'] ?? false,
      physicalStock: phys,
      reservedStock: res,
      availableStock: avail,
      lowStockThreshold: map['lowStockThreshold'] ?? 10,
      isAvailable: map['isAvailable'] ?? true,
      isFeatured: map['isFeatured'] ?? false,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : const [],
      brand: map['brand'] as String?,
      rating: (map['rating'] as num?)?.toDouble(),
      reviewCount: (map['reviewCount'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      if (discountedPrice != null) 'discountedPrice': discountedPrice,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'category': category,
      'stock': stock,
      'unit': unit,
      'requiresPrescription': requiresPrescription,
      'physicalStock': physicalStock,
      'reservedStock': reservedStock,
      'availableStock': availableStock,
      'lowStockThreshold': lowStockThreshold,
      'isAvailable': isAvailable,
      'isFeatured': isFeatured,
      'tags': tags,
      if (brand != null) 'brand': brand,
      if (rating != null) 'rating': rating,
      if (reviewCount != null) 'reviewCount': reviewCount,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ProductDto.fromEntity(Product product) {
    return ProductDto(
      id: product.id,
      name: product.name,
      description: product.description,
      price: product.price,
      discountedPrice: product.discountedPrice,
      imageUrl: product.imageUrl,
      imageUrls: product.imageUrls,
      category: product.category,
      stock: product.stock,
      unit: product.unit,
      requiresPrescription: product.requiresPrescription,
      physicalStock: product.physicalStock,
      reservedStock: product.reservedStock,
      availableStock: product.availableStock,
      lowStockThreshold: product.lowStockThreshold,
      isAvailable: product.isAvailable,
      isFeatured: product.isFeatured,
      tags: product.tags,
    );
  }
}
