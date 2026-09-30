import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/data/models/product_dto.dart';

void main() {
  group('ProductDto.fromMap', () {
    test('parses all fields', () {
      final map = <String, dynamic>{
        'name': 'Milk',
        'description': 'Fresh milk',
        'price': 30.0,
        'discountedPrice': 25.0,
        'imageUrl': 'https://example.com/milk.jpg',
        'imageUrls': ['https://example.com/milk1.jpg', 'https://example.com/milk2.jpg'],
        'category': 'Dairy',
        'stock': 50,
        'unit': 'litre',
        'requiresPrescription': false,
        'physicalStock': 45,
        'reservedStock': 5,
        'availableStock': 40,
        'lowStockThreshold': 10,
        'isAvailable': true,
        'isFeatured': true,
        'tags': ['fresh', 'organic'],
        'brand': 'Amul',
        'rating': 4.5,
        'reviewCount': 120,
      };

      final product = ProductDto.fromMap(map, 'p1');

      expect(product.id, 'p1');
      expect(product.name, 'Milk');
      expect(product.description, 'Fresh milk');
      expect(product.price, 30.0);
      expect(product.discountedPrice, 25.0);
      expect(product.imageUrl, 'https://example.com/milk.jpg');
      expect(product.imageUrls.length, 2);
      expect(product.category, 'Dairy');
      expect(product.stock, 50);
      expect(product.unit, 'litre');
      expect(product.requiresPrescription, false);
      expect(product.physicalStock, 45);
      expect(product.reservedStock, 5);
      expect(product.availableStock, 40);
      expect(product.lowStockThreshold, 10);
      expect(product.isAvailable, true);
      expect(product.isFeatured, true);
      expect(product.tags, ['fresh', 'organic']);
      expect(product.brand, 'Amul');
      expect(product.rating, 4.5);
      expect(product.reviewCount, 120);
    });

    test('applies defaults for missing optional fields', () {
      final map = <String, dynamic>{
        'name': 'Bread',
        'description': 'White bread',
        'price': 25.0,
        'imageUrl': 'https://example.com/bread.jpg',
        'category': 'Bakery',
        'stock': 10,
        'unit': 'piece',
      };

      final product = ProductDto.fromMap(map, 'p2');

      expect(product.discountedPrice, isNull);
      expect(product.imageUrls, isEmpty);
      expect(product.requiresPrescription, false);
      expect(product.lowStockThreshold, 10);
      expect(product.isAvailable, true);
      expect(product.isFeatured, false);
      expect(product.tags, isEmpty);
      expect(product.brand, isNull);
      expect(product.rating, isNull);
      expect(product.reviewCount, isNull);
    });

    test('stock field fallback: physicalStock from stock if missing', () {
      final map = <String, dynamic>{
        'name': 'Item',
        'description': 'desc',
        'price': 10.0,
        'imageUrl': 'url',
        'category': 'cat',
        'stock': 25,
        'unit': 'kg',
      };

      final product = ProductDto.fromMap(map, 'p3');

      expect(product.stock, 25);
      expect(product.physicalStock, 25);
      expect(product.reservedStock, 0);
      expect(product.availableStock, 25);
    });

    test('stock fallback: physicalStock and reservedStock provided', () {
      final map = <String, dynamic>{
        'name': 'Item',
        'description': 'desc',
        'price': 10.0,
        'imageUrl': 'url',
        'category': 'cat',
        'stock': 25,
        'unit': 'kg',
        'physicalStock': 30,
        'reservedStock': 5,
      };

      final product = ProductDto.fromMap(map, 'p4');

      expect(product.physicalStock, 30);
      expect(product.reservedStock, 5);
      expect(product.availableStock, 25);
    });

    test('availableStock fallback: computed from physicalStock - reservedStock', () {
      final map = <String, dynamic>{
        'name': 'Item',
        'description': 'desc',
        'price': 10.0,
        'imageUrl': 'url',
        'category': 'cat',
        'stock': 100,
        'unit': 'kg',
        'physicalStock': 40,
        'reservedStock': 10,
      };

      final product = ProductDto.fromMap(map, 'p5');

      expect(product.availableStock, 30);
    });
  });

  group('ProductDto.toMap', () {
    test('serializes all fields correctly', () {
      final product = ProductDto(
        id: 'p1',
        name: 'Milk',
        description: 'Fresh',
        price: 30.0,
        discountedPrice: 25.0,
        imageUrl: 'url',
        imageUrls: ['url1'],
        category: 'Dairy',
        stock: 50,
        unit: 'litre',
        physicalStock: 45,
        reservedStock: 5,
        availableStock: 40,
        brand: 'Amul',
        rating: 4.5,
        reviewCount: 10,
      );

      final map = product.toMap();

      expect(map['name'], 'Milk');
      expect(map['price'], 30.0);
      expect(map['discountedPrice'], 25.0);
      expect(map['imageUrl'], 'url');
      expect(map['category'], 'Dairy');
      expect(map['stock'], 50);
      expect(map['physicalStock'], 45);
      expect(map['reservedStock'], 5);
      expect(map['availableStock'], 40);
      expect(map['brand'], 'Amul');
      expect(map['rating'], 4.5);
      expect(map['reviewCount'], 10);
    });

    test('omits null optional fields', () {
      final product = ProductDto(
        id: 'p1',
        name: 'Item',
        description: 'desc',
        price: 10.0,
        imageUrl: 'url',
        category: 'cat',
        stock: 5,
        unit: 'kg',
      );

      final map = product.toMap();

      expect(map.containsKey('discountedPrice'), false);
      expect(map.containsKey('brand'), false);
      expect(map.containsKey('rating'), false);
      expect(map.containsKey('reviewCount'), false);
    });
  });
}
