import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/banner_carousel.dart';
import '../../../core/design/widgets/category_icon_rail.dart';
import '../../../core/design/widgets/email_verification_banner.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/floating_navbar.dart';
import '../../../core/design/widgets/product_card.dart';
import '../../../core/design/widgets/skeleton.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/product_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/customer_helper.dart';
import '../../../domain/entities/app_config.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/service_zone.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/utils/route_generator.dart';
import '../../../domain/entities/order.dart';

/// Used when the admin hasn't configured a custom category list yet.
const List<String> _kDefaultCategories = [
  'All',
  'Fruits & Vegetables',
  'Dairy & Eggs',
  'Bakery',
  'Medicines',
  'Snacks',
  'Beverages',
  'Household',
];

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String _selectedCategory = 'All';
  int _currentIndex = 0;
  bool _checkedBoundary = false;
  late final Stream<List<Product>> _productsStream =
      context.read<ProductProvider>().streamProducts();
  late final Stream<AppConfig> _configStream =
      context.read<ConfigProvider>().streamAppConfig();
  String? _ordersStreamUid;
  Stream<List<Order>>? _ordersStream;

  /// Memoized per-uid — the active-order bar rebuilds on every cart/auth
  /// change, and streamCustomerOrders() opens a fresh Firestore listener
  /// each call, so calling it straight from build() churned a new listener
  /// on every rebuild.
  Stream<List<Order>> _ordersStreamFor(String uid) {
    if (_ordersStreamUid != uid) {
      _ordersStreamUid = uid;
      _ordersStream =
          context.read<OrderProvider>().streamCustomerOrders(uid);
    }
    return _ordersStream!;
  }

  void _selectCategory(String category) {
    setState(() => _selectedCategory = category);
  }

  void _checkBoundaryNotice(UserModel user, List<ServiceZone> serviceZones) {
    if (_checkedBoundary) return;
    _checkedBoundary = true;

    bool isOut = !user.deliveryAvailable;
    if (user.addresses.isNotEmpty) {
      final defaultAddr = user.addresses.firstWhere((a) => a.isDefault, orElse: () => user.addresses.first);
      final lat = defaultAddr.latitude;
      final lng = defaultAddr.longitude;
      // Addresses saved without a pin have no coordinates — nothing to check.
      if (lat != null && lng != null && !(lat == 0.0 && lng == 0.0)) {
        final zoneResult = CustomerHelper.nearestZone(lat, lng, serviceZones);
        if (!zoneResult.isInside) {
          isOut = true;
        }
      }
    }

    if (isOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showOutOfBoundaryModal(context);
      });
    }
  }

  void _showOutOfBoundaryModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rXl)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Outside Service Area",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          "Sorry, we don't deliver to your current location right now. "
          "You can place an order for someone else in our delivery zone or browse our store catalog.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Browse Catalog", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.pushNamed(context, RouteGenerator.addressBook);
            },
            icon: const Icon(Icons.location_on_rounded, size: 18),
            label: const Text("Order for Someone Else", style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: scheme.primary)),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.read<CartProvider>().setUser(user.uid);
      }
    });

    // 🌟 Blinkit-Style Green Gradient Header & Auto-Collapsible Store View
    final storeCustomScrollView = CustomScrollView(
      slivers: [
        // 1. Blinkit Green Gradient Header (Pinned with integrated search bar)
        SliverAppBar(
          pinned: true,
          floating: false,
          elevation: 2,
          expandedHeight: 124,
          toolbarHeight: 64,
          backgroundColor: const Color(0xFF0F766E),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF16A34A), Color(0xFF15803D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
          ),
          leadingWidth: 52,
          leading: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTokens.brandChrome,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: AppTokens.onBrandChrome,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'JC Mart',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              InkWell(
                onTap: () => Navigator.pushNamed(context, RouteGenerator.addressBook),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me_rounded, size: 12, color: AppTokens.brandChrome),
                    const SizedBox(width: 4),
                    Text(
                      user.village.isNotEmpty ? user.village : 'Select Location',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.white70),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.transparent,
                  backgroundImage: (user.avatarUrl != null && user.avatarUrl!.isNotEmpty && user.avatarUrl!.startsWith('http'))
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: (user.avatarUrl == null || user.avatarUrl!.isEmpty || !user.avatarUrl!.startsWith('http'))
                      ? const Icon(Icons.person_rounded, color: Colors.white, size: 18)
                      : null,
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, RouteGenerator.userProfile);
              },
            ),
            const SizedBox(width: 8),
          ],
          // Integrated Blinkit White Search Bar inside Header
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTokens.rPill),
                shadowColor: Colors.black.withValues(alpha: 0.2),
                elevation: 3,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTokens.rPill),
                  onTap: () =>
                      Navigator.pushNamed(context, RouteGenerator.search),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: AppTokens.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Search "milk", "bread", "vegetables"...',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTokens.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic_rounded, color: AppTokens.primary, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Collapsible Section (Store closed banner + Banner Carousel + Category Icons)
        SliverToBoxAdapter(
          child: Column(
            children: [
              const EmailVerificationBanner(),
              StreamBuilder<AppConfig>(
                stream: _configStream,
                builder: (context, snapshot) {
                  final config = snapshot.data;
                  if (config != null && !config.storeOpen) {
                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTokens.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTokens.rMd),
                        border: Border.all(color: AppTokens.warning.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.store_mall_directory_outlined, color: AppTokens.warning, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'The store is closed. You can browse, but orders can\'t be placed until it reopens.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 8),

              // Banner Carousel
              BannerCarousel(onBannerTap: _selectCategory),

              // Shop-by-Category Icon Rail
              StreamBuilder<AppConfig>(
                stream: _configStream,
                builder: (context, snapshot) {
                  final config = snapshot.data;
                  if (config != null) {
                    _checkBoundaryNotice(user, config.serviceZones);
                  }
                  final adminCategories = config?.categories ?? const [];
                  final categories = [
                    'All',
                    ...(adminCategories.isNotEmpty
                        ? adminCategories
                        : _kDefaultCategories.skip(1)),
                  ];
                  return CategoryIconRail(
                    categories: categories,
                    selectedCategory: _selectedCategory,
                    onSelect: _selectCategory,
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        // 3. Product Grid View
        StreamBuilder<List<Product>>(
          stream: _productsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Couldn\'t load products. Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const SliverFillRemaining(
                child: SkeletonProductGrid(),
              );
            }

            if (snapshot.hasError) {
              return SliverFillRemaining(
                child: EmptyState.error(
                  onAction: () => setState(() {}),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products available',
                  message: 'Check back soon — new items are added regularly.',
                ),
              );
            }

            final products = snapshot.data!
                .where((prod) => _selectedCategory == 'All' || prod.category == _selectedCategory)
                .toList();

            if (products.isEmpty) {
              return SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.category_outlined,
                  title: 'No items in this category',
                  message: 'Try browsing a different category.',
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = products[index];
                    return Consumer<CartProvider>(
                      builder: (context, cartProvider, child) {
                        final inCartQty = cartProvider.quantityOf(product.id);
                        return ProductCard(
                          product: product,
                          quantityInCart: inCartQty,
                          onAdd: () => cartProvider.addItem(product),
                          onRemove: () => cartProvider.decrementItem(product.id),
                          onTap: () => Navigator.pushNamed(
                            context,
                            RouteGenerator.productDetails,
                            arguments: product,
                          ),
                        );
                      },
                    );
                  },
                  childCount: products.length,
                ),
              ),
            );
          },
        ),

        // Bottom space for active cart bar overhang
        const SliverToBoxAdapter(
          child: SizedBox(height: 60),
        ),
      ],
    );

    final tabs = [
      Scaffold(
        body: storeCustomScrollView,
      ),
      const CartScreen(),
      const OrderHistoryScreen(),
      const OrderHistoryScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),

      bottomNavigationBar: StreamBuilder<List<Order>>(
        stream: _ordersStreamFor(user.uid),
        builder: (context, ordersSnapshot) {
          final activeOrders = (ordersSnapshot.data ?? []).where((o) =>
            o.status != 'delivered' && o.status != 'cancelled'
          ).toList();

          return Consumer<CartProvider>(
            builder: (context, cart, _) {
              return FloatingNavbar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  if (index == 2) {
                    // Pending / Active Order tab clicked
                    if (activeOrders.isNotEmpty) {
                      Navigator.pushNamed(
                        context,
                        RouteGenerator.orderTracking,
                        arguments: activeOrders.first.id,
                      );
                    } else {
                      setState(() => _currentIndex = 3);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No active pending order at the moment.'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } else {
                    setState(() => _currentIndex = index);
                  }
                },
                items: [
                  const FloatingNavItem(
                    icon: Icons.storefront_outlined,
                    activeIcon: Icons.storefront_rounded,
                    label: 'Store',
                  ),
                  FloatingNavItem(
                    icon: Icons.shopping_cart_outlined,
                    activeIcon: Icons.shopping_cart_rounded,
                    label: 'Cart',
                    badgeCount: cart.itemCount,
                  ),
                  FloatingNavItem(
                    icon: Icons.directions_bike_outlined,
                    activeIcon: Icons.directions_bike_rounded,
                    label: 'Pending',
                    badgeCount: activeOrders.length,
                  ),
                  const FloatingNavItem(
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long_rounded,
                    label: 'Orders',
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
