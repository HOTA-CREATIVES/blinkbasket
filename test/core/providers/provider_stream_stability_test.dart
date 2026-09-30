import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/providers/order_provider.dart';
import 'package:hypermart/core/providers/product_provider.dart';
import 'package:hypermart/core/providers/support_provider.dart';
import 'package:hypermart/domain/entities/order.dart';
import 'package:hypermart/domain/entities/product.dart';
import 'package:hypermart/domain/entities/support_ticket.dart';
import 'package:hypermart/domain/repositories/order_repository.dart';
import 'package:hypermart/domain/repositories/product_repository.dart';
import 'package:hypermart/domain/repositories/support_repository.dart';

Order order(String id) => Order(
      id: id,
      customerId: 'c1',
      customerName: 'A',
      customerPhone: '9876543210',
      deliveryAddress: 'addr',
      village: 'Bhimavaram',
      items: const [],
      totalAmount: 10,
      paymentMethod: 'COD',
      status: 'pending',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// Counts how many upstream (Firestore-like) listeners each call opens.
class _OrderRepo implements OrderRepository {
  final Map<String, List<StreamController<Order>>> single = {};
  final Map<String, List<StreamController<List<Order>>>> lists = {};

  @override
  Stream<Order> streamOrder(String orderId) {
    final c = StreamController<Order>();
    (single[orderId] ??= []).add(c);
    return c.stream;
  }

  @override
  Stream<List<Order>> streamCustomerOrders(String customerId) {
    final c = StreamController<List<Order>>();
    (lists[customerId] ??= []).add(c);
    return c.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProductRepo implements ProductRepository {
  int opened = 0;
  final List<StreamController<List<Product>>> controllers = [];

  @override
  Stream<List<Product>> streamProducts() {
    opened++;
    final c = StreamController<List<Product>>();
    controllers.add(c);
    return c.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SupportRepo implements SupportRepository {
  final Map<String, int> opened = {};

  @override
  Stream<SupportTicket> streamTicket(String ticketId) {
    opened[ticketId] = (opened[ticketId] ?? 0) + 1;
    return StreamController<SupportTicket>().stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  group('OrderProvider streams are safe to read from build()', () {
    test('the same stream instance comes back for the same id, a different one per id', () {
      final provider = OrderProvider(repository: _OrderRepo());
      expect(identical(provider.streamOrder('o1'), provider.streamOrder('o1')), isTrue);
      expect(identical(provider.streamOrder('o1'), provider.streamOrder('o2')), isFalse);
      expect(identical(provider.streamCustomerOrders('c1'), provider.streamCustomerOrders('c1')), isTrue);
      provider.dispose();
    });

    test('rebuilding (asking again) and several widgets listening open one upstream', () async {
      final repo = _OrderRepo();
      final provider = OrderProvider(repository: repo);
      final seen = <String>[];

      final subs = [
        provider.streamOrder('o1').listen((o) => seen.add('a:${o.id}')),
        provider.streamOrder('o1').listen((o) => seen.add('b:${o.id}')),
      ];
      // A "rebuild": another call, another listener, same stream.
      subs.add(provider.streamOrder('o1').listen((o) => seen.add('c:${o.id}')));
      repo.single['o1']!.single.add(order('o1'));
      await tick();

      expect(repo.single['o1'], hasLength(1));
      expect(seen, unorderedEquals(['a:o1', 'b:o1', 'c:o1']));
      for (final s in subs) {
        await s.cancel();
      }
      provider.dispose();
    });

    test('a late widget is handed the latest order at once', () async {
      final repo = _OrderRepo();
      final provider = OrderProvider(repository: repo);
      final first = provider.streamOrder('o1').listen((_) {});
      repo.single['o1']!.single.add(order('o1'));
      await tick();

      final late = <String>[];
      final second = provider.streamOrder('o1').listen((o) => late.add(o.status));
      await tick();

      expect(late, ['pending']);
      await first.cancel();
      await second.cancel();
      provider.dispose();
    });

    test('resetSession (sign-out) drops every cached order stream; the next login gets fresh ones', () async {
      final repo = _OrderRepo();
      final provider = OrderProvider(repository: repo);
      final sub = provider.streamCustomerOrders('c1').listen((_) {});
      repo.lists['c1']!.single.add([order('o1')]);
      await tick();
      await sub.cancel();

      provider.resetSession();

      final next = <int>[];
      final sub2 = provider.streamCustomerOrders('c1').listen((o) => next.add(o.length));
      await tick();
      expect(repo.lists['c1'], hasLength(2), reason: 'a new upstream, the old one is dead');
      expect(next, isEmpty, reason: "the previous user's orders are not replayed");
      await sub2.cancel();
      provider.dispose();
    });

    test('retryOrder replaces a failed listener immediately', () async {
      final repo = _OrderRepo();
      final provider = OrderProvider(repository: repo);
      final errors = <Object>[];
      final seen = <String>[];
      final sub = provider.streamOrder('o1').listen((o) => seen.add(o.id), onError: errors.add);

      repo.single['o1']!.single.addError('permission-denied');
      await tick();
      expect(errors, ['permission-denied']);

      provider.retryOrder('o1');
      expect(repo.single['o1'], hasLength(2));
      repo.single['o1']!.last.add(order('o1'));
      await tick();

      expect(seen, ['o1']);
      await sub.cancel();
      provider.dispose();
    });
  });

  group('ProductProvider.streamProducts', () {
    test('is one stable stream with one upstream listener however often it is asked for', () async {
      final repo = _ProductRepo();
      final provider = ProductProvider(repository: repo);

      expect(identical(provider.streamProducts(), provider.streamProducts()), isTrue);
      final a = provider.streamProducts().listen((_) {});
      final b = provider.streamProducts().listen((_) {});
      await tick();

      expect(repo.opened, 1);
      await a.cancel();
      await b.cancel();
      provider.dispose();
    });

    test('retryProducts reconnects after a failure', () async {
      final repo = _ProductRepo();
      final provider = ProductProvider(repository: repo);
      final errors = <Object>[];
      final sub = provider.streamProducts().listen((_) {}, onError: errors.add);

      repo.controllers.single.addError('unavailable');
      await tick();
      provider.retryProducts();

      expect(errors, ['unavailable']);
      expect(repo.opened, 2);
      await sub.cancel();
      provider.dispose();
    });
  });

  group('SupportProvider streams', () {
    test('one stable stream and one listener per ticket, reset on sign-out', () async {
      final repo = _SupportRepo();
      final provider = SupportProvider(repository: repo);

      expect(identical(provider.streamTicket('t1'), provider.streamTicket('t1')), isTrue);
      final a = provider.streamTicket('t1').listen((_) {});
      final b = provider.streamTicket('t1').listen((_) {});
      final c = provider.streamTicket('t2').listen((_) {});
      expect(repo.opened, {'t1': 1, 't2': 1});

      provider.resetSession();
      final d = provider.streamTicket('t1').listen((_) {});
      expect(repo.opened['t1'], 2);

      for (final s in [a, b, c, d]) {
        await s.cancel();
      }
      provider.dispose();
    });
  });
}
