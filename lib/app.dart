import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/utils/route_generator.dart';
import 'modules/auth/screens/customer_profile_setup_screen.dart';
import 'modules/auth/screens/biometric_lock_screen.dart';
import 'modules/auth/screens/unified_login_screen.dart';
import 'modules/customer/screens/customer_home_screen.dart';
import 'modules/delivery/screens/delivery_home_screen.dart';

class BlinkBasketApp extends StatelessWidget {
  const BlinkBasketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlinkBasket',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Google Sans',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          primary: const Color(0xFF1A73E8),
          surface: Colors.white,
          outline: const Color(0xFFDADCE0),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF202124)),
          titleTextStyle: TextStyle(
            color: Color(0xFF202124),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Google Sans',
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
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
        if (role == 'admin') {
          // Admin needs biometric authentication check on entering/resuming
          return const BiometricLockScreen();
        } else if (role == 'delivery') {
          return const DeliveryHomeScreen();
        } else {
          return const CustomerHomeScreen();
        }
      default:
        return const UnifiedLoginScreen();
    }
  }
}
