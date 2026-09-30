import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/providers/cart_provider.dart';
import 'package:hypermart/core/utils/reorder_helper.dart';
import 'package:hypermart/domain/entities/order.dart';
import 'package:hypermart/domain/entities/product.dart';
import 'package:hypermart/domain/repositories/cart_repository.dart';

class _MemoryCartRepository implements CartRepository {
  Map<String, dynamic>? stored;

  @override
  Future<Map<String, dynamic>?> getCart(String userId) async => stored;

  @override
  Future<void> saveCart(String userId, Map<String, dynamic> cartMap) async {
    stored = cartMap;
  }
}

Product product(
  String id, {
  double price = 100,
  double? discountedPrice,
  int available = 10,
  bool isAvailable = true,
}) =>
    Product(
      id: id,
      name: 'Item $id',
      description: '',
      category: 'Dairy',
      imageUrl: '',
      price: price,
      discountedPrice: discountedPrice,
      unit: '1 kg',
      stock: available,
      physicalStock: available,
      availableStock: available,
      isAvailable: isAvailable,
    );

void main() {
  CartProvider newCart() => CartProvider(cartRepository: _MemoryCartRepository());

  group('CartProvider pricing', () {
    test('totals the price the customer will actually be charged (discount applied)', () {
      final cart = newCart();
      cart.addItemQuantity(product('a', price: 100, discountedPrice: 80), 2);
      cart.addItem(product('b', price: 50));

      expect(cart.totalAmount, 2 * 80 + 50);
    });

    test('uses the list price when the discount is invalid', () {
      final cart = newCart();
      cart.addItem(product('a', price: 100, discountedPrice: 120));
      expect(cart.totalAmount, 100);
    });
  });

  group('CartProvider stock limits', () {
    test('refuses to add beyond the sellable stock', () {
      final cart = newCart();
      final p = product('a', available: 2);
      expect(cart.addItem(p), isTrue);
      expect(cart.addItem(p), isTrue);
      expect(cart.addItem(p), isFalse);
      expect(cart.quantityOf('a'), 2);
    });

    test('refuses a product the admin switched off even with stock on the shelf', () {
      final cart = newCart();
      expect(cart.addItem(product('a', available: 9, isAvailable: false)), isFalse);
      expect(cart.itemCount, 0);
    });
  });

  group('ReorderHelper', () {
    OrderItem line(String id, int qty) =>
        OrderItem(productId: id, name: 'Item $id', price: 1, quantity: qty);

    test('caps at sellable stock, skips switched-off and missing products', () async {
      final cart = newCart();
      final catalog = {
        'a': product('a', available: 3),
        'off': product('off', available: 9, isAvailable: false),
      };

      final outcome = await ReorderHelper.reorderOrderItems(
        [line('a', 5), line('off', 1), line('gone', 1)],
        (id) async => catalog[id],
        cart,
      );

      expect(outcome.addedCount, 1);
      expect(outcome.skippedCount, 2);
      expect(cart.quantityOf('a'), 3);
    });

    test('does not count a line as added when the cart already holds the stock', () async {
      final cart = newCart();
      final p = product('a', available: 3);
      cart.addItemQuantity(p, 3);

      final outcome = await ReorderHelper.reorderOrderItems(
        [line('a', 2)],
        (id) async => p,
        cart,
      );

      expect(outcome.addedCount, 0);
      expect(outcome.skippedCount, 1);
      expect(cart.quantityOf('a'), 3);
    });
  });
}
