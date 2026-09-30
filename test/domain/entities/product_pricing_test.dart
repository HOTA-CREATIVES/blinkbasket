import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/domain/entities/product.dart';

Product product({
  double price = 100,
  double? discountedPrice,
  int available = 10,
  bool isAvailable = true,
}) =>
    Product(
      id: 'p1',
      name: 'Milk',
      description: '',
      category: 'Dairy',
      imageUrl: '',
      price: price,
      discountedPrice: discountedPrice,
      unit: '1 L',
      stock: available,
      physicalStock: available,
      availableStock: available,
      isAvailable: isAvailable,
    );

void main() {
  group('Product.effectivePrice (must match placeOrder server-side)', () {
    test('is the list price without a discount', () {
      expect(product().effectivePrice, 100);
      expect(product().hasDiscount, isFalse);
      expect(product().discountPercent, 0);
    });

    test('is the discounted price when it is a valid discount', () {
      final p = product(discountedPrice: 80);
      expect(p.effectivePrice, 80);
      expect(p.hasDiscount, isTrue);
      expect(p.discountPercent, 20);
    });

    test('ignores a discount that is not below the list price, zero or negative', () {
      for (final d in [100.0, 150.0, 0.0, -5.0]) {
        final p = product(discountedPrice: d);
        expect(p.effectivePrice, 100, reason: 'discount $d');
        expect(p.hasDiscount, isFalse, reason: 'discount $d');
      }
    });
  });

  group('Product.sellableStock / isOutOfStock', () {
    test('is the available stock for an available product', () {
      final p = product(available: 7);
      expect(p.sellableStock, 7);
      expect(p.isOutOfStock, isFalse);
    });

    test('is zero when the admin switched the product off, whatever the stock', () {
      final p = product(available: 7, isAvailable: false);
      expect(p.sellableStock, 0);
      expect(p.isOutOfStock, isTrue);
    });

    test('never goes negative when reservations exceed physical stock', () {
      final p = product(available: -3);
      expect(p.sellableStock, 0);
      expect(p.isOutOfStock, isTrue);
    });
  });
}
