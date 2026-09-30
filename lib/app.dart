import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/banner_provider.dart';
import 'core/providers/support_provider.dart';
import 'core/providers/cart_provider.dart';
import 'core/providers/config_provider.dart';
import 'core/providers/order_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/route_generator.dart';
import 'core/widgets/connectivity_banner.dart';
import 'modules/auth/screens/customer_profile_setup_screen.dart';
import 'modules/auth/screens/unified_login_screen.dart';
import 'modules/customer/screens/customer_home_screen.dart';
import 'modules/delivery/screens/delivery_home_screen.dart';
import 'modules/admin/screens/admin_home_screen.dart';

class JCMartApp extends StatelessWidget {
  const JCMartApp({super.key});

  /// Lets code outside the widget tree (e.g. the foreground FCM listener in
  /// main.dart) show a SnackBar without needing a BuildContext.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Global navigator key so notification tap handlers can push routes
  /// without a BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'J C Mart',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      onGenerateRoute: RouteGenerator.generateRoute,
      home: const ConnectivityBanner(child: AuthWrapper()),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  AuthStatus? _lastStatus;
  String? _lastUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    final uid = authProvider.isAuthenticated
        ? authProvider.currentUserModel?.uid
        : null;

    // Sync cart user whenever auth status changes — replaces the old direct
    // FirebaseAuth listener that was inside CartProvider.
    if (authProvider.status != _lastStatus) {
      _lastStatus = authProvider.status;
      Provider.of<CartProvider>(context, listen: false).setUser(uid);
    }

    // The signed-in user changed (sign-out, forced logout, or another account
    // signing in). Everything cached for the previous user must go: shared
    // listeners are killed by Firestore on sign-out and would otherwise stay
    // dead — and keep the previous user's data — for the next login.
    if (uid != _lastUid) {
      final hadUser = _lastUid != null;
      _lastUid = uid;
      if (hadUser) {
        Provider.of<OrderProvider>(context, listen: false).resetSession();
        Provider.of<ConfigProvider>(context, listen: false).resetSession();
        Provider.of<SupportProvider>(context, listen: false).resetSession();
        Provider.of<BannerProvider>(context, listen: false).resetSession();
        // Screens pushed on top of this one (detail pages, checkout, ...)
        // must not survive a forced logout.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          JCMartApp.navigatorKey.currentState?.popUntil((route) => route.isFirst);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    switch (authProvider.status) {
      case AuthStatus.uninitialized:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
        return const UnifiedLoginScreen();
      case AuthStatus.needsProfileSetup:
        return const CustomerProfileSetupScreen();
      case AuthStatus.authenticated:
        final role = authProvider.currentUserModel?.role;
        if (role == 'delivery') {
          return const DeliveryHomeScreen();
        } else if (role == 'customer') {
          return const CustomerHomeScreen();
        } else if (role == 'admin') {
          return const AdminHomeScreen();
        } else {
          return const UnifiedLoginScreen();
        }
      default:
        return const UnifiedLoginScreen();
    }
  }
}
