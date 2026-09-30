import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/providers/order_provider.dart';
import 'package:hypermart/domain/entities/rider_location.dart';
import 'package:hypermart/domain/repositories/order_repository.dart';
import 'package:hypermart/modules/delivery/widgets/otp_verification_grid.dart';
import 'package:provider/provider.dart';
import '../../helpers/test_fonts.dart';

class _FakeOrderRepository implements OrderRepository {
  final List<({String orderId, String otp, double amount, RiderLocation? location})> calls = [];
  String? result;

  @override
  Future<String?> verifyDeliveryOtp(String orderId, String otp, double collectedAmount,
      {RiderLocation? location}) async {
    calls.add((orderId: orderId, otp: otp, amount: collectedAmount, location: location));
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<int> _pump(
  WidgetTester tester,
  _FakeOrderRepository repo, {
  VoidCallback? onSuccess,
  Future<RiderLocation?> Function()? locate,
}) async {
  var successes = 0;
  await tester.pumpWidget(
    ChangeNotifierProvider<OrderProvider>(
      create: (_) => OrderProvider(repository: repo),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OtpVerificationGrid(
              orderId: 'order1',
              amountDue: 130,
              locate: locate ?? () async => null,
              onSuccess: () {
                successes++;
                onSuccess?.call();
              },
            ),
          ),
        ),
      ),
    ),
  );
  return successes;
}

Future<void> _typeOtp(WidgetTester tester, String otp) async {
  for (var i = 0; i < 4; i++) {
    await tester.enterText(find.byType(TextFormField).at(i), otp[i]);
    await tester.pump();
  }
}

ElevatedButton _verifyButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Verify'));

void main() {
  testWidgets('shows the amount to collect and blocks Verify until the rider confirms the cash',
      (tester) async {
    await _pump(tester, _FakeOrderRepository());

    expect(find.text('Collect ₹130 in cash'), findsOneWidget);
    expect(find.text('I have collected ₹130'), findsOneWidget);
    expect(_verifyButton(tester).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(_verifyButton(tester).onPressed, isNotNull);
  });

  testWidgets('a complete code without the cash confirmation is not sent, and says why',
      (tester) async {
    final repo = _FakeOrderRepository();
    await _pump(tester, repo);

    await _typeOtp(tester, '1234');
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
    expect(find.text('Confirm you collected ₹130 first'), findsOneWidget);
  });

  testWidgets('sends the code and the confirmed amount, then reports success', (tester) async {
    final repo = _FakeOrderRepository();
    var succeeded = false;
    await _pump(tester, repo, onSuccess: () => succeeded = true);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await _typeOtp(tester, '1234');
    // The real dialog is popped by onSuccess; here the busy spinner keeps
    // animating, so pump a few frames instead of settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.orderId, 'order1');
    expect(repo.calls.single.otp, '1234');
    expect(repo.calls.single.amount, 130);
    expect(succeeded, isTrue);
  });

  testWidgets('shows the server message for a wrong code and clears the boxes', (tester) async {
    final repo = _FakeOrderRepository()..result = 'Incorrect delivery OTP. 4 attempts left.';
    await _pump(tester, repo);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await _typeOtp(tester, '9999');
    await tester.pumpAndSettle();

    expect(find.text('Incorrect delivery OTP. 4 attempts left.'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      final field = tester.widget<TextFormField>(find.byType(TextFormField).at(i));
      expect(field.controller?.text, isEmpty);
    }
  });

  testWidgets('shows a fixed message, not the exception, when the call throws', (tester) async {
    final repo = _ThrowingRepository();
    await _pump(tester, repo);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await _typeOtp(tester, '1234');
    await tester.pumpAndSettle();

    expect(find.text('Verification failed. Please try again.'), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });
  testWidgets('sends the rider location with the code as proof of delivery', (tester) async {
    final repo = _FakeOrderRepository();
    await _pump(tester, repo,
        locate: () async => const RiderLocation(lat: 16.546, lng: 81.5225, accuracyMeters: 8));

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await _typeOtp(tester, '1234');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.calls.single.location?.lat, 16.546);
    expect(repo.calls.single.location?.accuracyMeters, 8);
  });

  group('accessibility and input', () {
    List<String> boxes(WidgetTester tester) => [
          for (var i = 0; i < 4; i++)
            tester.widget<TextFormField>(find.byType(TextFormField).at(i)).controller!.text,
        ];

    testWidgets('pasting the whole code into the first box fills every box and submits', (tester) async {
      final repo = _FakeOrderRepository();
      await _pump(tester, repo);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).at(0), '4821');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.otp, '4821');
    });

    testWidgets('pasting keeps only digits and ignores formatting characters', (tester) async {
      final repo = _FakeOrderRepository();
      await _pump(tester, repo);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).at(0), '4 8-2 1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.calls.single.otp, '4821');
    });

    testWidgets('a partial paste fills the boxes it can and waits for the rest', (tester) async {
      final repo = _FakeOrderRepository();
      await _pump(tester, repo);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).at(0), '48');
      await tester.pump();
      await tester.pump();

      expect(boxes(tester), ['4', '8', '', '']);
      expect(repo.calls, isEmpty);
    });

    testWidgets('pasting into a later box spreads from that box and never past the last', (tester) async {
      final repo = _FakeOrderRepository();
      await _pump(tester, repo);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).at(2), '99999');
      await tester.pump();
      await tester.pump();

      expect(boxes(tester), ['', '', '9', '9']);
    });

    testWidgets('each box is announced to a screen reader with its position', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _FakeOrderRepository());

      for (var i = 1; i <= 4; i++) {
        expect(find.bySemanticsLabel(RegExp('Code digit $i of 4')), findsOneWidget);
      }
      handle.dispose();
    });
  });

  group('large text', () {
    testWidgets('the dialog stays usable on a small screen at 2x text (scrolls instead of overflowing)',
        (tester) async {
      if (!await loadRealisticFonts()) return markTestSkipped('Flutter SDK fonts unavailable');
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<OrderProvider>(
          create: (_) => OrderProvider(repository: _FakeOrderRepository()),
          child: testApp(
            textScale: 2.0,
            home: Scaffold(
              body: OtpVerificationGrid(
                orderId: 'order1',
                amountDue: 1299.5,
                locate: () async => null,
                onSuccess: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
      expect(find.text('Collect ₹1299.50 in cash'), findsOneWidget);
    });
  });

  testWidgets('a GPS error never stops the delivery', (tester) async {
    final repo = _FakeOrderRepository();
    await _pump(tester, repo, locate: () async => throw StateError('gps exploded'));

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await _typeOtp(tester, '1234');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.location, isNull);
    expect(find.text('Verification failed. Please try again.'), findsNothing);
  });

  testWidgets('still delivers, with no location, when GPS gives nothing', (tester) async {
    final repo = _FakeOrderRepository();
    await _pump(tester, repo, locate: () async => null);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await _typeOtp(tester, '1234');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.location, isNull);
  });

  testWidgets("doesn't hold the delivery up for a GPS fix that never arrives", (tester) async {
    final repo = _FakeOrderRepository();
    final never = Completer<RiderLocation?>();
    await _pump(tester, repo, locate: () => never.future);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await _typeOtp(tester, '1234');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.location, isNull);
  });
}

class _ThrowingRepository extends _FakeOrderRepository {
  @override
  Future<String?> verifyDeliveryOtp(String orderId, String otp, double collectedAmount,
      {RiderLocation? location}) {
    throw StateError('boom');
  }
}
