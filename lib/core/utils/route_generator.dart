import 'dart:async';
import 'package:flutter/material.dart';
import '../../modules/auth/screens/unified_login_screen.dart';
import '../../modules/auth/screens/customer_profile_setup_screen.dart';
import '../../modules/customer/screens/customer_home_screen.dart';
import '../../modules/customer/screens/cart_screen.dart';
import '../../modules/customer/screens/checkout_screen.dart';
import '../../modules/customer/screens/order_history_screen.dart';
import '../../modules/customer/screens/order_success_screen.dart';
import '../../modules/customer/screens/order_tracking_screen.dart';
import '../../modules/customer/screens/product_details_screen.dart';
import '../../modules/customer/screens/search_screen.dart';
import '../../modules/delivery/screens/delivery_home_screen.dart';
import '../../modules/delivery/screens/rider_map_screen.dart';
import '../../modules/delivery/screens/earnings_screen.dart';
import '../../modules/delivery/screens/task_detail_screen.dart';
import '../../modules/admin/screens/store_settings_screen.dart';
import '../../modules/admin/screens/add_rider_screen.dart';
import '../../modules/admin/screens/admin_profile_screen.dart';
import '../../modules/admin/screens/inventory_logs_screen.dart';
import '../../modules/admin/screens/banner_management_screen.dart';
import '../../modules/admin/screens/product_editor_screen.dart';
import '../../modules/admin/screens/stock_alerts_screen.dart';
import '../../modules/admin/screens/admin_rider_detail_screen.dart';
import '../../modules/admin/screens/admin_order_detail_screen.dart';
import '../../modules/customer/screens/support/customer_support_hub_screen.dart';
import '../../modules/customer/screens/support/support_chat_screen.dart';
import '../../modules/admin/screens/admin_support_screen.dart';
import '../../modules/profile/screens/address_book_screen.dart';
import '../../modules/profile/screens/add_address_screen.dart';
import '../../modules/profile/screens/edit_address_screen.dart';
import '../../modules/profile/screens/delete_address_screen.dart';
import '../../modules/profile/screens/privacy_policy_screen.dart';
import '../../modules/profile/screens/terms_conditions_screen.dart';
import '../../modules/profile/screens/user_profile_screen.dart';
import '../../modules/profile/screens/wishlist_screen.dart';
import '../../core/models/user_model.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/support_ticket.dart';
import '../design/transitions.dart';

/// Arguments for [RouteGenerator.orderSuccess] — the success screen needs both
/// the new order id and the amount that was confirmed, so it can't ride on a
/// single positional argument.
typedef OrderSuccessArgs = ({String orderId, double total});

