import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/utils/route_generator.dart';

void main() {
  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    // Pump the splash screen directly: the full app requires a live
    // Firebase instance, which is not available in widget tests.
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('J C Mart'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
