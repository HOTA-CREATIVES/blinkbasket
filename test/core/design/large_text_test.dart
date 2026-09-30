import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/design/widgets/email_verification_banner.dart';
import 'package:hypermart/core/design/widgets/order_card.dart';
import 'package:hypermart/core/design/widgets/product_card.dart';
import 'package:hypermart/core/design/widgets/swipe_to_confirm_slider.dart';
import 'package:hypermart/core/models/user_model.dart';
import 'package:hypermart/core/providers/auth_provider.dart';
import 'package:hypermart/domain/entities/order.dart';
import 'package:hypermart/domain/entities/product.dart';
import 'package:hypermart/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:provider/provider.dart';
import '../../helpers/test_fonts.dart';

/// Renders [child] on a 360x640 phone at the given system text scale. Flutter
/// reports a RenderFlex overflow as an exception, which fails the test.
Future<void> _pumpScaled(WidgetTester tester, Widget child, double scale) async {
  tester.view.physicalSize = const Size(360 * 2, 640 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(home: Scaffold(body: child), textScale: scale));
  await tester.pump();
}

const _scales = [1.0, 1.5, 2.0];

Product _product({
  String name = 'Farm Fresh Full Cream Buffalo Milk Family Pack',
  double price = 1299.5,
  double? discounted = 999.75,
  int stock = 3,
  bool available = true,
  bool rx = false,
}) => Product(
  id: 'p',
  name: name,
  description: '',
  category: 'Dairy & Eggs',
  imageUrl: '',
  price: price,
  discountedPrice: discounted,
  unit: '500 ml x 12 pack',
  stock: stock,
  physicalStock: stock,
  availableStock: stock,
  isAvailable: available,
  requiresPrescription: rx,
);

class _AuthRepo implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();
  @override
  bool get isEmailVerified => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  var fontsLoaded = false;
  setUpAll(() async => fontsLoaded = await loadRealisticFonts());

  group('product grid (2 columns) survives large system text', () {
    for (final scale in _scales) {
      testWidgets(
        'scale $scale: discounted, low stock, in cart, sold out, Rx',
        (tester) async {
          final products = [
            (_product(), 0),
            (_product(), 2),
            (_product(stock: 0), 0),
            (_product(rx: true, discounted: null, stock: 50), 0),
            (_product(name: 'Tea', price: 10, discounted: null, stock: 500), 1),
          ];
          await _pumpScaled(
            tester,
            Builder(
              builder:
                  (context) => GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: productGridDelegate(context),
                    itemCount: products.length,
                    itemBuilder:
                        (context, i) => ProductCard(
                          product: products[i].$1,
                          quantityInCart: products[i].$2,
                          onAdd: () {},
                          onRemove: () {},
                        ),
                  ),
            ),
            scale,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('email verification banner', () {
    for (final scale in _scales) {
      testWidgets('scale $scale', (tester) async {
        if (!fontsLoaded) return markTestSkipped('Flutter SDK fonts unavailable');
        await _pumpScaled(
          tester,
          ChangeNotifierProvider<AuthProvider>(
            create:
                (_) => AuthProvider(
                  repository: _AuthRepo(),
                )..updateCurrentUserModel(
                  UserModel(
                    uid: 'u',
                    name: 'A',
                    email:
                        'a.very.long.email.address.for.testing@example-domain.com',
                    phone: '9876543210',
                    role: 'customer',
                    village: 'V',
                    createdAt: DateTime(2026),
                  ),
                ),
            child: const SingleChildScrollView(
              child: EmailVerificationBanner(),
            ),
          ),
          scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('swipe to confirm slider', () {
    for (final scale in _scales) {
      testWidgets('scale $scale with a long label', (tester) async {
        if (!fontsLoaded) return markTestSkipped('Flutter SDK fonts unavailable');
        await _pumpScaled(
          tester,
          Padding(
            padding: const EdgeInsets.all(16),
            child: SwipeToConfirmSlider(
              text: 'SWIPE TO PLACE ORDER • ₹1,299.50',
              color: Colors.green,
              onSwipeCompleted: () {},
            ),
          ),
          scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('order card', () {
    for (final scale in _scales) {
      testWidgets('scale $scale', (tester) async {
        if (!fontsLoaded) return markTestSkipped('Flutter SDK fonts unavailable');
        final order = Order(
          id: 'abcdef123456',
          customerId: 'c',
          customerName: 'A Customer With A Rather Long Name',
          customerPhone: '9876543210',
          deliveryAddress:
              '12-3-45, A Very Long Street Name, Beside The Big Temple, Bhimavaram',
          village: 'Bhimavaram',
          items: [
            OrderItem(
              productId: 'p',
              name: 'Farm Fresh Full Cream Buffalo Milk Family Pack',
              price: 100,
              quantity: 12,
            ),
          ],
          totalAmount: 1299.5,
          paymentMethod: 'COD',
          status: 'out_for_delivery',
          createdAt: DateTime(2026, 9, 30, 16, 5),
          updatedAt: DateTime(2026, 9, 30, 16, 5),
        );
        await _pumpScaled(
          tester,
          SingleChildScrollView(child: OrderCard(order: order, onTap: () {})),
          scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
