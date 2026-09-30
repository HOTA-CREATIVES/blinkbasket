import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/utils/shared_stream.dart';

void main() {
  test('exposes one stable stream instance (so StreamBuilders do not resubscribe on rebuild)', () {
    final shared = SharedStream<int>(() => const Stream<int>.empty());
    expect(identical(shared.stream, shared.stream), isTrue);
    shared.dispose();
  });

  test('opens a single upstream subscription no matter how many listeners join', () async {
    var upstreamListens = 0;
    final source = StreamController<int>.broadcast(onListen: () => upstreamListens++);
    final shared = SharedStream<int>(() => source.stream);

    final a = <int>[];
    final b = <int>[];
    final subA = shared.stream.listen(a.add);
    final subB = shared.stream.listen(b.add);

    source.add(1);
    source.add(2);
    await Future<void>.delayed(Duration.zero);

    expect(upstreamListens, 1);
    expect(a, [1, 2]);
    expect(b, [1, 2]);

    await subA.cancel();
    await subB.cancel();
    shared.dispose();
    await source.close();
  });

  test('replays the latest value to a listener that joins late', () async {
    final source = StreamController<int>.broadcast();
    final shared = SharedStream<int>(() => source.stream);

    final first = shared.stream.listen((_) {});
    source.add(1);
    source.add(7);
    await Future<void>.delayed(Duration.zero);

    final late = <int>[];
    final lateSub = shared.stream.listen(late.add);
    await Future<void>.delayed(Duration.zero);
    expect(late, [7], reason: 'newest snapshot delivered immediately, not the whole history');

    source.add(8);
    await Future<void>.delayed(Duration.zero);
    expect(late, [7, 8]);

    await first.cancel();
    await lateSub.cancel();
    shared.dispose();
    await source.close();
  });

  test('reset() drops the cached value and the next listener gets a fresh upstream', () async {
    var upstreamListens = 0;
    late StreamController<int> current;
    final shared = SharedStream<int>(() {
      upstreamListens++;
      current = StreamController<int>.broadcast();
      return current.stream;
    });

    final first = <int>[];
    final sub1 = shared.stream.listen(first.add);
    current.add(1);
    await Future<void>.delayed(Duration.zero);
    await sub1.cancel();
    expect(first, [1]);

    shared.reset();

    // A new user's listener must NOT be handed the previous user's value...
    final second = <int>[];
    final sub2 = shared.stream.listen(second.add);
    await Future<void>.delayed(Duration.zero);
    expect(second, isEmpty);
    // ...and must be fed by a brand-new subscription to the source.
    expect(upstreamListens, 2);
    current.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(second, [2]);

    await sub2.cancel();
    shared.dispose();
  });

  test('recovers by itself after the upstream fails (dead Firestore listener)', () async {
    var upstreamListens = 0;
    late StreamController<int> current;
    final shared = SharedStream<int>(
      () {
        upstreamListens++;
        current = StreamController<int>.broadcast();
        return current.stream;
      },
      retryDelay: const Duration(milliseconds: 20),
    );

    final received = <int>[];
    final errors = <Object>[];
    final sub = shared.stream.listen(received.add, onError: errors.add);

    current.add(1);
    await Future<void>.delayed(Duration.zero);
    current.addError('permission-denied');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    // Error was surfaced, then the source was re-subscribed and data flows again.
    expect(errors, ['permission-denied']);
    expect(upstreamListens, 2);
    current.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(received, [1, 2]);

    await sub.cancel();
    shared.dispose();
  });

  test('forwards upstream errors to listeners', () async {
    final source = StreamController<int>.broadcast();
    final shared = SharedStream<int>(() => source.stream);

    final errors = <Object>[];
    final sub = shared.stream.listen((_) {}, onError: errors.add);
    source.addError('boom');
    await Future<void>.delayed(Duration.zero);

    expect(errors, ['boom']);

    await sub.cancel();
    shared.dispose();
    await source.close();
  });

  group('idle teardown', () {
    test('closes the upstream once the last listener has been gone for the grace period', () async {
      final source = StreamController<int>.broadcast();
      var upstreamListens = 0;
      var upstreamCancels = 0;
      final shared = SharedStream<int>(
        () {
          upstreamListens++;
          return source.stream.asBroadcastStream(onCancel: (_) => upstreamCancels++);
        },
        idleGrace: const Duration(milliseconds: 30),
      );

      final sub = shared.stream.listen((_) {});
      expect(upstreamListens, 1);
      await sub.cancel();

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(upstreamCancels, 1, reason: 'no listener for longer than the grace');

      // A later listener starts a fresh upstream.
      final again = shared.stream.listen((_) {});
      expect(upstreamListens, 2);
      await again.cancel();
      shared.dispose();
      await source.close();
    });

    test('a listener that returns within the grace keeps the upstream and the cached value', () async {
      final source = StreamController<int>.broadcast();
      var upstreamListens = 0;
      final shared = SharedStream<int>(
        () {
          upstreamListens++;
          return source.stream;
        },
        idleGrace: const Duration(milliseconds: 60),
      );

      final first = shared.stream.listen((_) {});
      source.add(7);
      await Future<void>.delayed(Duration.zero);
      await first.cancel();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final seen = <int>[];
      final second = shared.stream.listen(seen.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(upstreamListens, 1, reason: 'still within the grace: no new upstream');
      expect(seen, [7], reason: 'cached value replayed at once');
      await second.cancel();
      shared.dispose();
      await source.close();
    });

    test('without idleGrace the upstream is kept for the life of the stream (the old behaviour)', () async {
      final source = StreamController<int>.broadcast();
      var upstreamListens = 0;
      final shared = SharedStream<int>(() {
        upstreamListens++;
        return source.stream;
      });

      await (shared.stream.listen((_) {})).cancel();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final again = shared.stream.listen((_) {});

      expect(upstreamListens, 1);
      await again.cancel();
      shared.dispose();
      await source.close();
    });
  });

  group('reconnect', () {
    test('replaces a stale subscription at once when someone is listening', () async {
      var upstreamListens = 0;
      final controllers = <StreamController<int>>[];
      final shared = SharedStream<int>(() {
        upstreamListens++;
        final c = StreamController<int>.broadcast();
        controllers.add(c);
        return c.stream;
      });
      final seen = <int>[];
      final sub = shared.stream.listen(seen.add);
      controllers[0].add(1);
      await Future<void>.delayed(Duration.zero);

      shared.reconnect();
      expect(upstreamListens, 2);
      controllers[1].add(2);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [1, 2]);
      await sub.cancel();
      shared.dispose();
    });

    test('with no listeners it only drops the old subscription; the next listener reconnects', () async {
      var upstreamListens = 0;
      final shared = SharedStream<int>(() {
        upstreamListens++;
        return const Stream<int>.empty();
      });
      shared.reconnect();
      expect(upstreamListens, 0);
      final sub = shared.stream.listen((_) {});
      expect(upstreamListens, 1);
      await sub.cancel();
      shared.dispose();
    });
  });

  group('KeyedSharedStreams', () {
    test('hands back the same stream for a key on every call (safe to call from build())', () {
      final keyed = KeyedSharedStreams<String, int>((k) => const Stream<int>.empty());
      expect(identical(keyed.stream('a'), keyed.stream('a')), isTrue);
      expect(identical(keyed.stream('a'), keyed.stream('b')), isFalse);
      keyed.dispose();
    });

    test('opens one upstream per key however many listeners join', () async {
      final opened = <String>[];
      final keyed = KeyedSharedStreams<String, int>((k) {
        opened.add(k);
        return StreamController<int>.broadcast().stream;
      });
      final subs = [
        keyed.stream('order1').listen((_) {}),
        keyed.stream('order1').listen((_) {}),
        keyed.stream('order2').listen((_) {}),
      ];
      expect(opened, ['order1', 'order2']);
      for (final s in subs) {
        await s.cancel();
      }
      keyed.dispose();
    });

    test('reset() forgets every key so the next call opens fresh upstreams', () async {
      var opens = 0;
      final keyed = KeyedSharedStreams<String, int>((k) {
        opens++;
        return StreamController<int>.broadcast().stream;
      });
      await keyed.stream('a').listen((_) {}).cancel();
      keyed.reset();
      await keyed.stream('a').listen((_) {}).cancel();
      expect(opens, 2);
      keyed.dispose();
    });
  });
}
