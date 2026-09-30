import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'core/config/emulator_config.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/banner_provider.dart';
import 'core/providers/cart_provider.dart';
import 'core/providers/order_provider.dart';
import 'core/providers/product_provider.dart';
import 'core/providers/profile_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/config_provider.dart';
import 'core/providers/support_provider.dart';
import 'core/services/notification_handler.dart';
import 'data/repositories/firebase_auth_repository.dart';
import 'data/repositories/firebase_product_repository.dart';
import 'firebase_options.dart';
import 'data/repositories/firebase_order_repository.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await EmulatorConfig.configureEmulators();

      if (!kIsWeb) {
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      }

      if (!EmulatorConfig.useEmulator) {
        await FirebaseAppCheck.instance.activate(
          androidProvider:
              kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
          appleProvider:
              kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        );
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
        );
      }

      await FirebaseAnalytics.instance.logAppOpen();

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;

        // Broadcast order offers already appear live in the rider's
        // incoming-offers feed (see DeliveryHomeScreen) — an on-duty rider
        // gets one of these every ~90s while an order sits unaccepted, and
        // stacking a SnackBar per push on top of that feed is just spam.
        if (message.data['type'] == 'new_order_offer') return;

        final title = notification.title;
        final body = notification.body;
        final text =
            [title, body].where((s) => s != null && s.isNotEmpty).join(': ');
        if (text.isEmpty) return;

        final orderId = message.data['orderId'] as String?;
        final messenger = JCMartApp.scaffoldMessengerKey.currentState;
        if (messenger == null) return;

        messenger.showSnackBar(
          SnackBar(
            content: Text(text),
            behavior: SnackBarBehavior.floating,
            action: orderId != null
                ? SnackBarAction(
                    label: 'View',
                    onPressed: () {
                      final ctx = JCMartApp.navigatorKey.currentContext;
                      if (ctx == null) return;
                      final auth =
                          Provider.of<AuthProvider>(ctx, listen: false);
                      final role = auth.currentUserModel?.role;
                      NotificationHandler.handleMessageTap(message, role);
                    },
                  )
                : null,
          ),
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final ctx = JCMartApp.navigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        final auth = Provider.of<AuthProvider>(ctx, listen: false);
        final role = auth.currentUserModel?.role;
        NotificationHandler.handleMessageTap(message, role);
      });

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = JCMartApp.navigatorKey.currentContext;
          if (ctx == null) return;
          final auth = Provider.of<AuthProvider>(ctx, listen: false);
          final role = auth.currentUserModel?.role;
          NotificationHandler.handleMessageTap(initialMessage, role);
        });
      }

      final authRepository = FirebaseAuthRepository();

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthProvider(repository: authRepository),
            ),
            ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
              create: (context) => ProfileProvider(
                authProvider: Provider.of<AuthProvider>(context, listen: false),
                repository: authRepository,
              ),
              update: (context, auth, previous) =>
                  previous ??
                  ProfileProvider(
                    authProvider: auth,
                    repository: authRepository,
                  ),
            ),
            ChangeNotifierProvider(
              create: (_) => CartProvider(
                productRepository: FirebaseProductRepository(),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => OrderProvider(repository: FirebaseOrderRepository()),
            ),
            ChangeNotifierProvider(create: (_) => ProductProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => ConfigProvider()),
            ChangeNotifierProvider(create: (_) => BannerProvider()),
            ChangeNotifierProvider(create: (_) => SupportProvider()),
          ],
          child: const JCMartApp(),
        ),
      );
    } catch (e, stack) {
      debugPrint("Startup failed: $e");
      if (!kIsWeb) {
        try {
          await FirebaseCrashlytics.instance.recordError(e, stack, fatal: true);
        } catch (_) {
          // Crashlytics itself may be the thing that failed to initialise.
        }
      }
      // Never leave the user on a blank screen: show what happened and let
      // them retry (a flaky network at launch is the common cause).
      runApp(const _StartupErrorApp(onRetry: main));
    }
  }, (error, stack) {
    // Uncaught async errors are non-fatal — the app keeps running. Marking
    // them fatal skewed crash-free-user numbers.
    if (!kIsWeb) {
      FirebaseCrashlytics.instance.recordError(error, stack);
    }
  });
}

class _StartupErrorApp extends StatelessWidget {
  final VoidCallback onRetry;
  const _StartupErrorApp({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 64),
                  const SizedBox(height: 20),
                  const Text(
                    "Couldn't start J C Mart",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please check your internet connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
