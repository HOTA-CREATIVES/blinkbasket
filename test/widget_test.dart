import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hypermart/core/providers/auth_provider.dart';
import 'package:hypermart/app.dart';

void main() {
  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const BlinkBasketApp(),
      ),
    );

    // Verify that our app name displays.
    expect(find.text('BlinkBasket'), findsWidgets);
  });
}
