import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/utils/biometric_auth.dart';
import '../../../core/providers/product_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../domain/entities/product.dart' as ent;
import '../../../domain/entities/order.dart' as ord;
import '../../../domain/entities/inventory_ledger.dart';
import '../../../domain/entities/dashboard_stats.dart';
import '../../../core/models/user_model.dart';
import 'admin_profile_screen.dart';
import '../../../core/design/app_tokens.dart';
import 'add_rider_screen.dart';
import '../../../core/utils/route_generator.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isLocked = true;
  String _riderSearchQuery = '';
  String _selectedRiderVillage = 'All';


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddRiderScreen()),
    );
  }

  void _showAddProductBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _AddProductSheet(),
    );
  }

  void _showEditProductBottomSheet(BuildContext context, ent.Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddProductSheet(existing: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;

    final dashboardContent = Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? 'Admin Dashboard'
              : _currentIndex == 1
                  ? 'Order Management'
                  : _currentIndex == 2
                      ? 'Inventory Catalog'
                      : 'Delivery Partners',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminProfileScreen()),
                );
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
    final scheme = Theme.of(context).colorScheme;
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
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, height: 1.5, fontSize: 14),
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
    // The nav bar uses inverseSurface as bg, so items use onInverseSurface colors.
    const selectedColor = Colors.white;
    final unselectedColor = Colors.white.withValues(alpha: 0.55);
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
              ? Colors.white.withValues(alpha: 0.15)
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
                style: const TextStyle(
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
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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
                    value: '$activeOrders Placed',
                    icon: Icons.shopping_bag_outlined,
                    color: AppTokens.statusPending,
                    scheme: scheme,
                  ),
                  _buildMetricCard(
                    title: 'Active Riders',
                    value: '$riderCount Partners',
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
                    title: 'Catalog',
                    value: '$productCount Products',
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
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Inventory Warnings (Action Required)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 130,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: lowStock.length,
                      itemBuilder: (context, index) {
                        final product = lowStock[index];
                        return Container(
                          width: 260,
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.shade100, width: 1),
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
                                          color: Colors.grey.shade200,
                                          width: 60,
                                          height: 60,
                                          child: const Icon(Icons.image_not_supported),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey.shade200,
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${product.availableStock} left in stock',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final provider = Provider.of<ProductProvider>(context, listen: false);
                                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                        final adminId = authProvider.currentUserModel?.uid ?? 'admin_default_dev';
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
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
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
          const Text(
            'Quick Operations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildOperationCard(
                  title: 'Whitelist Rider',
                  subtitle: 'Register Google account',
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
  Widget _buildOrdersTab(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(text: 'Pending Assignment'),
              Tab(text: 'Active Runs'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOrderQueue(isPendingOnly: true),
                _buildOrderQueue(isPendingOnly: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderQueue({required bool isPendingOnly}) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    return StreamBuilder<List<ord.Order>>(
      stream: orderProvider.streamAllOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No orders found in queue.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          );
        }

        // Filter orders locally
        final allOrders = snapshot.data!;
        final filtered = allOrders.where((order) {
          final deliveryBoyId = order.deliveryBoyId ?? '';
          final status = order.status;

          if (isPendingOnly) {
            return deliveryBoyId.isEmpty && (status == 'placed' || status == 'pending');
          } else {
            return deliveryBoyId.isNotEmpty || status == 'delivered' || status == 'cancelled';
          }
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text('Queue is empty.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100),
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
                side: BorderSide(color: Colors.grey.shade200),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusBg(status),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      customerName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Destination: $village • Bill: ₹$totalAmount',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    if (riderName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.delivery_dining, size: 16, color: Colors.orange.shade800),
                          const SizedBox(width: 6),
                          Text(
                            'Rider: $riderName',
                            style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    if (isPendingOnly) ...[
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
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              (order.notifyTier ?? 1) >= 2
                                  ? 'Searching for a rider (wide search)…'
                                  : 'Searching for a nearby rider…',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusBg(String status) {
    switch (status) {
      case 'placed':
        return Colors.orange.shade50;
      case 'assigned':
        return Colors.blue.shade50;
      case 'picked_up':
        return Colors.yellow.shade100;
      case 'out_for_delivery':
        return Colors.purple.shade50;
      case 'delivered':
        return Colors.green.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'placed':
        return Colors.orange.shade700;
      case 'assigned':
        return Colors.blue.shade700;
      case 'picked_up':
        return Colors.orange.shade900;
      case 'out_for_delivery':
        return Colors.purple.shade700;
      case 'delivered':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  // ==================== INVENTORY TAB ====================
  Widget _buildInventoryTab(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    return StreamBuilder<List<ent.Product>>(
      stream: productProvider.streamProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'No products in catalog',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                ),

              ],
            ),
          );
        }

        final products = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
          itemCount: products.length,
          itemBuilder: (context, index) {
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
              statusColor = Colors.red;
              statusTextColor = Colors.red.shade800;
              statusText = 'OUT OF STOCK';
            } else if (isLowStock) {
              statusColor = Colors.orange;
              statusTextColor = Colors.orange.shade800;
              statusText = 'LOW STOCK';
            } else {
              statusColor = Colors.green;
              statusTextColor = Colors.green.shade800;
              statusText = 'IN STOCK';
            }

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (context) => _ProductLedgerSheet(product: product),
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
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.image_outlined, color: Colors.grey),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 64,
                            height: 64,
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
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
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹$price / $unit',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStockIndicator('Phys', product.physicalStock, Colors.cyan.shade800),
                                _buildStockIndicator('Res', product.reservedStock, Colors.orange.shade800),
                                _buildStockIndicator('Avail', product.availableStock, Colors.green.shade800),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: Colors.blue.shade700, size: 22),
                            onPressed: () => _showEditProductBottomSheet(context, product),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(height: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                            onPressed: () => _confirmDeleteProduct(context, product.id, name),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(height: 12),
                          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
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
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
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
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('DELETE', style: TextStyle(color: Colors.red)),
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
        if (ridersSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRiders = ridersSnapshot.data ?? [];

        return StreamBuilder<List<ord.Order>>(
          stream: orderProvider.streamAllOrders(),
          builder: (context, ordersSnapshot) {
            final orders = ordersSnapshot.data ?? [];

            // Calculate metrics
            final totalRiders = allRiders.length;
            final activeRidersCount = allRiders.where((r) => r.isActive).length;
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
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => setState(() => _riderSearchQuery = ''),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTokens.rMd),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) => setState(() => _riderSearchQuery = val),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: villagesList.contains(_selectedRiderVillage) ? _selectedRiderVillage : 'All',
                          items: villagesList.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                          onChanged: (val) => setState(() => _selectedRiderVillage = val ?? 'All'),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            labelText: 'Village Filter',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
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
                    Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text(
                      'No whitelisted delivery partners',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
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
                              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'No riders matching current filters.',
                                style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
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
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildRiderStatCard(
              title: 'Active / Online',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        border: Border.all(color: Colors.grey.shade100),
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
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
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
    final docId = rider.docId ?? rider.uid;
    final isPendingFirstLogin = (rider.uid.isEmpty || rider.uid == docId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showRiderDetailSheet(context, rider, activeCount),
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
                    backgroundColor: Colors.orange.shade50,
                    child: Icon(Icons.delivery_dining_rounded, color: Colors.orange.shade800, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rider.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              rider.village,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
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
                          color: rider.isActive
                              ? AppTokens.primary.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(AppTokens.rSm),
                        ),
                        child: Text(
                          rider.isActive ? 'ACTIVE' : 'OFFLINE',
                          style: TextStyle(
                            color: rider.isActive ? AppTokens.primary : Colors.grey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isPendingFirstLogin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTokens.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Awaiting Login',
                            style: TextStyle(
                              color: AppTokens.accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.phone_rounded, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(rider.phone, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.email_rounded, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                rider.email,
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
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
                          const Text('Active Load: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: activeCount > 2
                                  ? Colors.red.shade50
                                  : activeCount > 0
                                      ? Colors.orange.shade50
                                      : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$activeCount',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: activeCount > 2
                                    ? Colors.red
                                    : activeCount > 0
                                        ? Colors.orange.shade800
                                        : Colors.green,
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
                              backgroundColor: Colors.grey.shade100,
                              color: activeCount > 2
                                  ? Colors.red
                                  : activeCount > 0
                                      ? Colors.orange
                                      : Colors.green,
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
                    color: Colors.grey.shade50,
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
                            const Icon(Icons.directions_bike_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Vehicle: ${rider.vehicleNo}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                      if (rider.licenseNo != null && rider.licenseNo!.isNotEmpty) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.badge_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Licence: ${rider.licenseNo}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
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
                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (context) => _EditRiderSheet(rider: rider),
                      );
                    },
                    tooltip: 'Edit Rider',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    onPressed: () => _confirmDeleteRider(context, orderProvider, rider),
                    tooltip: 'Delete Rider',
                  ),
                  const SizedBox(width: 8),
                  const Text('Online', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 4),
                  Switch(
                    value: rider.isActive,
                    activeColor: Colors.green.shade700,
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
    final isPendingFirstLogin = (rider.uid.isEmpty || rider.uid == (rider.docId ?? rider.uid));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.orange.shade50,
                    child: Icon(Icons.delivery_dining_rounded, size: 36, color: Colors.orange.shade800),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rider.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: rider.isActive
                                    ? AppTokens.primary.withValues(alpha: 0.1)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                rider.isActive ? 'ACTIVE / ONLINE' : 'OFFLINE',
                                style: TextStyle(
                                  color: rider.isActive ? AppTokens.primary : Colors.grey.shade600,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                rider.village,
                                style: TextStyle(
                                  color: Colors.blue.shade800,
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
              const Text(
                'Rider Profile & Asset Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
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
                'Linked Account Authentication',
                isPendingFirstLogin
                    ? 'Awaiting First Login (Inactive UID)'
                    : 'Successfully Linked (UID: ${rider.uid})',
                valColor: isPendingFirstLogin ? AppTokens.accent : Colors.green.shade700,
              ),
              _buildDetailRow(Icons.calendar_today_outlined, 'Registration Date',
                  '${rider.createdAt.day}/${rider.createdAt.month}/${rider.createdAt.year}'),
              const SizedBox(height: 16),
              const Text(
                'Active Workload',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(AppTokens.rMd),
                ),
                child: Row(
                  children: [
                    Icon(
                      activeCount > 0 ? Icons.inventory_2 : Icons.check_circle_outline,
                      color: activeCount > 2 ? Colors.red : activeCount > 0 ? Colors.orange : Colors.green,
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
                                ? 'Partner is currently overloaded. Avoid assigning more.'
                                : activeCount > 0
                                    ? 'Partner is busy but can take short deliveries.'
                                    : 'Partner is available to receive new orders.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                  backgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white,
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
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valColor ?? Colors.black87
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent),
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
                        Text('Active Deliveries Assigned'),
                      ],
                    ),
                    content: Text(
                      '${rider.name} currently has active deliveries assigned.\n\n'
                      'Please complete or reassign those deliveries before deleting this rider.',
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
                    backgroundColor: Colors.green.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete rider: $e'),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('DELETE RIDER', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
    return _MetricCard(
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
        side: BorderSide(color: Colors.grey.shade200),
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color baseColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.baseColor,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  double _scale = 1.0;

  LinearGradient _getMetricGradient(Color baseColor) {
    if (baseColor == Colors.orange) {
      return const LinearGradient(
        colors: [Color(0xFFFF9E53), Color(0xFFE05300)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (baseColor == Colors.green) {
      return const LinearGradient(
        colors: [Color(0xFF4EE286), Color(0xFF008F39)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (baseColor == Colors.blue) {
      return const LinearGradient(
        colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (baseColor == Colors.purple) {
      return const LinearGradient(
        colors: [Color(0xFFE040FB), Color(0xFF6A1B9A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return LinearGradient(
      colors: [baseColor, baseColor.withValues(alpha: 0.8)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _scale = 0.95;
        });
      },
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
        });
      },
      onTapCancel: () {
        setState(() {
          _scale = 1.0;
        });
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            gradient: _getMetricGradient(widget.baseColor),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.baseColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 24),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditRiderSheet extends StatefulWidget {
  final UserModel rider;
  const _EditRiderSheet({required this.rider});

  @override
  State<_EditRiderSheet> createState() => _EditRiderSheetState();
}

class _EditRiderSheetState extends State<_EditRiderSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _villageController;
  late final TextEditingController _vehicleNoController;
  late final TextEditingController _licenseNoController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rider.name);
    _emailController = TextEditingController(text: widget.rider.email);
    _phoneController = TextEditingController(text: widget.rider.phone);
    _villageController = TextEditingController(text: widget.rider.village);
    _vehicleNoController = TextEditingController(text: widget.rider.vehicleNo ?? '');
    _licenseNoController = TextEditingController(text: widget.rider.licenseNo ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    _vehicleNoController.dispose();
    _licenseNoController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatVehicleNumber(String rawVehicle) {
    final cleaned = rawVehicle.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (cleaned.length < 5) return cleaned;
    
    final state = cleaned.substring(0, 2);
    final district = cleaned.substring(2, 4);
    
    // Find where the numbers at the end start
    int numIndex = cleaned.length;
    for (int i = cleaned.length - 1; i >= 4; i--) {
      final code = cleaned.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        numIndex = i;
      } else {
        break;
      }
    }
    
    final series = cleaned.substring(4, numIndex);
    final number = cleaned.substring(numIndex);
    
    return '$state $district $series $number'.trim();
  }

  String _formatLicenseNumber(String rawLicense) {
    final cleaned = rawLicense.replaceAll(RegExp(r'[\s\-/]+'), '').toUpperCase();
    if (cleaned.length != 15) return cleaned;
    
    final state = cleaned.substring(0, 2);
    final rto = cleaned.substring(2, 4);
    final year = cleaned.substring(4, 8);
    final serial = cleaned.substring(8);
    
    return '$state-$rto-$year-$serial';
  }

  Future<void> _submitEdit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final rawVehicle = _vehicleNoController.text.trim();
    final formattedVehicle = rawVehicle.isNotEmpty ? _formatVehicleNumber(rawVehicle) : '';
    final rawLicense = _licenseNoController.text.trim();
    final formattedLicense = rawLicense.isNotEmpty ? _formatLicenseNumber(rawLicense) : '';

    try {
      await orderProvider.updateRiderDetails(
        docId: widget.rider.docId ?? widget.rider.uid,
        name: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        phone: _phoneController.text.trim(),
        village: _villageController.text.trim(),
        vehicleNo: formattedVehicle,
        licenseNo: formattedLicense,
      );

      _showSnackBar('Rider updated successfully!', isError: false);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Failed to update rider: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24,
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
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Edit Delivery Partner Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Rider Full Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter rider name';
                    if (value.trim().length < 3) return 'Name must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Google Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter rider email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter phone number';
                    if (value.trim().length != 10 || int.tryParse(value.trim()) == null) {
                      return 'Enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _villageController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Assigned Region / Village',
                    prefixIcon: const Icon(Icons.map_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter assigned region';
                    if (value.trim().length < 3) return 'Region name must be at least 3 characters';
                    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                      return 'Region name can only contain letters and spaces';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _vehicleNoController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Number (Optional)',
                    prefixIcon: const Icon(Icons.directions_bike_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    hintText: 'XX NN XX XXXX (e.g. AP 39 XX 1234)',
                    helperText: 'Enter in XX NN XX XXXX format (e.g. AP 39 XX 1234).',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final cleaned = value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
                    final regExp = RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{1,4}$');
                    if (!regExp.hasMatch(cleaned)) {
                      return 'Must match format: XX NN XX XXXX (e.g., AP 39 XX 1234)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _licenseNoController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Driving Licence Number (Optional)',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    hintText: 'SS-RR-YYYY-NNNNNNN (e.g. DL-14-2011-0012345)',
                    helperText: 'Enter in SS-RR-YYYY-NNNNNNN format (e.g. DL-14-2011-0012345).',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final cleaned = value.replaceAll(RegExp(r'[\s\-/]+'), '').toUpperCase();
                    final regExp = RegExp(r'^[A-Z]{2}[0-9]{13}$');
                    if (!regExp.hasMatch(cleaned)) {
                      return 'Must match standard format (e.g., DL-14-2011-0012345)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Saving...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        )
                      : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductLedgerSheet extends StatefulWidget {
  final ent.Product product;
  const _ProductLedgerSheet({required this.product});

  @override
  State<_ProductLedgerSheet> createState() => _ProductLedgerSheetState();
}

class _ProductLedgerSheetState extends State<_ProductLedgerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _deltaController = TextEditingController();
  final _notesController = TextEditingController();
  String _changeType = 'restock';
  bool _isSubmitting = false;

  final List<Map<String, String>> _reasons = [
    {'value': 'restock', 'label': 'Restock (Add Stock)'},
    {'value': 'spoilage', 'label': 'Damage / Spoilage (Reduce Stock)'},
    {'value': 'adjustment', 'label': 'Inventory Correction (Manual Change)'},
  ];

  @override
  void dispose() {
    _deltaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;

    final rawDelta = int.parse(_deltaController.text.trim());
    int physicalDelta = rawDelta;
    if (_changeType == 'spoilage') {
      physicalDelta = -rawDelta.abs();
    } else if (_changeType == 'adjustment') {
      physicalDelta = rawDelta;
    } else {
      physicalDelta = rawDelta.abs();
    }

    setState(() {
      _isSubmitting = true;
    });

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminId = authProvider.currentUserModel?.uid ?? 'admin_default_dev';

    try {
      final success = await productProvider.adjustStock(
        productId: widget.product.id,
        physicalDelta: physicalDelta,
        reservedDelta: 0,
        changeType: _changeType,
        notes: _notesController.text.trim(),
        adminId: adminId,
      );

      if (success) {
        _showSnackBar('Stock adjusted successfully and logged!', isError: false);
        if (mounted) {
          _deltaController.clear();
          _notesController.clear();
          setState(() {
            _isSubmitting = false;
          });
        }
      } else {
        _showSnackBar('Failed to adjust stock: ${productProvider.errorMessage}');
        setState(() {
          _isSubmitting = false;
        });
      }
    } catch (e) {
      _showSnackBar('Error adjusting stock: $e');
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.product.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                widget.product.category,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPillCard(
                    title: 'Physical',
                    value: '${widget.product.physicalStock}',
                    color: Colors.cyan.shade700,
                    bgColor: Colors.cyan.shade50,
                  ),
                  _buildPillCard(
                    title: 'Reserved',
                    value: '${widget.product.reservedStock}',
                    color: Colors.orange.shade800,
                    bgColor: Colors.orange.shade50,
                  ),
                  _buildPillCard(
                    title: 'Available',
                    value: '${widget.product.availableStock}',
                    color: Colors.green.shade700,
                    bgColor: Colors.green.shade50,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'New Adjustment Entry',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _changeType,
                      decoration: InputDecoration(
                        labelText: 'Adjustment Reason',
                        prefixIcon: const Icon(Icons.assignment_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _reasons.map((r) {
                        return DropdownMenuItem(value: r['value'], child: Text(r['label']!));
                      }).toList(),
                      onChanged: _isSubmitting ? null : (val) {
                        if (val != null) {
                          setState(() {
                            _changeType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _deltaController,
                            enabled: !_isSubmitting,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Quantity Change',
                              prefixIcon: const Icon(Icons.exposure),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Enter quantity';
                              final val = int.tryParse(value.trim());
                              if (val == null) return 'Invalid number';
                              if (val == 0) return 'Cannot be 0';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Audit Memo / Notes',
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter note/reason' : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitAdjustment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Saving Ledger Entry...'),
                              ],
                            )
                          : const Text('SUBMIT ADJUSTMENT', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Text(
                'Audit Ledger Logs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              StreamBuilder<List<InventoryLedger>>(
                stream: productProvider.streamInventoryLogs(widget.product.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No audit transactions recorded yet.',
                        style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final logs = snapshot.data!;
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return _buildLedgerTimelineTile(log);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillCard({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTimelineTile(InventoryLedger log) {
    IconData icon;
    Color color;
    String prefix = "";

    switch (log.changeType) {
      case 'restock':
        icon = Icons.add_business_rounded;
        color = Colors.green;
        prefix = "+${log.physicalDelta}";
        break;
      case 'sale':
        icon = Icons.shopping_bag_outlined;
        color = Colors.blue;
        prefix = "${log.physicalDelta}";
        break;
      case 'spoilage':
        icon = Icons.delete_outline;
        color = Colors.red;
        prefix = "${log.physicalDelta}";
        break;
      default:
        icon = Icons.tune;
        color = Colors.orange;
        prefix = log.physicalDelta >= 0 ? "+${log.physicalDelta}" : "${log.physicalDelta}";
    }

    final formattedTime = "${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year} ${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      log.changeType.toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                    ),
                    Text(
                      prefix,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(log.notes, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  "$formattedTime • User: ${log.adminId}",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddProductSheet extends StatefulWidget {
  final ent.Product? existing;

  const _AddProductSheet({this.existing});

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.existing?.name);
  late final _descriptionController = TextEditingController(text: widget.existing?.description);
  late final _priceController = TextEditingController(text: widget.existing?.price.toString());
  late final _unitController = TextEditingController(text: widget.existing?.unit);
  late final _stockController = TextEditingController(text: widget.existing?.physicalStock.toString());
  late final _thresholdController =
      TextEditingController(text: (widget.existing?.lowStockThreshold ?? 10).toString());

  late String _selectedCategory = widget.existing?.category ?? 'Fruits & Vegetables';
  late bool _requiresPrescription = widget.existing?.requiresPrescription ?? false;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  final List<String> _categories = [
    'Fruits & Vegetables',
    'Dairy & Eggs',
    'Medicines',
    'Bakery',
    'Snacks',
    'Beverages',
    'Household',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e');
    }
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    String? imageUrl;

    try {
      if (_imageFile != null) {
        final cloudinary = CloudinaryService();
        imageUrl = await cloudinary.uploadImage(_imageFile!);
        if (imageUrl == null) {
          throw Exception('Image upload failed.');
        }
      } else if (_isEditing) {
        imageUrl = widget.existing!.imageUrl;
      } else {
        imageUrl = 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500&auto=format&fit=crop';
      }

      final price = double.parse(_priceController.text.trim());
      final threshold = int.parse(_thresholdController.text.trim());
      // Stock is only settable at creation here; once a product exists, stock
      // corrections must go through the ledger-tracked adjustStock flow
      // (_ProductLedgerSheet) so every change is auditable.
      final physicalStock = _isEditing ? widget.existing!.physicalStock : int.parse(_stockController.text.trim());
      final reservedStock = _isEditing ? widget.existing!.reservedStock : 0;
      final availableStock = physicalStock - reservedStock;

      final product = ent.Product(
        id: widget.existing?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        imageUrl: imageUrl,
        category: _selectedCategory,
        stock: availableStock,
        unit: _unitController.text.trim(),
        requiresPrescription: _requiresPrescription,
        physicalStock: physicalStock,
        reservedStock: reservedStock,
        availableStock: availableStock,
        lowStockThreshold: threshold,
      );

      final success = _isEditing ? await productProvider.updateProduct(product) : await productProvider.addProduct(product);
      if (success) {
        _showSnackBar(_isEditing ? 'Product updated successfully!' : 'Product added to catalog successfully!', isError: false);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        _showSnackBar('Failed to save product: ${productProvider.errorMessage}');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isEditing ? 'Edit Product' : 'Add New Product',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                GestureDetector(
                  onTap: _isSubmitting ? null : _pickImage,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
                          )
                        : (_isEditing && widget.existing!.imageUrl.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: widget.existing!.imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Tap to upload product photo', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Product Name',
                    prefixIcon: const Icon(Icons.shopping_bag_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter product name' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSubmitting,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter description' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        enabled: !_isSubmitting,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Price (₹)',
                          prefixIcon: const Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter price';
                          final p = double.tryParse(val.trim());
                          if (p == null || p <= 0) return 'Invalid price';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        enabled: !_isSubmitting,
                        decoration: InputDecoration(
                          hintText: 'e.g., 1 kg, 500 g, 1 pc',
                          labelText: 'Unit Size',
                          prefixIcon: const Icon(Icons.scale_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Enter unit size' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        enabled: !_isSubmitting && !_isEditing,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Initial Stock',
                          helperText: _isEditing ? 'Use the ledger view to adjust stock' : null,
                          prefixIcon: const Icon(Icons.inventory_2_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter stock';
                          final s = int.tryParse(val.trim());
                          if (s == null || s < 0) return 'Invalid stock';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _thresholdController,
                        enabled: !_isSubmitting,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Low Stock Threshold',
                          prefixIcon: const Icon(Icons.warning_amber_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter threshold';
                          final s = int.tryParse(val.trim());
                          if (s == null || s < 0) return 'Invalid value';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: _isSubmitting ? null : (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                        if (_selectedCategory != 'Medicines') {
                          _requiresPrescription = false;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                if (_selectedCategory == 'Medicines') ...[
                  SwitchListTile(
                    title: const Text('Requires Prescription', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Requires customer prescription upload on order placement'),
                    value: _requiresPrescription,
                    activeColor: Colors.blue.shade800,
                    contentPadding: EdgeInsets.zero,
                    onChanged: _isSubmitting ? null : (val) {
                      setState(() {
                        _requiresPrescription = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Uploading & Saving...'),
                          ],
                        )
                      : Text(_isEditing ? 'SAVE CHANGES' : 'CREATE PRODUCT', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

