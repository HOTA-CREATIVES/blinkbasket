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
}
