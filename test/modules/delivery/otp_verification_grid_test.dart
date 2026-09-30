import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/providers/order_provider.dart';
import 'package:hypermart/domain/repositories/order_repository.dart';
import 'package:hypermart/modules/delivery/widgets/otp_verification_grid.dart';
import 'package:provider/provider.dart';

class _FakeOrderRepository implements OrderRepository {
  final List<({String orderId, String otp, double amount})> calls = [];
  String? result;

  @override
  Future<String?> verifyDeliveryOtp(String orderId, String otp, double collectedAmount) async {
    calls.add((orderId: orderId, otp: otp, amount: collectedAmount));
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<int> _pump(WidgetTester tester, _FakeOrderRepository repo, {VoidCallback? onSuccess}) async {
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
}

class _ThrowingRepository extends _FakeOrderRepository {
  @override
  Future<String?> verifyDeliveryOtp(String orderId, String otp, double collectedAmount) {
    throw StateError('boom');
  }
}
