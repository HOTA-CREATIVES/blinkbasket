import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/banner_carousel.dart';
import '../../../core/design/widgets/category_icon_rail.dart';
import '../../../core/design/widgets/delivery_eta_badge.dart';
import '../../../core/design/widgets/product_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/product_provider.dart';
import '../../../domain/entities/app_config.dart';
import '../../../domain/entities/product.dart';
import '../../profile/screens/user_profile_screen.dart';
import 'product_details_screen.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'search_screen.dart';

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
  late final Stream<List<Product>> _productsStream =
      context.read<ProductProvider>().streamProducts();
  late final Stream<AppConfig> _configStream =
      context.read<ConfigProvider>().streamAppConfig();

  void _selectCategory(String category) {
    setState(() => _selectedCategory = category);
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int badgeCount = 0}) {
    final isSelected = _currentIndex == index;
    final scheme = Theme.of(context).colorScheme;

    Widget iconWidget = Icon(
      icon,
      color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
      size: 24,
    );

    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text('$badgeCount'),
        backgroundColor: scheme.error,
        child: iconWidget,
      );
    }

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(AppTokens.rXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    // Non-listening: this build() also constructs the product grid, and
    // CartProvider fires on every add/remove tap. Cart-count-dependent UI
    // below (FAB, nav badge) reads it via its own Consumer/select scope
    // instead, so a cart change doesn't re-run the whole grid's itemBuilder.
    final user = authProvider.currentUserModel;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: scheme.primary)),
      );
    }

    final storeBody = Column(
      children: [
        // Search bar — tap-through to the dedicated SearchScreen (recent
        // searches, debounced query) rather than filtering this grid inline.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTokens.rPill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.rPill),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.s16, vertical: AppTokens.s12),
                child: Row(
                  children: [
                    Icon(Icons.search, color: scheme.onSurfaceVariant),
                    const SizedBox(width: AppTokens.s12),
                    Text(
                      'Search fresh produce, dairy, bakery...',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Promo banner carousel — hidden automatically when no banners are set.
        BannerCarousel(onBannerTap: _selectCategory),
        // Shop-by-category icon rail — admin-configured list, falling back
        // to built-in defaults until the admin sets one.
        StreamBuilder<AppConfig>(
          stream: _configStream,
          builder: (context, snapshot) {
            final adminCategories = snapshot.data?.categories ?? const [];
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
        const SizedBox(height: AppTokens.s4),
        // Product Grid View
        Expanded(
          child: StreamBuilder<List<Product>>(
            stream: _productsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: scheme.primary));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text('No products available. Check again later!', style: TextStyle(color: scheme.onSurfaceVariant)),
                );
              }

              // Filter by category — free-text search lives on SearchScreen.
              final products = snapshot.data!
                  .where((prod) => _selectedCategory == 'All' || prod.category == _selectedCategory)
                  .toList();

              if (products.isEmpty) {
                return Center(
                  child: Text('No matching items found.', style: TextStyle(color: scheme.onSurfaceVariant)),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(AppTokens.s16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: AppTokens.s16,
                  mainAxisSpacing: AppTokens.s16,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Consumer<CartProvider>(
                    builder: (context, cartProvider, child) {
                      final inCartQty = cartProvider.quantityOf(product.id);
                      return ProductCard(
                        product: product,
                        quantityInCart: inCartQty,
                        onAdd: () => cartProvider.addItem(product),
                        onRemove: () => cartProvider.decrementItem(product.id),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailsScreen(product: product),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    final tabs = [
      Scaffold(
        appBar: AppBar(
          toolbarHeight: 108,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('J C Mart', style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary)),
              Text(
                'Deliver to: ${user.village} (${user.phone})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.normal),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: DeliveryEtaBadge(style: DeliveryEtaBadgeStyle.chrome),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: storeBody,
        // Consumer, not the outer cartProvider read — isolates this bar's
        // rebuild to itself instead of re-running the whole tab's build().
        floatingActionButton: Consumer<CartProvider>(
          builder: (context, cart, _) => cart.itemCount > 0
              ? Padding(
                  // Raised above the bottom navbar; full-width sticky mini-cart bar.
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 78),
                  child: SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      elevation: 4,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppTokens.rLg),
                        onTap: () => setState(() => _currentIndex = 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.s16, vertical: AppTokens.s12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppTokens.s4),
                                decoration: BoxDecoration(
                                  color: scheme.onPrimary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppTokens.rSm),
                                ),
                                child: Icon(Icons.shopping_bag_rounded,
                                    color: scheme.onPrimary, size: 20),
                              ),
                              const SizedBox(width: AppTokens.s12),
                              Expanded(
                                child: Text(
                                  '${cart.itemCount} item${cart.itemCount > 1 ? 's' : ''} • ₹${cart.totalAmount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: scheme.onPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                'View Cart',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: scheme.onPrimary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
      const CartScreen(),
      const OrderHistoryScreen(),
      const UserProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppTokens.rPill),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.storefront_rounded, 'Store'),
                Consumer<CartProvider>(
                  builder: (context, cart, _) => _buildNavItem(
                    1,
                    Icons.shopping_cart_rounded,
                    'Cart',
                    badgeCount: cart.itemCount,
                  ),
                ),
                _buildNavItem(2, Icons.receipt_long_rounded, 'My Orders'),
                _buildNavItem(3, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
