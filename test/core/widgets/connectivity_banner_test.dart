import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/widgets/connectivity_banner.dart';

const _grace = Duration(milliseconds: 40);
Future<void> _past(Duration d) => Future<void>.delayed(d + const Duration(milliseconds: 30));

void main() {
  group('OfflineDetector', () {
    test('a cache-only snapshot is not offline until it has lasted for the grace period', () async {
      final changes = <bool>[];
      final d = OfflineDetector(onChange: changes.add, grace: _grace)..onSnapshot(fromCache: true);

      expect(d.isOnline, isTrue, reason: 'normal cold start: the server has not answered yet');
      await _past(_grace);
      expect(d.isOnline, isFalse);
      expect(changes, [false]);
      d.dispose();
    });

    test('a server-confirmed snapshot inside the grace period means it was never offline', () async {
      final changes = <bool>[];
      final d = OfflineDetector(onChange: changes.add, grace: _grace)
        ..onSnapshot(fromCache: true)
        ..onSnapshot(fromCache: false);

      await _past(_grace);
      expect(d.isOnline, isTrue);
      expect(changes, isEmpty);
      d.dispose();
    });

    test('comes back online at once when the server answers again', () async {
      final changes = <bool>[];
      final d = OfflineDetector(onChange: changes.add, grace: _grace)..onSnapshot(fromCache: true);
      await _past(_grace);

      d.onSnapshot(fromCache: false);

      expect(d.isOnline, isTrue);
      expect(changes, [false, true]);
      d.dispose();
    });

    test('repeated cache snapshots do not restart the countdown or repeat the callback', () async {
      final changes = <bool>[];
      final d = OfflineDetector(onChange: changes.add, grace: _grace);
      d.onSnapshot(fromCache: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      d.onSnapshot(fromCache: true); // must not push the deadline out
      await _past(const Duration(milliseconds: 25));
      expect(changes, [false]);

      d.onSnapshot(fromCache: true);
      await _past(_grace);
      expect(changes, [false], reason: 'already offline: no duplicate notification');
      d.dispose();
    });
  });

  group('ConnectivityBanner', () {
    Future<StreamController<bool>> pump(WidgetTester tester) async {
      final states = StreamController<bool>();
      addTearDown(states.close);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConnectivityBanner(
            cacheStates: states.stream,
            grace: const Duration(seconds: 1),
            child: const Text('app content'),
          ),
        ),
      ));
      return states;
    }

    testWidgets('shows nothing while online and never covers the app', (tester) async {
      final states = await pump(tester);
      states.add(false);
      await tester.pump();

      expect(find.textContaining("You're offline"), findsNothing);
      expect(find.text('app content'), findsOneWidget);
    });

    testWidgets('shows an honest offline banner once the cache-only state persists', (tester) async {
      final states = await pump(tester);
      states.add(true);
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.textContaining("You're offline"), findsOneWidget);
      // It must not claim that changes will sync: placing an order cannot queue.
      expect(find.textContaining('sync'), findsNothing);
      expect(find.text('app content'), findsOneWidget);
    });

    testWidgets('hides the banner when the connection returns', (tester) async {
      final states = await pump(tester);
      states.add(true);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.textContaining("You're offline"), findsOneWidget);

      states.add(false);
      // One pump delivers the stream event, the next builds the resulting frame.
      await tester.pump();
      await tester.pump();

      expect(find.textContaining("You're offline"), findsNothing);
    });

    testWidgets('a listener error is not treated as being offline', (tester) async {
      final states = await pump(tester);
      states.addError('permission-denied');
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.textContaining("You're offline"), findsNothing);
    });
  });
}
