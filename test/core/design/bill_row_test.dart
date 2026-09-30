import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/design/widgets/bill_row.dart';
import '../../helpers/test_fonts.dart';

void main() {
  var fontsLoaded = false;
  setUpAll(() async => fontsLoaded = await loadRealisticFonts());

  Future<void> pump(WidgetTester tester, Widget row, {double scale = 1.0}) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      textScale: scale,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: row)),
    ));
  }

  testWidgets('shows the label and the amount', (tester) async {
    await pump(tester, const BillRow(label: 'Item subtotal', value: '₹300'));
    expect(find.text('Item subtotal'), findsOneWidget);
    expect(find.text('₹300'), findsOneWidget);
  });

  testWidgets('a free delivery line shows the struck-through fee beside FREE', (tester) async {
    await pump(tester, const BillRow.deliveryFee(fee: 30, isFree: true));
    expect(find.text('Delivery fee'), findsOneWidget);
    final text = tester.widget<Text>(find.byType(Text).last);
    final span = text.textSpan as TextSpan;
    expect(span.children!.map((c) => (c as TextSpan).text), ['₹30 ', 'FREE']);
    expect((span.children!.first as TextSpan).style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('a charged delivery line shows the fee', (tester) async {
    await pump(tester, const BillRow.deliveryFee(fee: 30, isFree: false));
    expect(find.text('₹30'), findsOneWidget);
    expect(find.text('FREE'), findsNothing);
  });

  testWidgets('the total row is emphasised', (tester) async {
    await pump(tester, const BillRow(label: 'Total', value: '₹330', emphasised: true));
    final label = tester.widget<Text>(find.text('Total'));
    expect(label.style?.fontWeight, FontWeight.w800);
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('a long label and a big amount never overflow (text scale $scale)', (tester) async {
      if (!fontsLoaded) return markTestSkipped('Flutter SDK fonts unavailable');
      await pump(
        tester,
        const Column(children: [
          BillRow(label: 'To pay (cash on delivery)', value: '₹12,999.75', emphasised: true),
          BillRow.deliveryFee(fee: 30, isFree: true),
          BillRow(label: 'A very long line item description that keeps going', value: '₹1,299.50'),
        ]),
        scale: scale,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
