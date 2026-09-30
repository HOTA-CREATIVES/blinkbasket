import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/design/widgets/cart_changes_dialog.dart';
import 'package:hypermart/core/providers/cart_provider.dart';
import 'package:hypermart/domain/entities/product.dart';
import 'package:hypermart/domain/repositories/cart_repository.dart';
import 'package:hypermart/domain/repositories/product_repository.dart';

class _CartRepo implements CartRepository {
  Map<String, dynamic>? stored;
  int saves = 0;

  @override
  Future<Map<String, dynamic>?> getCart(String userId) async => stored;

  @override
  Future<void> saveCart(String userId, Map<String, dynamic> cartMap) async {
    saves++;
    stored = cartMap;
  }
}

class _Catalog implements ProductRepository {
  final Map<String, Product?> products = {};
  final Set<String> failing = {};
  int lookups = 0;

  @override
  Future<Product?> getProductById(String id) async {
    lookups++;
    if (failing.contains(id)) throw StateError('offline');
    return products[id];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Product product(
  String id, {
  double price = 100,
  double? discountedPrice,
  int available = 10,
  bool isAvailable = true,
  String? name,
}) =>
    Product(
      id: id,
      name: name ?? 'Item $id',
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

Future<({CartProvider cart, _Catalog catalog, _CartRepo repo})> setup({
  Map<String, Product?> initial = const {},
}) async {
  final catalog = _Catalog()..products.addAll(initial);
  final repo = _CartRepo();
  final cart = CartProvider(productRepository: catalog, cartRepository: repo);
  await cart.setUser('u1');
  return (cart: cart, catalog: catalog, repo: repo);
}

void main() {
  group('CartProvider.revalidate', () {
    test('an unchanged cart is clean, and does not rewrite the saved cart', () async {
      final t = await setup(initial: {'a': product('a')});
      t.cart.addItem(product('a'));
      await Future<void>.delayed(const Duration(milliseconds: 400)); // debounced save
      final savesBefore = t.repo.saves;

      final result = await t.cart.revalidate();

      expect(result.isClean, isTrue);
      expect(result.couldNotVerify, isFalse);
      expect(t.repo.saves, savesBefore);
    });

    test('a price change is reported, and the cart total moves to today\'s price', () async {
      final t = await setup(initial: {'a': product('a', price: 120)});
      t.cart.addItemQuantity(product('a', price: 100), 2);
      expect(t.cart.totalAmount, 200);

      final result = await t.cart.revalidate();

      expect(result.changes, hasLength(1));
      expect(result.changes.single.kind, CartChangeKind.priceChanged);
      expect(result.changes.single.message, contains('₹100'));
      expect(result.changes.single.message, contains('₹120'));
      expect(t.cart.totalAmount, 240);
      expect(t.cart.quantityOf('a'), 2);
    });

    test('a new discount is a price change; the discounted price is what the cart uses', () async {
      final t = await setup(initial: {'a': product('a', price: 100, discountedPrice: 80)});
      t.cart.addItem(product('a', price: 100));

      final result = await t.cart.revalidate();

      expect(result.changes.single.newPrice, 80);
      expect(t.cart.totalAmount, 80);
    });

    test('quantity is reduced to what is left', () async {
      final t = await setup(initial: {'a': product('a', available: 2)});
      t.cart.addItemQuantity(product('a', available: 9), 5);

      final result = await t.cart.revalidate();

      expect(result.changes.single.kind, CartChangeKind.quantityReduced);
      expect(result.changes.single.newQuantity, 2);
      expect(t.cart.quantityOf('a'), 2);
    });

    test('a sold-out, switched-off or deleted product is removed', () async {
      final t = await setup(initial: {
        'soldout': product('soldout', available: 0),
        'off': product('off', available: 9, isAvailable: false),
        'gone': null,
        'ok': product('ok'),
      });
      for (final id in ['soldout', 'off', 'gone', 'ok']) {
        t.cart.addItem(product(id, name: 'Item $id'));
      }

      final result = await t.cart.revalidate();

      expect(result.changes.where((c) => c.kind == CartChangeKind.removed), hasLength(3));
      expect(t.cart.items.keys, ['ok']);
      expect(result.changes.first.message, contains('removed'));
    });

    test('persists what it changed', () async {
      final t = await setup(initial: {'a': product('a', price: 120)});
      t.cart.addItem(product('a', price: 100));
      await Future<void>.delayed(const Duration(milliseconds: 400));

      await t.cart.revalidate();

      final saved = (t.repo.stored!['a'] as Map)['product'] as Map;
      expect(saved['price'], 120);
    });

    test('a lookup failure removes nothing and says the cart could not be verified', () async {
      final t = await setup(initial: {'a': product('a'), 'b': product('b', available: 0)});
      t.catalog.failing.add('a');
      t.cart.addItem(product('a'));
      t.cart.addItem(product('b', available: 5));

      final result = await t.cart.revalidate();

      expect(result.couldNotVerify, isTrue);
      expect(t.cart.quantityOf('a'), 1, reason: 'unverified line is kept');
      expect(t.cart.quantityOf('b'), 0, reason: 'a verified sold-out line is still removed');
    });

    test('an empty cart needs no lookups', () async {
      final t = await setup();
      final result = await t.cart.revalidate();
      expect(result.isClean, isTrue);
      expect(t.catalog.lookups, 0);
    });

    test('isValidating is true only while it runs', () async {
      final t = await setup(initial: {'a': product('a')});
      t.cart.addItem(product('a'));
      final states = <bool>[];
      t.cart.addListener(() => states.add(t.cart.isValidating));

      await t.cart.revalidate();

      expect(states.first, isTrue);
      expect(states.last, isFalse);
      expect(t.cart.isValidating, isFalse);
    });

    test('a second call while one is running does not start another', () async {
      final t = await setup(initial: {'a': product('a')});
      t.cart.addItem(product('a'));
      final before = t.catalog.lookups;

      final first = t.cart.revalidate();
      final second = await t.cart.revalidate();
      await first;

      expect(second.isClean, isTrue);
      expect(t.catalog.lookups - before, 1);
    });
  });

  group('cart load', () {
    test('loading a saved cart applies live prices and stock and keeps what changed for the cart screen',
        () async {
      final catalog = _Catalog()..products['a'] = product('a', price: 130, available: 1);
      final repo = _CartRepo()
        ..stored = {
          'a': CartItem(product: product('a', price: 100), quantity: 3).toMap(),
        };
      final cart = CartProvider(productRepository: catalog, cartRepository: repo);
      await cart.setUser('u1');

      expect(cart.quantityOf('a'), 1);
      expect(cart.totalAmount, 130);
      expect(cart.pendingChanges.map((c) => c.kind),
          containsAll([CartChangeKind.quantityReduced, CartChangeKind.priceChanged]));

      cart.dismissPendingChanges();
      expect(cart.pendingChanges, isEmpty);
    });

    test('signing out forgets pending changes', () async {
      final catalog = _Catalog()..products['a'] = product('a', price: 130);
      final repo = _CartRepo()..stored = {'a': CartItem(product: product('a'), quantity: 1).toMap()};
      final cart = CartProvider(productRepository: catalog, cartRepository: repo);
      await cart.setUser('u1');
      expect(cart.pendingChanges, isNotEmpty);

      await cart.setUser(null);
      expect(cart.pendingChanges, isEmpty);
    });
  });

  group('showCartChangesDialog', () {
    Future<bool?> open(WidgetTester tester, {String? continueLabel}) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showCartChangesDialog(
                  context,
                  const [
                    CartChange.priceChanged(productName: 'Milk', oldPrice: 50, newPrice: 52),
                    CartChange.removed(productName: 'Bread'),
                  ],
                  continueLabel: continueLabel ?? 'Continue',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('lists every change in plain words', (tester) async {
      await open(tester);
      expect(find.text('Your cart was updated'), findsOneWidget);
      expect(find.textContaining('Milk: price changed from ₹50 to ₹52'), findsOneWidget);
      expect(find.textContaining('Bread: no longer available'), findsOneWidget);
    });

    testWidgets('Continue proceeds, Review cart does not', (tester) async {
      var results = <bool>[];
      Future<void> run(String button) async {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => results.add(await showCartChangesDialog(
                  context,
                  const [CartChange.removed(productName: 'Bread')],
                )),
                child: const Text('open'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
      }

      await run('Continue');
      await run('Review cart');

      expect(results, [true, false]);
    });
  });
}