class RouteGenerator {
  static const String splash = '/';
  static const String login = '/login';
  static const String customerLogin = '/customer-login';
  static const String customerProfileSetup = '/customer-profile-setup';
  static const String deliveryLogin = '/delivery-login';
  static const String customerHome = '/customer-home';
  static const String deliveryHome = '/delivery-home';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orderHistory = '/order-history';
  static const String riderMap = '/rider-map';
  static const String earnings = '/earnings';
  static const String taskDetail = '/task-detail';
  static const String storeSettings = '/store-settings';
  static const String productDetails = '/product-details';
  static const String search = '/search';
  static const String orderSuccess = '/order-success';
  static const String orderTracking = '/order-tracking';
  static const String customerSupport = '/customer-support';
  static const String supportChat = '/support-chat';
  static const String adminSupport = '/admin-support';
  static const String adminProfile = '/admin-profile';
  static const String addRider = '/add-rider';
  static const String inventoryLogs = '/inventory-logs';
  static const String bannerManagement = '/banner-management';
  static const String userProfile = '/user-profile';
  static const String wishlist = '/wishlist';
  static const String addressBook = '/address-book';
  static const String addAddress = '/add-address';
  static const String editAddress = '/edit-address';
  static const String deleteAddress = '/delete-address';
  static const String termsConditions = '/terms-conditions';
  static const String privacyPolicy = '/privacy-policy';
  static const String productEditor = '/product-editor';
  static const String stockAlerts = '/stock-alerts';
  static const String adminRiderDetail = '/admin-rider-detail';
  static const String adminOrderDetail = '/admin-order-detail';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return AppPageRoute.fadeThrough((_) => const SplashScreen(), settings: settings);
      case login:
      case customerLogin:
      case deliveryLogin:
        return AppPageRoute.fadeThrough((_) => const UnifiedLoginScreen(), settings: settings);
      case customerProfileSetup:
        return AppPageRoute.slideUp((_) => const CustomerProfileSetupScreen(), settings: settings);
      case customerHome:
        return AppPageRoute.fadeThrough((_) => const CustomerHomeScreen(), settings: settings);
      case deliveryHome:
        return AppPageRoute.fadeThrough((_) => const DeliveryHomeScreen(), settings: settings);
      case cart:
        return AppPageRoute.slideUp((_) => const CartScreen(), settings: settings);
      case checkout:
        return AppPageRoute.slideUp((_) => const CheckoutScreen(), settings: settings);
      case orderHistory:
        return AppPageRoute.slideUp((_) => const OrderHistoryScreen(), settings: settings);
      case riderMap:
        return AppPageRoute.slideUp((_) => const RiderMapScreen(), settings: settings);
      case earnings:
        return AppPageRoute.slideUp((_) => const EarningsScreen(), settings: settings);
      case taskDetail:
        final order = settings.arguments;
        if (order is! Order) return _missingArgsRoute(settings);
        return AppPageRoute.slideUp((_) => TaskDetailScreen(order: order), settings: settings);
      case storeSettings:
        return AppPageRoute.slideUp((_) => const StoreSettingsScreen(), settings: settings);
      case productDetails:
        final product = settings.arguments;
        if (product is! Product) return _missingArgsRoute(settings);
        return AppPageRoute.slideUp((_) => ProductDetailsScreen(product: product), settings: settings);
      case search:
        return AppPageRoute.fadeThrough((_) => const SearchScreen(), settings: settings);
      case orderSuccess:
        final args = settings.arguments;
        if (args is! OrderSuccessArgs) return _missingArgsRoute(settings);
        return AppPageRoute.slideUp(
          (_) => OrderSuccessScreen(orderId: args.orderId, total: args.total),
          settings: settings,
        );
      case orderTracking:
        final orderId = settings.arguments;
        if (orderId is! String || orderId.isEmpty) return _missingArgsRoute(settings);
        return AppPageRoute.slideUp(
          (_) => OrderTrackingScreen(orderId: orderId),
          settings: settings,
        );
      case userProfile:
        return AppPageRoute.slideUp((_) => const UserProfileScreen(), settings: settings);
      case wishlist:
        return AppPageRoute.slideUp((_) => const WishlistScreen(), settings: settings);
      case addressBook:
        return AppPageRoute.slideUp((_) => const AddressBookScreen(), settings: settings);
      case addAddress:
        return AppPageRoute.slideUp((_) => const AddAddressScreen(), settings: settings);
      case editAddress:
        final address = settings.arguments;
        if (address is! AddressModel) return _missingArgsRoute(settings);
        return AppPageRoute.slideUp(
          (_) => EditAddressScreen(address: address),
          settings: settings,
        );
      case deleteAddress:
        final address = settings.arguments;
        if (address is! AddressModel) return _missingArgsRoute(settings);
        return AppPageRoute.slideUp(
          (_) => DeleteAddressScreen(address: address),
          settings: settings,
        );
      case termsConditions:
        return AppPageRoute.slideUp((_) => const TermsConditionsScreen(), settings: settings);
      case privacyPolicy:
        return AppPageRoute.slideUp((_) => const PrivacyPolicyScreen(), settings: settings);
      case customerSupport:
        final orderId = settings.arguments as String?;
        return AppPageRoute.slideUp((_) => CustomerSupportHubScreen(initialOrderId: orderId), settings: settings);
      case supportChat:
        final ticket = settings.arguments;
        if (ticket is! SupportTicket) return _missingArgsRoute(settings);
        return AppPageRoute.slideUp((_) => SupportChatScreen(ticket: ticket), settings: settings);
      case adminSupport:
        return AppPageRoute.slideUp((_) => const AdminSupportScreen(), settings: settings);
      case adminProfile:
        return AppPageRoute.slideUp((_) => const AdminProfileScreen(), settings: settings);
      case addRider:
        return AppPageRoute.slideUp((_) => const AddRiderScreen(), settings: settings);
      case inventoryLogs:
        return AppPageRoute.slideUp((_) => const InventoryLogsScreen(), settings: settings);
      case bannerManagement:
        return AppPageRoute.slideUp((_) => const BannerManagementScreen(), settings: settings);
      case productEditor:
        // Arguments: the Product to edit, or null to add a new one.
        final product = settings.arguments;
        if (product != null && product is! Product) return _missingArgsRoute(settings);
        return AppPageRoute.slideUp(
          (_) => ProductEditorScreen(existing: product as Product?),
          settings: settings,
        );
      case stockAlerts:
        return AppPageRoute.slideUp((_) => const StockAlertsScreen(), settings: settings);
      case adminRiderDetail:
        final riderId = settings.arguments;
        if (riderId is! String || riderId.isEmpty) return _missingArgsRoute(settings);
        return AppPageRoute.slideUp((_) => AdminRiderDetailScreen(riderId: riderId), settings: settings);
      case adminOrderDetail:
        final orderId = settings.arguments;
        if (orderId is! String || orderId.isEmpty) return _missingArgsRoute(settings);
        return AppPageRoute.slideUp((_) => AdminOrderDetailScreen(orderId: orderId), settings: settings);
      default:
        return AppPageRoute.fadeThrough(
          (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
          settings: settings,
        );
    }
  }

  /// Route pushed with the wrong (or missing) `arguments` type — e.g. deep
  /// link/back-stack restore without the expected object. Shows an error
  /// screen instead of crashing on a bad `as` cast.
  static Route<dynamic> _missingArgsRoute(RouteSettings settings) {
    return AppPageRoute.fadeThrough(
      (_) => Scaffold(
        body: Center(child: Text('Missing data for ${settings.name}')),
      ),
      settings: settings,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timeoutTimer;
  bool _showFallback = false;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _showFallback = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8CB46),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shopping_bag_rounded,
                        size: 48,
                        color: Color(0xFF1C1C1C),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'J C Mart',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'HYPERLOCAL QUICK-COMMERCE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
                if (_showFallback) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Connection is taking longer than usual',
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, RouteGenerator.login);
                          },
                          child: const Text('Proceed to Login'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

