import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/banner_provider.dart';
import 'core/providers/cart_provider.dart';
import 'core/providers/order_provider.dart';
import 'core/providers/product_provider.dart';
import 'core/providers/profile_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/config_provider.dart';
import 'firebase_options.dart';
import 'data/repositories/http_order_repository.dart';
import 'app.dart';

/// Must be a top-level (or static) function — FCM runs it in a background
/// isolate that has its own Firebase initialization, separate from main().
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Debug provider in debug builds only (requires registering the printed
    // debug token in the Firebase console App Check tab); Play Integrity /
    // App Attest in release. The `enforceAppCheck: true` callables will
    // reject every request until App Check is activated here AND the app
    // is registered for Play Integrity in the console — do not deploy the
    // enforceAppCheck functions change before that console step is done.
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    // FCM doesn't auto-display a banner while the app is in the foreground
    // on all platforms, so surface it ourselves via a SnackBar.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      final title = notification.title;
      final body = notification.body;
      final text = [title, body].where((s) => s != null && s.isNotEmpty).join(': ');
      if (text.isEmpty) return;
      JCMartApp.scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
    });
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
          create: (context) => ProfileProvider(
            authProvider: Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, auth, previous) => previous ?? ProfileProvider(authProvider: auth),
        ),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(
          create: (_) => OrderProvider(repository: HttpOrderRepository()),
        ),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => BannerProvider()),
      ],
      child: const JCMartApp(),
    ),
  );
}
