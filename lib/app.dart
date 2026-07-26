import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/route_generator.dart';
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
      onGenerateRoute: RouteGenerator.generateRoute,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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
