import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/utils/biometric_auth.dart';
import '../../../core/providers/product_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../domain/entities/product.dart' as ent;
import '../../../domain/entities/order.dart' as ord;
import '../../../domain/entities/dashboard_stats.dart';
import '../../../core/models/user_model.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/status_chip.dart';
import '../../../core/utils/route_generator.dart';
import 'widgets/metric_card.dart';
import 'widgets/order_actions_sheet.dart';
import 'widgets/edit_rider_sheet.dart';
import 'widgets/product_ledger_sheet.dart';
import '../../../core/utils/app_exception.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isLocked = true;
  // Mirrors the "Biometric Console Lock" switch on the admin profile screen
  // (SharedPreferences 'admin_biometric_lock_enabled'). That switch used to
  // save the preference but nothing here ever read it.
  bool _lockEnabled = true;
  String _orderFilter = 'active'; // active | searching | completed | all
  String _riderSearchQuery = '';
  String _selectedRiderVillage = 'All';


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLock();
  }

  Future<void> _loadLockPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lockEnabled = prefs.getBool('admin_biometric_lock_enabled') ?? true;
    } catch (_) {}
    if (!_lockEnabled && mounted) setState(() => _isLocked = false);
  }

  Future<void> _initLock() async {
    await _loadLockPref();
    if (_lockEnabled) await _authenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lockEnabled &&
        (state == AppLifecycleState.paused || state == AppLifecycleState.inactive)) {
      setState(() {
        _isLocked = true; // Lock immediately on backgrounding
      });
    }
  }

  Future<void> _authenticate() async {
    final authenticated = await requestLocalAuth(
        'Please authenticate to access the Admin Operations Console');
    if (authenticated && mounted) {
      setState(() {
        _isLocked = false;
      });
    }
  }

  void _showAddRiderBottomSheet(BuildContext context) {
    Navigator.pushNamed(context, RouteGenerator.addRider);
  }

  // Add / edit product is a full page now (was a cramped bottom sheet).
  void _showAddProductBottomSheet(BuildContext context) {
    Navigator.pushNamed(context, RouteGenerator.productEditor);
  }

  void _showEditProductBottomSheet(BuildContext context, ent.Product product) {
    Navigator.pushNamed(context, RouteGenerator.productEditor, arguments: product);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;

    final scheme = Theme.of(context).colorScheme;
    final dashboardContent = Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? 'Admin Dashboard'
              : _currentIndex == 1
                  ? 'Order Management'
                  : _currentIndex == 2
                      ? 'Inventory Catalog'
                      : 'Delivery Partners',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded),
            tooltip: 'Customer Support Desk',
            onPressed: () {
              Navigator.pushNamed(context, RouteGenerator.adminSupport);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Store Configurations',
            onPressed: () {
              Navigator.pushNamed(context, RouteGenerator.storeSettings);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () async {
                await Navigator.pushNamed(context, RouteGenerator.adminProfile);
                // The lock switch lives on that screen — pick up any change.
                _loadLockPref();
              },
              child: Builder(builder: (context) {
                final cs = Theme.of(context).colorScheme;
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    (user?.name.isNotEmpty == true)
                        ? user!.name[0].toUpperCase()
                        : 'A',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardTab(context),
          _buildOrdersTab(context),
          _buildInventoryTab(context),
          _buildRidersTab(context),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Builder(builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            return Container(
              height: 72,
              decoration: BoxDecoration(
                color: scheme.inverseSurface,
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
                  _buildNavItem(1, Icons.shopping_bag_rounded, 'Orders'),
                  _buildNavItem(2, Icons.inventory_2_rounded, 'Catalog'),
                  _buildNavItem(3, Icons.people_rounded, 'Riders'),
                ],
              ),
            );
          }),
        ),
      ),
      floatingActionButton: _currentIndex == 2
          ? FloatingActionButton(
              onPressed: () => _showAddProductBottomSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
    );

    if (!_isLocked) {
      return dashboardContent;
    }

    // Flat lock screen — no blur/glassmorphism.
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_person_rounded,
                    size: 64,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Console Locked',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'Biometric or PIN verification required to access sensitive operations.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('UNLOCK CONSOLE',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final scheme = Theme.of(context).colorScheme;
    final selectedColor = scheme.onInverseSurface;
    final unselectedColor = scheme.onInverseSurface.withValues(alpha: 0.55);
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.onInverseSurface.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selectedColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== DASHBOARD TAB ====================
  Widget _buildDashboardTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Banner
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 28,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, ${user?.name ?? 'Admin'}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'admin@jcmart.com',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Overview Title
          Text(
            'Live Overview Metrics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // ── O(1) Metrics Grid from /config/dashboard_stats ──
          StreamBuilder<DashboardStats>(
            stream: Provider.of<ConfigProvider>(context, listen: false).streamDashboardStats(),
            builder: (context, snap) {
              // Only the very first load shows a spinner — a re-subscribe
              // keeps the previous data, so don't blank the cards for it.
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppTokens.primary));
              }
              final stats = snap.data;
              final activeOrders = stats?.activeOrdersCount ?? 0;
              final riderCount   = stats?.activeRidersCount ?? 0;
              final revenue      = stats?.completedRevenue ?? 0.0;
              final productCount = stats?.productCount ?? 0;

              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _buildMetricCard(
                    title: 'Active Orders',
                    value: '$activeOrders',
                    icon: Icons.shopping_bag_outlined,
                    color: AppTokens.statusPending,
                    scheme: scheme,
                  ),
                  _buildMetricCard(
                    title: 'Registered Riders',
                    value: '$riderCount',
                    icon: Icons.delivery_dining_outlined,
                    color: AppTokens.statusDelivered,
                    scheme: scheme,
                  ),
                  _buildMetricCard(
                    title: 'Revenue',
                    value: '₹${revenue.toStringAsFixed(0)}',
                    icon: Icons.currency_rupee_rounded,
                    color: AppTokens.statusAssigned,
                    scheme: scheme,
                  ),
                  _buildMetricCard(
                    title: 'Products in Catalog',
                    value: '$productCount',
                    icon: Icons.inventory_2_outlined,
                    color: AppTokens.statusPickedUp,
                    scheme: scheme,
                  ),
                ],
              );
            },
          ),


          StreamBuilder<List<ent.Product>>(
            stream: Provider.of<ProductProvider>(context, listen: false).streamProducts(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final lowStock = snapshot.data!
                  .where((p) => p.availableStock < p.lowStockThreshold)
                  .toList();
              if (lowStock.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                      const SizedBox(width: 8),
                      // Expanded: this Text used to sit bare in the Row and
                      // overflowed ("Action Requ…" + the striped marker).
                      Expanded(
                        child: Text(
                          'Low Stock — Action Required',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, RouteGenerator.stockAlerts),
                        child: Text('View all (${lowStock.length})'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 144,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: lowStock.length,
                      itemBuilder: (context, index) {
                        final product = lowStock[index];
                        // Tapping the card opens the product editor directly.
                        return GestureDetector(
                          onTap: () => _showEditProductBottomSheet(context, product),
                          child: Container(
                          width: 260,
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: scheme.error.withValues(alpha: 0.3), width: 1),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: product.imageUrl.isNotEmpty
                                    ? Image.network(
                                        product.imageUrl,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: scheme.outlineVariant,
                                          width: 60,
                                          height: 60,
                                          child: const Icon(Icons.image_not_supported),
                                        ),
                                      )
                                    : Container(
                                        color: scheme.outlineVariant,
                                        width: 60,
                                        height: 60,
                                        child: const Icon(Icons.image_outlined),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${product.availableStock} left in stock',
                                      style: TextStyle(
                                        color: scheme.error,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final provider = Provider.of<ProductProvider>(context, listen: false);
                                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                        final adminId = authProvider.currentUserModel?.uid ?? '';
                                        // No fake fallback id: a ledger entry must be
                                        // attributable to a real signed-in admin.
                                        if (adminId.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Sign in again to adjust stock.')),
                                          );
                                          return;
                                        }
                                        final success = await provider.adjustStock(
                                          productId: product.id,
                                          physicalDelta: 10,
                                          reservedDelta: 0,
                                          changeType: 'restock',
                                          notes: 'Dashboard Quick Restock (+10)',
                                          adminId: adminId,
                                        );
                                        if (success && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Restocked ${product.name} (+10)!'),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: scheme.error,
                                        foregroundColor: scheme.onError,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text(
                                        'QUICK RESTOCK (+10)',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),


          const SizedBox(height: 32),

          // Action Shortcuts
          Text(
            'Quick Operations',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildOperationCard(
                  title: 'Whitelist Rider',
                  subtitle: 'Create a rider login',
                  icon: Icons.person_add_rounded,
                  color: Colors.green.shade700,
                  onTap: () => _showAddRiderBottomSheet(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ORDERS TAB ====================
  // The old "Pending Assignment" / "Active Runs" tabs assumed an admin manually
  // assigns riders. Orders are now auto-broadcast and claimed by riders, so a
  // pending order is just a transient "searching" state — it lives here as one
  // filter, which keeps a stuck order visible (and cancellable) without a
  // dedicated tab.
  Widget _buildOrdersTab(BuildContext context) => _buildOrderQueue();

  static bool _isClosed(ord.Order o) => o.status == 'delivered' || o.status == 'cancelled';

  bool _matchesOrderFilter(ord.Order o) {
    switch (_orderFilter) {
      case 'searching':
        return o.status == 'pending';
      case 'completed':
        return _isClosed(o);
      case 'all':
        return true;
      default: // 'active' — everything still in flight
        return !_isClosed(o);
    }
  }

  Widget _buildOrderQueue() {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    return StreamBuilder<List<ord.Order>>(
      stream: orderProvider.streamAllOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTokens.primary));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No orders yet',
            message: 'Orders will appear here as customers place them.',
          );
        }

        final allOrders = snapshot.data!;
        final filtered = allOrders.where(_matchesOrderFilter).toList();

        Widget filterChip(String value, String label, int count) => ChoiceChip(
              label: Text('$label ($count)'),
              selected: _orderFilter == value,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: _orderFilter == value ? Theme.of(context).colorScheme.primary : null,
              ),
              onSelected: (_) => setState(() => _orderFilter = value),
            );

        final chips = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Row(
            children: [
              filterChip('active', 'In progress', allOrders.where((o) => !_isClosed(o)).length),
              const SizedBox(width: 8),
              filterChip('searching', 'Searching rider', allOrders.where((o) => o.status == 'pending').length),
              const SizedBox(width: 8),
              filterChip('completed', 'Completed', allOrders.where(_isClosed).length),
              const SizedBox(width: 8),
              filterChip('all', 'All', allOrders.length),
            ],
          ),
        );

        if (filtered.isEmpty) {
          return Column(
            children: [
              chips,
              const Expanded(
                child: EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Nothing here',
                  message: 'No orders match this filter right now.',
                ),
              ),
            ],
          );
        }

        return Column(children: [
          chips,
          Expanded(child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => Divider(color: Theme.of(context).colorScheme.outlineVariant),
          itemBuilder: (context, index) {
            final order = filtered[index];
            final id = order.id;
            final customerName = order.customerName;
            final village = order.village;
            final totalAmount = order.totalAmount;
            final status = order.status;
            final riderName = order.deliveryBoyName ?? '';

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ID: ...${id.substring(id.length - 8).toUpperCase()}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        StatusChip(status: status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      customerName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Destination: $village • Bill: ₹$totalAmount',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                    if (riderName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.delivery_dining, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Rider: $riderName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (status == 'pending' && (order.deliveryBoyId ?? '').isEmpty) ...[
                      const SizedBox(height: 12),
                      // Blinkit-style auto-broadcast has replaced manual
                      // assignment — orders are offered to on-duty riders
                      // and claimed via the acceptOrder Cloud Function.
                      // This is a passive status only; there is no admin
                      // action here anymore.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              (order.notifyTier ?? 1) >= 2
                                  ? 'Searching for a rider (wide search)…'
                                  : 'Searching for a nearby rider…',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            RouteGenerator.adminOrderDetail,
                            arguments: order.id,
                          ),
                          icon: const Icon(Icons.route_rounded, size: 16),
                          label: const Text('Track'),
                        ),
                        if (!_isClosed(order))
                          TextButton.icon(
                            onPressed: () => showOrderActionsSheet(context, order),
                            icon: const Icon(Icons.tune_rounded, size: 16),
                            label: const Text('Manage'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        )),
        ]);
      },
    );
  }

  // ==================== INVENTORY TAB ====================
  Widget _buildInventoryTab(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    return StreamBuilder<List<ent.Product>>(
      stream: productProvider.streamProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTokens.primary));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No products in catalog',
            message: 'Add your first product to get started.',
          );
        }

        final products = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final scheme = Theme.of(context).colorScheme;
            final product = products[index];
            final imageUrl = product.imageUrl;
            final name = product.name;
            final category = product.category;
            final price = product.price;
            final unit = product.unit;
            
            final isLowStock = product.availableStock < product.lowStockThreshold;
            final isOutOfStock = product.availableStock == 0;
            
            Color statusColor;
            Color statusTextColor;
            String statusText;
            if (isOutOfStock) {
              statusColor = scheme.error;
              statusTextColor = scheme.error;
              statusText = 'OUT OF STOCK';
            } else if (isLowStock) {
              statusColor = AppTokens.accent;
              statusTextColor = AppTokens.accent;
              statusText = 'LOW STOCK';
            } else {
              statusColor = scheme.primary;
              statusTextColor = scheme.primary;
              statusText = 'IN STOCK';
            }

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (context) => ProductLedgerSheet(product: product),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 64,
                            height: 64,
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            child: Icon(Icons.image_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 64,
                            height: 64,
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            child: Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusTextColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹$price / $unit',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStockIndicator('Phys', product.physicalStock, AppTokens.statusAssigned),
                                _buildStockIndicator('Res', product.reservedStock, AppTokens.accent),
                                _buildStockIndicator('Avail', product.availableStock, AppTokens.statusDelivered),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Tooltip(
                            message: 'Edit Product',
                            child: IconButton(
                              icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary, size: 22),
                              onPressed: () => _showEditProductBottomSheet(context, product),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Tooltip(
                            message: 'Delete Product',
                            child: IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error, size: 22),
                              onPressed: () => _confirmDeleteProduct(context, product.id, name),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStockIndicator(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _confirmDeleteProduct(BuildContext context, String productId, String name) {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Product?'),
          content: Text('Are you sure you want to remove "$name" from the active inventory catalog?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await productProvider.deleteProduct(productId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product deleted successfully.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text('DELETE', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

  // ==================== RIDERS TAB ====================
  Widget _buildRidersTab(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    return StreamBuilder<List<UserModel>>(
      stream: orderProvider.streamAllDeliveryBoys(),
      builder: (context, ridersSnapshot) {
        // Spinner only before the first data. Swapping the whole tab for a
        // spinner on every re-subscribe destroyed the search field (and its
        // focus) after each keystroke.
        if (ridersSnapshot.connectionState == ConnectionState.waiting && !ridersSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTokens.primary));
        }

        final allRiders = ridersSnapshot.data ?? [];

        return StreamBuilder<List<ord.Order>>(
          stream: orderProvider.streamAllOrders(),
          builder: (context, ordersSnapshot) {
            final orders = ordersSnapshot.data ?? [];

            // Calculate metrics
            final totalRiders = allRiders.length;
            // "Online" = enabled by admin AND on duty (the rider's own switch);
            // only those receive order broadcasts.
            final activeRidersCount = allRiders.where((r) => r.isActive && r.onDuty).length;
            final totalActiveLoad = orders.where((o) =>
                o.deliveryBoyId != null &&
                o.deliveryBoyId!.isNotEmpty &&
                o.status != 'delivered' &&
                o.status != 'cancelled'
            ).length;

            // Generate dynamic village list from whitelisted riders
            final villagesSet = allRiders.map((r) => r.village.trim()).toSet();
            final villagesList = ['All', ...villagesSet];

            // Filter riders by search query and village
            var filteredRiders = allRiders;
            if (_selectedRiderVillage != 'All') {
              filteredRiders = filteredRiders.where((r) =>
                  r.village.trim().toLowerCase() == _selectedRiderVillage.trim().toLowerCase()
              ).toList();
            }

            if (_riderSearchQuery.isNotEmpty) {
              final query = _riderSearchQuery.toLowerCase();
              filteredRiders = filteredRiders.where((r) =>
                  r.name.toLowerCase().contains(query) ||
                  r.phone.toLowerCase().contains(query) ||
                  r.email.toLowerCase().contains(query) ||
                  (r.vehicleNo ?? '').toLowerCase().contains(query) ||
                  (r.licenseNo ?? '').toLowerCase().contains(query)
              ).toList();
            }

            // Create stats dashboard card banner
            final statsDashboard = _buildRiderStatsDashboard(
              total: totalRiders,
              active: activeRidersCount,
              load: totalActiveLoad,
            );

            // Add Search and Filter Controls
            final filterControls = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, phone, or vehicle...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _riderSearchQuery.isNotEmpty
                          ? Tooltip(
                              message: 'Clear Search',
                              child: IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () => setState(() => _riderSearchQuery = ''),
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTokens.rMd),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) => setState(() => _riderSearchQuery = val),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: villagesList.contains(_selectedRiderVillage) ? _selectedRiderVillage : 'All',
                          items: villagesList.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                          onChanged: (val) => setState(() => _selectedRiderVillage = val ?? 'All'),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            labelText: 'Village Filter',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showAddRiderBottomSheet(context),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Add Rider'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            if (allRiders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline_rounded, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                    const SizedBox(height: 16),
                    Text(
                      'No whitelisted delivery partners',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddRiderBottomSheet(context),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Whitelist Rider'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTokens.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                statsDashboard,
                filterControls,
                Expanded(
                  child: filteredRiders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: Theme.of(context).colorScheme.outlineVariant),
                              const SizedBox(height: 12),
                              Text(
                                'No riders matching current filters.',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                          itemCount: filteredRiders.length,
                          itemBuilder: (context, index) {
                            final rider = filteredRiders[index];
                            final rId = rider.docId ?? rider.uid;
                            final activeCount = orders.where((o) =>
                                o.deliveryBoyId == rId &&
                                o.status != 'delivered' &&
                                o.status != 'cancelled'
                            ).length;

                            return _buildRiderCard(context, rider, activeCount, orderProvider);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRiderStatsDashboard({
    required int total,
    required int active,
    required int load,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildRiderStatCard(
              title: 'Whitelisted',
              value: '$total',
              icon: Icons.people_alt_rounded,
              color: AppTokens.statusAssigned,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildRiderStatCard(
              title: 'On Duty',
              value: '$active',
              icon: Icons.check_circle_outline_rounded,
              color: AppTokens.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildRiderStatCard(
              title: 'Active Load',
              value: '$load',
              icon: Icons.delivery_dining_rounded,
              color: AppTokens.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiderStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRiderCard(
    BuildContext context,
    UserModel rider,
    int activeCount,
    OrderProvider orderProvider,
  ) {
    final cs = Theme.of(context).colorScheme;
    // Account state first (admin-controlled), then the rider's own duty switch
    // — the latter is what decides who receives order broadcasts.
    final dutyLabel = !rider.isActive ? 'DISABLED' : (rider.onDuty ? 'ON DUTY' : 'OFF DUTY');
    final dutyColor = !rider.isActive
        ? cs.error
        : (rider.onDuty ? AppTokens.statusDelivered : cs.onSurfaceVariant);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        // Tap → the full rider page (profile, current assignments, history).
        // Long-press keeps the old quick-look sheet.
        onTap: () => Navigator.pushNamed(
          context,
          RouteGenerator.adminRiderDetail,
          arguments: rider.docId ?? rider.uid,
        ),
        onLongPress: () => _showRiderDetailSheet(context, rider, activeCount),
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTokens.accent.withValues(alpha: 0.1),
                    child: Icon(Icons.delivery_dining_rounded, color: AppTokens.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rider.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                rider.village,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: dutyColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppTokens.rSm),
                            ),
                            child: Text(
                              dutyLabel,
                              style: TextStyle(
                                color: dutyColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.phone_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                rider.phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.email_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                rider.email,
                                style: Theme.of(context).textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text('Active Load: ', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: activeCount > 2
                                  ? Theme.of(context).colorScheme.errorContainer
                                  : activeCount > 0
                                      ? AppTokens.accent.withValues(alpha: 0.1)
                                      : AppTokens.statusDelivered.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$activeCount',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: activeCount > 2
                                    ? Theme.of(context).colorScheme.error
                                    : activeCount > 0
                                        ? AppTokens.accent
                                        : AppTokens.statusDelivered,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (activeCount > 0)
                        SizedBox(
                          width: 80,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (activeCount / 3).clamp(0.0, 1.0),
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                              color: activeCount > 2
                                  ? Theme.of(context).colorScheme.error
                                  : activeCount > 0
                                      ? AppTokens.accent
                                      : AppTokens.statusDelivered,
                              minHeight: 4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if ((rider.vehicleNo != null && rider.vehicleNo!.isNotEmpty) ||
                  (rider.licenseNo != null && rider.licenseNo!.isNotEmpty)) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTokens.rSm),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (rider.vehicleNo != null && rider.vehicleNo!.isNotEmpty) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_bike_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Vehicle: ${rider.vehicleNo}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (rider.licenseNo != null && rider.licenseNo!.isNotEmpty) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.badge_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Licence: ${rider.licenseNo}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (context) => EditRiderSheet(rider: rider),
                      );
                    },
                    tooltip: 'Edit Rider',
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
                    onPressed: () => _confirmDeleteRider(context, orderProvider, rider),
                    tooltip: 'Delete Rider',
                  ),
                  const SizedBox(width: 8),
                  Text('Enabled', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 4),
                  Switch(
                    value: rider.isActive,
                    activeThumbColor: AppTokens.primary,
                    onChanged: (val) async {
                      await orderProvider.updateDeliveryBoyActiveStatus(rider.docId ?? rider.uid, val);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRiderDetailSheet(BuildContext context, UserModel rider, int activeCount) {
    final dutyLabel = !rider.isActive ? 'DISABLED' : (rider.onDuty ? 'ON DUTY' : 'OFF DUTY');
    final dutyColor = !rider.isActive
        ? Theme.of(context).colorScheme.error
        : (rider.onDuty ? AppTokens.statusDelivered : Theme.of(context).colorScheme.onSurfaceVariant);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTokens.accent.withValues(alpha: 0.1),
                    child: Icon(Icons.delivery_dining_rounded, size: 36, color: AppTokens.accent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rider.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: dutyColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                dutyLabel,
                                style: TextStyle(
                                  color: dutyColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                rider.village,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Rider Profile & Asset Details',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.phone_outlined, 'Phone Number', rider.phone),
              _buildDetailRow(Icons.email_outlined, 'Email Address', rider.email),
              _buildDetailRow(
                Icons.directions_bike_rounded,
                'Vehicle Registration Number',
                rider.vehicleNo != null && rider.vehicleNo!.isNotEmpty ? rider.vehicleNo! : 'Not Provided'
              ),
              _buildDetailRow(
                Icons.badge_outlined,
                'Driving Licence Number',
                rider.licenseNo != null && rider.licenseNo!.isNotEmpty ? rider.licenseNo! : 'Not Provided'
              ),
              _buildDetailRow(
                Icons.link_rounded,
                'Login Account',
                'Linked (UID: ${rider.uid})',
                valColor: AppTokens.statusDelivered,
              ),
              _buildDetailRow(Icons.calendar_today_outlined, 'Registration Date',
                  '${rider.createdAt.day}/${rider.createdAt.month}/${rider.createdAt.year}'),
              const SizedBox(height: 16),
              Text(
                'Active Workload',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTokens.rMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      activeCount > 0 ? Icons.inventory_2 : Icons.check_circle_outline,
                      color: activeCount > 2 ? Theme.of(context).colorScheme.error : activeCount > 0 ? AppTokens.accent : AppTokens.statusDelivered,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeCount == 0
                                ? 'No Active Deliveries'
                                : '$activeCount Active Orders Assigned',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activeCount > 2
                                ? 'Partner is carrying several orders right now.'
                                : activeCount > 0
                                    ? 'Partner is busy but can take short deliveries.'
                                    : 'Partner is available to receive new orders.',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.inverseSurface,
                  foregroundColor: Theme.of(context).colorScheme.onInverseSurface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('CLOSE PROFILE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valColor ?? Theme.of(context).colorScheme.onSurface,
                  )
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _hasActiveDeliveries(OrderProvider provider, String riderId) async {
    try {
      final orders = await provider.streamAllOrders().first;
      return orders.any((order) =>
          order.deliveryBoyId == riderId &&
          order.status != 'delivered' &&
          order.status != 'cancelled');
    } catch (e) {
      debugPrint("Error checking active deliveries: $e");
      return false;
    }
  }

  void _confirmDeleteRider(BuildContext context, OrderProvider provider, UserModel rider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Rider?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently remove',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              rider.name,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            const Text(
              'from the Rider Whitelist. This action cannot be undone.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog first
              
              final riderId = rider.docId ?? rider.uid;
              
              // 1. Check active deliveries first
              final hasActive = await _hasActiveDeliveries(provider, riderId);
              if (!context.mounted) return;

              if (hasActive) {
                showDialog(
                  context: context,
                  builder: (warnContext) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                        SizedBox(width: 8),
                        // Expanded: the bare Text overflowed the dialog title.
                        Expanded(child: Text('Active deliveries in progress')),
                      ],
                    ),
                    content: Text(
                      '${rider.name} currently has active deliveries assigned.\n\n'
                      'Let them finish, or open the Orders tab → Manage order → '
                      '"Return to rider pool" to reassign them, then delete this rider.',
                      style: const TextStyle(height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(warnContext),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                return;
              }

              // 2. Perform deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleting rider...'), duration: Duration(seconds: 1)),
              );

              try {
                await provider.deleteRider(riderId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${rider.name} deleted successfully.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(userMessageFor(e, fallback: "Couldn't delete the rider. Please try again.")),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('DELETE RIDER', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    ColorScheme? scheme,
  }) {
    return MetricCard(
      title: title,
      value: value,
      icon: icon,
      baseColor: color,
    );
  }

  Widget _buildOperationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
