import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../modules/auth/screens/login_selection_screen.dart';
import '../../modules/auth/screens/customer_login_screen.dart';
import '../../modules/auth/screens/customer_profile_setup_screen.dart';
import '../../modules/auth/screens/delivery_boy_login_screen.dart';
import '../../modules/auth/screens/admin_login_screen.dart';
import '../../modules/auth/screens/biometric_lock_screen.dart';
import '../../modules/customer/screens/customer_home_screen.dart';
import '../../modules/customer/screens/cart_screen.dart';
import '../../modules/customer/screens/order_history_screen.dart';
import '../../modules/delivery/screens/delivery_home_screen.dart';
import '../../modules/admin/screens/admin_home_screen.dart';

class RouteGenerator {
  static const String splash = '/';
  static const String loginSelection = '/login-selection';
  static const String customerLogin = '/customer-login';
  static const String customerProfileSetup = '/customer-profile-setup';
  static const String deliveryLogin = '/delivery-login';
  static const String adminLogin = '/admin-login';
  static const String biometricLock = '/biometric-lock';
  static const String customerHome = '/customer-home';
  static const String deliveryHome = '/delivery-home';
  static const String adminHome = '/admin-home';
  static const String cart = '/cart';
  static const String orderHistory = '/order-history';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case loginSelection:
        return MaterialPageRoute(builder: (_) => const LoginSelectionScreen());
      case customerLogin:
        return MaterialPageRoute(builder: (_) => const CustomerLoginScreen());
      case customerProfileSetup:
        return MaterialPageRoute(builder: (_) => const CustomerProfileSetupScreen());
      case deliveryLogin:
        return MaterialPageRoute(builder: (_) => const DeliveryBoyLoginScreen());
      case adminLogin:
        return MaterialPageRoute(builder: (_) => const AdminLoginScreen());
      case biometricLock:
        return MaterialPageRoute(builder: (_) => const BiometricLockScreen());
      case customerHome:
        return MaterialPageRoute(builder: (_) => const CustomerHomeScreen());
      case deliveryHome:
        return MaterialPageRoute(builder: (_) => const DeliveryHomeScreen());
      case adminHome:
        return MaterialPageRoute(builder: (_) => const AdminHomeScreen());
      case cart:
        return MaterialPageRoute(builder: (_) => const CartScreen());
      case orderHistory:
        return MaterialPageRoute(builder: (_) => const OrderHistoryScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}

// Temporary placeholder screens to avoid import compiler errors before dashboards are built
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Splash screen routing checks are handled in app.dart based on state changes.
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'BlinkBasket',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            SizedBox(height: 8),
            Text('Hyperlocal Quick-Commerce', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.green),
          ],
        ),
      ),
    );
  }
}

class DummyHomeScreen extends StatelessWidget {
  final String title;
  const DummyHomeScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final provider = Provider.of<AuthProvider>(context, listen: false);
              await provider.logout();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to $title',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Switch Role / Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                final provider = Provider.of<AuthProvider>(context, listen: false);
                await provider.logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
