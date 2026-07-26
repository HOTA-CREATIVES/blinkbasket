import 'package:flutter/material.dart';
import '../../modules/auth/screens/unified_login_screen.dart';
import '../../modules/auth/screens/customer_profile_setup_screen.dart';
import '../../modules/customer/screens/customer_home_screen.dart';
import '../../modules/customer/screens/cart_screen.dart';
import '../../modules/customer/screens/order_history_screen.dart';
import '../../modules/customer/screens/product_details_screen.dart';
import '../../modules/delivery/screens/delivery_home_screen.dart';
import '../../modules/delivery/screens/rider_map_screen.dart';
import '../../modules/delivery/screens/earnings_screen.dart';
import '../../modules/delivery/screens/task_detail_screen.dart';
import '../../modules/admin/screens/store_settings_screen.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/product.dart';

class RouteGenerator {
  static const String splash = '/';
  static const String login = '/login';
  static const String customerLogin = '/customer-login';
  static const String customerProfileSetup = '/customer-profile-setup';
  static const String deliveryLogin = '/delivery-login';
  static const String customerHome = '/customer-home';
  static const String deliveryHome = '/delivery-home';
  static const String cart = '/cart';
  static const String orderHistory = '/order-history';
  static const String riderMap = '/rider-map';
  static const String earnings = '/earnings';
  static const String taskDetail = '/task-detail';
  static const String storeSettings = '/store-settings';
  static const String productDetails = '/product-details';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
      case customerLogin:
      case deliveryLogin:
        return MaterialPageRoute(builder: (_) => const UnifiedLoginScreen());
      case customerProfileSetup:
        return MaterialPageRoute(builder: (_) => const CustomerProfileSetupScreen());
      case customerHome:
        return MaterialPageRoute(builder: (_) => const CustomerHomeScreen());
      case deliveryHome:
        return MaterialPageRoute(builder: (_) => const DeliveryHomeScreen());
      case cart:
        return MaterialPageRoute(builder: (_) => const CartScreen());
      case orderHistory:
        return MaterialPageRoute(builder: (_) => const OrderHistoryScreen());
      case riderMap:
        return MaterialPageRoute(builder: (_) => const RiderMapScreen());
      case earnings:
        return MaterialPageRoute(builder: (_) => const EarningsScreen());
      case taskDetail:
        final order = settings.arguments as Order;
        return MaterialPageRoute(builder: (_) => TaskDetailScreen(order: order));
      case storeSettings:
        return MaterialPageRoute(builder: (_) => const StoreSettingsScreen());
      case productDetails:
        final product = settings.arguments as Product;
        return MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product));
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/logo.png',
                height: 80,
                width: 80,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'J C Mart',
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

