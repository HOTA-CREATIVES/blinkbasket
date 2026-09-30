import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/design/widgets/swipe_to_confirm_slider.dart';

Widget _host({required bool enabled, required VoidCallback onSwipe}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: SwipeToConfirmSlider(
              text: 'SWIPE TO CONFIRM',
              color: Colors.green,
              enabled: enabled,
              onSwipeCompleted: onSwipe,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a full swipe fires the callback once', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_host(enabled: true, onSwipe: () => fired++));

    await tester.drag(find.byIcon(Icons.double_arrow_rounded), const Offset(400, 0));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(fired, 1);
  });

  testWidgets('a short swipe springs back without firing', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_host(enabled: true, onSwipe: () => fired++));

    await tester.drag(find.byIcon(Icons.double_arrow_rounded), const Offset(60, 0));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(fired, 0);
  });

  testWidgets('while disabled (request in flight) a swipe does nothing', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_host(enabled: false, onSwipe: () => fired++));

    await tester.drag(find.byIcon(Icons.double_arrow_rounded), const Offset(400, 0));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(fired, 0);
  });

  testWidgets('is exposed to screen readers as a button that can be activated without swiping',
      (tester) async {
    var fired = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(enabled: true, onSwipe: () => fired++));

    final node = tester.getSemantics(find.bySemanticsLabel('SWIPE TO CONFIRM'));
    expect(node.flagsCollection.isButton, isTrue);
    tester.semantics.tap(find.semantics.byLabel('SWIPE TO CONFIRM'));
    await tester.pump();

    expect(fired, 1);
    handle.dispose();
  });
}
