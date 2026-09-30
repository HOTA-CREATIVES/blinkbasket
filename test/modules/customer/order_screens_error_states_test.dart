import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/models/user_model.dart';
import 'package:hypermart/core/providers/auth_provider.dart';
import 'package:hypermart/core/providers/order_provider.dart';
import 'package:hypermart/core/utils/app_exception.dart';
import 'package:hypermart/domain/entities/order.dart';
import 'package:hypermart/domain/repositories/auth_repository.dart';
import 'package:hypermart/domain/repositories/order_repository.dart';
import 'package:hypermart/modules/customer/screens/order_history_screen.dart';
import 'package:hypermart/modules/customer/screens/order_tracking_screen.dart';
import 'package:provider/provider.dart';

class _AuthRepo implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Each call to a stream method opens a new "upstream" the test can drive.
class _OrderRepo implements OrderRepository {
  final List<StreamController<List<Order>>> customerOrders = [];
  final List<StreamController<Order>> orders = [];

  @override
  Stream<List<Order>> streamCustomerOrders(String customerId) {
    final c = StreamController<List<Order>>();
    customerOrders.add(c);
    return c.stream;
  }

  @override
  Stream<Order> streamOrder(String orderId) {
    final c = StreamController<Order>();
    orders.add(c);
    return c.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserModel _user() => UserModel(
      uid: 'u1',
      name: 'Asha',
      email: 'asha@example.com',
      phone: '9876543210',
      role: 'customer',
      village: 'Bhimavaram',
      createdAt: DateTime(2026, 1, 1),
    );

Future<_OrderRepo> _pump(WidgetTester tester, Widget screen) async {
  final repo = _OrderRepo();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(repository: _AuthRepo())..updateCurrentUserModel(_user()),
      ),
      ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider(repository: repo)),
    ],
    child: MaterialApp(home: screen),
  ));
  return repo;
}

void main() {
  group('OrderHistoryScreen', () {
    testWidgets('a load failure shows a safe message and Retry reconnects', (tester) async {
      final repo = await _pump(tester, const OrderHistoryScreen());
      repo.customerOrders.single.addError(StateError('internal /orders path'));
      await tester.pump();
      await tester.pump();

      expect(find.text("Couldn't load your orders"), findsOneWidget);
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.textContaining('internal'), findsNothing, reason: 'raw error text must not reach the user');

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(repo.customerOrders, hasLength(2), reason: 'Retry opened a fresh listener');

      repo.customerOrders.last.add(const []);
      await tester.pump();
      await tester.pump();
      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a connection failure is described as one', (tester) async {
      final repo = await _pump(tester, const OrderHistoryScreen());
      repo.customerOrders.single
          .addError(FirebaseFunctionsException(message: 'x', code: 'unavailable'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('No internet connection'), findsOneWidget);
    });
  });

  group('OrderTrackingScreen', () {
    testWidgets('a deleted order says so, with no Retry to press', (tester) async {
      final repo = await _pump(tester, const OrderTrackingScreen(orderId: 'o1'));
      repo.orders.single.addError(const AppException('Order not found.', code: 'not-found'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Order not found'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a network error is not reported as "order not found", and Retry reconnects',
        (tester) async {
      final repo = await _pump(tester, const OrderTrackingScreen(orderId: 'o1'));
      repo.orders.single.addError(FirebaseFunctionsException(message: 'x', code: 'unavailable'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Order not found'), findsNothing);
      expect(find.text("Couldn't load this order"), findsOneWidget);
      expect(find.textContaining('No internet connection'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(repo.orders, hasLength(2));
    });
  });
}
