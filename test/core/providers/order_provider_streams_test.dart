import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/providers/order_provider.dart';
import 'package:hypermart/domain/entities/order.dart';
import 'package:hypermart/domain/repositories/order_repository.dart';

/// Only the streams under test are implemented; anything else throws.
class _FakeRepo implements OrderRepository {
  /// Like Firestore's snapshots(): every call is a NEW single-subscription
  /// stream (reusing one would throw "already been listened to").
  late StreamController<List<Order>> current;
  int allOrdersListens = 0;

  @override
  Stream<List<Order>> streamAllOrders({int limit = 300}) {
    allOrdersListens++;
    current = StreamController<List<Order>>();
    return current.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('many StreamBuilders can subscribe/unsubscribe/resubscribe to the shared admin orders stream', () async {
    final repo = _FakeRepo();
    final provider = OrderProvider(repository: repo);

    // Two order tabs + a rebuild each: new stream objects, repeated subscribes.
    final received = <int>[];
    var a = provider.streamAllOrders().listen((o) => received.add(o.length));
    final b = provider.streamAllOrders().listen((o) => received.add(o.length));
    await Future<void>.delayed(Duration.zero); // async* connects on the next tick

    repo.current.add(const []);
    await Future<void>.delayed(Duration.zero);

    await a.cancel();
    a = provider.streamAllOrders().listen((o) => received.add(o.length));
    await Future<void>.delayed(Duration.zero);

    // Only one underlying listener regardless of how many subscribers.
    expect(repo.allOrdersListens, 1);
    expect(received, isNotEmpty);

    await a.cancel();
    await b.cancel();
  });

  test('resetSession() makes the next admin login reconnect instead of reusing a dead listener', () async {
    final repo = _FakeRepo();
    final provider = OrderProvider(repository: repo);

    // First admin session receives data.
    final seen = <int>[];
    final sub = provider.streamAllOrders().listen((o) => seen.add(o.length));
    await Future<void>.delayed(Duration.zero); // async* connects on the next tick
    repo.current.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(repo.allOrdersListens, 1);
    expect(seen, [0]);
    await sub.cancel();

    // Sign-out: shared listeners are dropped and the cached value forgotten.
    provider.resetSession();

    // The next login must open a NEW listener (the old one is dead in prod)
    // and must not be replayed the previous user's orders.
    final next = <int>[];
    final sub2 = provider.streamAllOrders().listen((o) => next.add(o.length));
    await Future<void>.delayed(Duration.zero);
    expect(repo.allOrdersListens, 2);
    expect(next, isEmpty);

    repo.current.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(next, [0]);
    await sub2.cancel();
  });

  test('a failed listener is dropped, so the next subscription reconnects', () async {
    final repo = _FakeRepo();
    final provider = OrderProvider(repository: repo);

    final errors = <Object>[];
    final sub = provider.streamAllOrders().listen((_) {}, onError: errors.add);
    await Future<void>.delayed(Duration.zero); // async* connects on the next tick
    repo.current.addError('permission-denied');
    await Future<void>.delayed(Duration.zero);
    expect(errors, ['permission-denied']);
    await sub.cancel();

    // Next rebuild asks again: must reconnect rather than get a dead stream.
    final again = <int>[];
    final sub2 = provider.streamAllOrders().listen((o) => again.add(o.length));
    await Future<void>.delayed(Duration.zero);
    expect(repo.allOrdersListens, 2);
    repo.current.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(again, [0]);
    await sub2.cancel();
  });
}
