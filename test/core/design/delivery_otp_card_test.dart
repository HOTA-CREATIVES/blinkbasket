import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/design/widgets/delivery_otp_card.dart';
import 'package:hypermart/core/providers/order_provider.dart';
import 'package:hypermart/core/utils/app_exception.dart';
import 'package:hypermart/domain/entities/delivery_otp.dart';
import 'package:hypermart/domain/repositories/order_repository.dart';
import 'package:provider/provider.dart';

class _Repo implements OrderRepository {
  DeliveryOtp? current;
  DeliveryOtp? next;
  Object? regenerateError;
  int loads = 0;
  int regenerations = 0;

  @override
  Future<DeliveryOtp?> getDeliveryOtp(String orderId) async {
    loads++;
    return current;
  }

  @override
  Future<DeliveryOtp> regenerateDeliveryOtp(String orderId) async {
    regenerations++;
    final error = regenerateError;
    if (error != null) throw error;
    current = next;
    return next!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _t0 = DateTime(2026, 9, 30, 16, 0);

Future<void> _pump(
  WidgetTester tester,
  _Repo repo, {
  String status = 'out_for_delivery',
  DateTime Function()? now,
}) async {
  await tester.pumpWidget(ChangeNotifierProvider<OrderProvider>(
    create: (_) => OrderProvider(repository: repo),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DeliveryOtpCard(orderId: 'o1', status: status, now: now ?? () => _t0),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows the code big and spaced, with when it stops working', (tester) async {
    final repo = _Repo()
      ..current = DeliveryOtp(code: '4821', expiresAt: DateTime(2026, 9, 30, 18, 5));
    await _pump(tester, repo);

    expect(find.text('4 8 2 1'), findsOneWidget);
    expect(find.text('Valid until 6:05 PM'), findsOneWidget);
    expect(find.text('Give this code to your rider'), findsOneWidget);
  });

  testWidgets('before dispatch it warns not to share the code yet and shows no expiry', (tester) async {
    final repo = _Repo()..current = const DeliveryOtp(code: '4821');
    await _pump(tester, repo, status: 'assigned');

    expect(find.text('Your delivery code'), findsOneWidget);
    expect(find.textContaining("Don't share it before then"), findsOneWidget);
    expect(find.textContaining('Valid until'), findsNothing);
  });

  testWidgets('an expired code is struck out, cannot be copied, and points to a new one', (tester) async {
    final repo = _Repo()
      ..current = DeliveryOtp(code: '4821', expiresAt: DateTime(2026, 9, 30, 15, 0));
    await _pump(tester, repo);

    expect(find.text('This code has expired. Get a new one.'), findsOneWidget);
    expect(find.textContaining('Valid until'), findsNothing);
    final copy = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.copy_rounded));
    expect(copy.onPressed, isNull);
  });

  testWidgets('copying puts the code on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final repo = _Repo()..current = const DeliveryOtp(code: '4821');
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('Copy code'));
    await tester.pump();

    expect(copied, '4821');
    expect(find.text('Code copied'), findsOneWidget);
  });

  group('getting a new code', () {
    testWidgets('asks first, then shows the new code and confirms', (tester) async {
      final repo = _Repo()
        ..current = DeliveryOtp(code: '4821', expiresAt: DateTime(2026, 9, 30, 15, 0))
        ..next = DeliveryOtp(code: '7305', expiresAt: DateTime(2026, 9, 30, 18, 0));
      await _pump(tester, repo);

      await tester.tap(find.text('Get a new code'));
      await tester.pumpAndSettle();
      expect(find.text('Get a new code?'), findsOneWidget);
      expect(repo.regenerations, 0, reason: 'nothing changes until the customer confirms');

      await tester.tap(find.text('Get new code'));
      await tester.pumpAndSettle();

      expect(repo.regenerations, 1);
      expect(find.text('7 3 0 5'), findsOneWidget);
      expect(find.text('Valid until 6:00 PM'), findsOneWidget);
      expect(find.text('New delivery code ready.'), findsOneWidget);
      expect(find.text('This code has expired. Get a new one.'), findsNothing);
    });

    testWidgets('keeping the current code changes nothing', (tester) async {
      final repo = _Repo()..current = const DeliveryOtp(code: '4821');
      await _pump(tester, repo);

      await tester.tap(find.text('Get a new code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep current code'));
      await tester.pumpAndSettle();

      expect(repo.regenerations, 0);
      expect(find.text('4 8 2 1'), findsOneWidget);
    });

    testWidgets("shows the server's reason when it can't, and keeps the old code", (tester) async {
      final repo = _Repo()
        ..current = const DeliveryOtp(code: '4821')
        ..regenerateError = const AppException("You've refreshed this code too many times.");
      await _pump(tester, repo);

      await tester.tap(find.text('Get a new code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get new code'));
      await tester.pumpAndSettle();

      expect(find.text("You've refreshed this code too many times."), findsOneWidget);
      expect(find.text('4 8 2 1'), findsOneWidget);
    });

    testWidgets('never shows raw exception text', (tester) async {
      final repo = _Repo()
        ..current = const DeliveryOtp(code: '4821')
        ..regenerateError = StateError('internal /orders/o1/private');
      await _pump(tester, repo);

      await tester.tap(find.text('Get a new code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get new code'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't get a new code. Please try again."), findsOneWidget);
      expect(find.textContaining('internal'), findsNothing);
    });
  });

  testWidgets("a code that can't be loaded says so and Retry loads it", (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    expect(find.text("Couldn't load your code."), findsOneWidget);

    repo.current = const DeliveryOtp(code: '4821');
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('4 8 2 1'), findsOneWidget);
    expect(repo.loads, 2);
  });

  testWidgets('reloads the code (and its new expiry) when the order goes out for delivery', (tester) async {
    final repo = _Repo()..current = const DeliveryOtp(code: '4821');
    final status = ValueNotifier('picked_up');
    await tester.pumpWidget(ChangeNotifierProvider<OrderProvider>(
      create: (_) => OrderProvider(repository: repo),
      child: MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (_, s, __) => DeliveryOtpCard(orderId: 'o1', status: s, now: () => _t0),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Valid until'), findsNothing);

    repo.current = DeliveryOtp(code: '4821', expiresAt: DateTime(2026, 9, 30, 18, 0));
    status.value = 'out_for_delivery';
    await tester.pump();
    await tester.pump();

    expect(find.text('Valid until 6:00 PM'), findsOneWidget);
    expect(repo.loads, 2);
  });

  testWidgets('flips to expired when the time passes, without any other rebuild', (tester) async {
    var now = _t0;
    final repo = _Repo()
      ..current = DeliveryOtp(code: '4821', expiresAt: _t0.add(const Duration(seconds: 30)));
    await _pump(tester, repo, now: () => now);
    expect(find.textContaining('Valid until'), findsOneWidget);

    now = _t0.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 32));

    expect(find.text('This code has expired. Get a new one.'), findsOneWidget);
  });
}
