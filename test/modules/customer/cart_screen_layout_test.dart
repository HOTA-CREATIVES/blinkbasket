import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/providers/cart_provider.dart';
import 'package:hypermart/core/providers/config_provider.dart';
import 'package:hypermart/domain/entities/app_config.dart';
import 'package:hypermart/domain/entities/dashboard_stats.dart';
import 'package:hypermart/domain/entities/product.dart';
import 'package:hypermart/domain/repositories/cart_repository.dart';
import 'package:hypermart/domain/repositories/config_repository.dart';
import 'package:hypermart/modules/customer/screens/cart_screen.dart';
import 'package:provider/provider.dart';
import '../../helpers/test_fonts.dart';

class _CartRepo implements CartRepository {
  @override
  Future<Map<String, dynamic>?> getCart(String userId) async => null;
  @override
  Future<void> saveCart(String userId, Map<String, dynamic> cartMap) async {}
}

class _ConfigRepo implements ConfigRepository {
  _ConfigRepo({this.storeOpen = true});
  final bool storeOpen;

  @override
  Stream<AppConfig> streamAppConfig() => Stream.value(AppConfig(
        storeOpen: storeOpen,
        deliveryFee: 30,
        freeDeliveryAbove: 300,
        updatedAt: DateTime(2026),
      ));

  @override
  Stream<DashboardStats> streamDashboardStats() => const Stream.empty();

  @override
  Future<void> updateAppConfig(AppConfig config) async {}
}

Product _product(String id, {String? name, double price = 1299.5, double? discounted = 999.75}) => Product(
      id: id,
      name: name ?? 'Farm Fresh Full Cream Buffalo Milk Family Pack Of Twelve Bottles',
      description: '',
      category: 'Dairy',
      imageUrl: '',
      price: price,
      discountedPrice: discounted,
      unit: '500 ml x 12 pack',
      stock: 50,
      physicalStock: 50,
      availableStock: 50,
    );

Future<CartProvider> _pump(WidgetTester tester, double scale, {bool storeOpen = true}) async {
  tester.view.physicalSize = const Size(360 * 2, 640 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  late CartProvider cart;
  await tester.pumpWidget(MultiProvider(
    providers: [
      // Owned by the tree, so its save debounce timer is cancelled on dispose.
      ChangeNotifierProvider<CartProvider>(create: (_) {
        cart = CartProvider(cartRepository: _CartRepo())
          ..addItemQuantity(_product('a'), 3)
          ..addItem(_product('b', name: 'Tea', price: 10, discounted: null));
        return cart;
      }),
      ChangeNotifierProvider<ConfigProvider>(
          create: (_) => ConfigProvider(repository: _ConfigRepo(storeOpen: storeOpen))),
    ],
    child: testApp(home: const CartScreen(), textScale: scale),
  ));
  await tester.pump();
  await tester.pump();
  return cart;
}

void main() {
  var fontsLoaded = false;
  setUpAll(() async => fontsLoaded = await loadRealisticFonts());

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('cart screen at text scale $scale has no overflow', (tester) async {
    if (!fontsLoaded) return markTestSkipped('Flutter SDK fonts unavailable');
      await _pump(tester, scale);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Checkout'), findsOneWidget);
    });
  }

  testWidgets('shows the discounted price the customer will pay, and a rupee format with no stray decimals',
      (tester) async {
    if (!fontsLoaded) return markTestSkipped('Flutter SDK fonts unavailable');
    await _pump(tester, 1.0);

    expect(find.text('₹999.75 / 500 ml x 12 pack'), findsOneWidget);
    // 3 x 999.75 + 1 x 10
    expect(find.text('₹2999.25'), findsWidgets);
    expect(find.textContaining('₹10 / 1 kg'), findsNothing);
    expect(find.textContaining('.0 '), findsNothing, reason: 'no "₹10.0" style prices');
  });

  testWidgets('checkout is disabled, and says why, while the store is closed', (tester) async {
    if (!fontsLoaded) return markTestSkipped('Flutter SDK fonts unavailable');
    await _pump(tester, 1.0, storeOpen: false);

    expect(find.text('Store is closed'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
