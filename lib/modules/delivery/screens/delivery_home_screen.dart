import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/skeleton.dart';
import '../../../core/design/widgets/status_chip.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../domain/entities/order.dart';
import '../../../core/models/user_model.dart';
import '../../profile/screens/user_profile_screen.dart';
import 'rider_map_screen.dart';
import 'earnings_screen.dart';
import 'task_detail_screen.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  int _currentIndex = 0;

  // Blinkit-style "Reject" is a pure local dismiss — no backend call, no
  // persisted state. An offer reappearing here on the next broadcast retry
  // (see escalateStaleOrders) is correct behavior, not a bug.
  final Set<String> _dismissedOfferIds = {};

  @override
  Widget build(BuildContext context) {
    // authProvider stays listening: user.onDuty drives the duty Switch and
    // gates the incoming-offers section, and must reflect reloadUserProfile()
    // after toggling. orderProvider only starts streams / makes action calls
    // below — its own notifyListeners() (fired app-wide, other personas
    // included) doesn't need to rebuild this screen.
    final authProvider = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = authProvider.currentUserModel;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(
        body: EmptyState(
            icon: Icons.person_off_outlined, title: 'Authentication error'),
      );
    }

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildTasksTab(context, user, orderProvider, authProvider, scheme),
          const RiderMapScreen(isEmbedded: true),
          const EarningsScreen(isEmbedded: true),
          const UserProfileScreen(isEmbedded: true),
        ],
      ),
      bottomNavigationBar: _buildFloatingNavBar(scheme),
    );
  }

  Widget _buildTasksTab(
      BuildContext context,
      UserModel user,
      OrderProvider orderProvider,
      AuthProvider authProvider,
      ColorScheme scheme) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text('Partner Panel',
              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
          Text(
            'Rider: ${user.name}',
            style: TextStyle(
                fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.normal),
          ),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: scheme.onSurfaceVariant),
            tooltip: 'Log out',
            onPressed: () async => authProvider.logout(),
          ),
        ],
      ),
      body: _buildTasksBody(context, user, orderProvider, scheme),
    );
  }

  Widget _buildActionPanel(BuildContext context, UserModel user,
      OrderProvider orderProvider, ColorScheme scheme) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.delivery_dining_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Region: ${user.village}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    user.onDuty ? 'On duty' : 'Off duty',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: user.onDuty ? Colors.green.shade700 : Colors.grey,
                    ),
                  ),
                  Switch(
                    value: user.onDuty,
                    activeColor: Colors.green,
                    onChanged: (val) async {
                      await orderProvider.updateDeliveryBoyDutyStatus(user.uid, val);
                      if (context.mounted) {
                        await Provider.of<AuthProvider>(context, listen: false).reloadUserProfile();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Live Map Button
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentIndex = 1;
                    });
                  },
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rSm),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.green.shade50.withValues(alpha: 0.2),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Column(
                        children: [
                          Icon(Icons.map_rounded, color: Colors.green, size: 24),
                          SizedBox(height: 4),
                          Text(
                            'Live Map',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Earnings Button
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentIndex = 2;
                    });
                  },
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rSm),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.blue.shade50.withValues(alpha: 0.2),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Column(
                        children: [
                          Icon(Icons.currency_rupee_rounded, color: Colors.blue, size: 24),
                          SizedBox(height: 4),
                          Text(
                            'Earnings',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Profile Button
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentIndex = 3;
                    });
                  },
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rSm),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.orange.shade50.withValues(alpha: 0.2),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Column(
                        children: [
                          Icon(Icons.person_rounded, color: Colors.orange, size: 24),
                          SizedBox(height: 4),
                          Text(
                            'Profile',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTasksBody(BuildContext context, UserModel user,
      OrderProvider orderProvider, ColorScheme scheme) {
    return StreamBuilder<List<Order>>(
      stream: orderProvider.streamDeliveryBoyOrders(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: SkeletonList());
        }
        final allOrders = snapshot.data ?? [];
        final activeOrders = allOrders
            .where((o) => o.status != 'delivered' && o.status != 'cancelled')
            .toList();
        final completedOrders = allOrders
            .where((o) => o.status == 'delivered' || o.status == 'cancelled')
            .toList();

        return Column(
          children: [
            _buildActionPanel(context, user, orderProvider, scheme),
            _buildIncomingOffersSection(context, user, orderProvider, scheme),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(children: [
                  TabBar(
                    indicatorColor: scheme.primary,
                    labelColor: scheme.primary,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    labelStyle:
                        const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: const [Tab(text: 'Active Tasks'), Tab(text: 'Completed Runs')],
                  ),
                  Expanded(
                    child: TabBarView(children: [
                      _buildActiveList(context, activeOrders, orderProvider, scheme),
                      _buildCompletedList(completedOrders, scheme),
                    ]),
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Blinkit-style incoming-order broadcast feed — any pending, unassigned
  /// order any on-duty rider can accept. Only shown while on duty; village
  /// match is a display hint only, never a hard filter (see acceptOrder CF
  /// and firestore.rules — any on-duty rider may accept any pending order).
  Widget _buildIncomingOffersSection(BuildContext context, UserModel user,
      OrderProvider orderProvider, ColorScheme scheme) {
    if (!user.onDuty) return const SizedBox.shrink();

    return StreamBuilder<List<Order>>(
      stream: orderProvider.streamIncomingOffers(),
      builder: (context, snapshot) {
        final offers = (snapshot.data ?? [])
            .where((o) => !_dismissedOfferIds.contains(o.id))
            .toList()
          ..sort((a, b) {
            final aLocal =
                a.village.trim().toLowerCase() == user.village.trim().toLowerCase();
            final bLocal =
                b.village.trim().toLowerCase() == user.village.trim().toLowerCase();
            if (aLocal != bLocal) return aLocal ? -1 : 1;
            return a.createdAt.compareTo(b.createdAt);
          });

        if (offers.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.only(top: AppTokens.s12, bottom: AppTokens.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
                child: Text(
                  'Incoming Offers',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.s8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
                  itemCount: offers.length,
                  itemBuilder: (context, index) => _buildOfferCard(
                      context, offers[index], orderProvider, user, scheme),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfferCard(BuildContext context, Order order,
      OrderProvider orderProvider, UserModel user, ColorScheme scheme) {
    final isLocal =
        order.village.trim().toLowerCase() == user.village.trim().toLowerCase();
    bool isAccepting = false;

    return StatefulBuilder(
      builder: (context, setCardState) {
        return Container(
          width: 240,
          margin: const EdgeInsets.only(right: AppTokens.s12),
          padding: const EdgeInsets.all(AppTokens.s12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isLocal ? AppTokens.statusDelivered : AppTokens.statusAssigned)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTokens.rPill),
                    ),
                    child: Text(
                      isLocal ? 'Local' : 'Wide search',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isLocal ? AppTokens.statusDelivered : AppTokens.statusAssigned,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text('${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                ],
              ),
              const SizedBox(height: AppTokens.s8),
              Text(order.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(order.village,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const Spacer(),
              Text('₹${order.totalAmount.toStringAsFixed(2)} (COD)',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15, color: scheme.primary)),
              const SizedBox(height: AppTokens.s8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isAccepting
                          ? null
                          : () => setState(() => _dismissedOfferIds.add(order.id)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Reject', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: AppTokens.s8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isAccepting
                          ? null
                          : () async {
                              setCardState(() => isAccepting = true);
                              final error = await orderProvider.acceptOrder(order.id);
                              if (!context.mounted) return;
                              if (error != null) {
                                setCardState(() => isAccepting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(error),
                                    backgroundColor: AppTokens.statusCancelled,
                                  ),
                                );
                              }
                              // On success the order drops off streamIncomingOffers
                              // on its own (deliveryBoyId is now set) — no local
                              // state change needed here.
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: isAccepting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveList(BuildContext context, List<Order> orders,
      OrderProvider orderProvider, ColorScheme scheme) {
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'All caught up!',
        message: 'No active tasks right now.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s16, AppTokens.s16, 100),
      itemCount: orders.length,
      itemBuilder: (context, i) =>
          _buildActiveTaskCard(context, orders[i], orderProvider, scheme),
    );
  }

  Widget _buildActiveTaskCard(BuildContext context, Order order,
      OrderProvider orderProvider, ColorScheme scheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.s16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TaskDetailScreen(order: order)),
          );
        },
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Order #${order.id.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                StatusChip(status: order.status),
              ]),
              const Divider(height: AppTokens.s24),
              _InfoRow(
                  icon: Icons.person_rounded,
                  iconColor: scheme.onSurfaceVariant,
                  child: Text(order.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              const SizedBox(height: AppTokens.s8),
              _InfoRow(
                  icon: Icons.location_on_rounded,
                  iconColor: scheme.onSurfaceVariant,
                  child: Expanded(
                    child: Text('${order.deliveryAddress}, ${order.village}',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  )),
              const SizedBox(height: AppTokens.s12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.s12, vertical: AppTokens.s8),
                decoration: BoxDecoration(
                  color: AppTokens.statusDelivered.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTokens.rSm),
                  border: Border.all(
                      color: AppTokens.statusDelivered.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.currency_rupee_rounded,
                      size: 16, color: AppTokens.statusDelivered),
                  const SizedBox(width: AppTokens.s4),
                  Text('Collect ₹${order.totalAmount.toStringAsFixed(2)} (COD)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTokens.statusDelivered,
                          fontSize: 14)),
                ]),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TaskDetailScreen(order: order)),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('VIEW TASK DETAILS', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rSm)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedList(List<Order> orders, ColorScheme scheme) {
    if (orders.isEmpty) {
      return const EmptyState(icon: Icons.history_rounded, title: 'No runs completed yet');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s16, AppTokens.s16, 100),
      itemCount: orders.length,
      itemBuilder: (_, i) {
        final o = orders[i];
        final ok = o.status == 'delivered';
        return Card(
          margin: const EdgeInsets.only(bottom: AppTokens.s12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s16, vertical: AppTokens.s4),
            leading: CircleAvatar(
              backgroundColor: ok
                  ? AppTokens.statusDelivered.withValues(alpha: 0.12)
                  : AppTokens.statusCancelled.withValues(alpha: 0.12),
              child: Icon(
                ok ? Icons.check_rounded : Icons.close_rounded,
                color: ok ? AppTokens.statusDelivered : AppTokens.statusCancelled,
                size: 20,
              ),
            ),
            title: Text('Order #${o.id.substring(0, 6).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${o.customerName} • ₹${o.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            trailing: StatusChip(status: o.status),
          ),
        );
      },
    );
  }

  Widget _buildFloatingNavBar(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      height: 72,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.assignment_rounded, 'Tasks', scheme),
          _buildNavItem(1, Icons.map_rounded, 'Map', scheme),
          _buildNavItem(2, Icons.currency_rupee_rounded, 'Earnings', scheme),
          _buildNavItem(3, Icons.person_rounded, 'Profile', scheme),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, ColorScheme scheme) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: isActive
                    ? scheme.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isActive ? scheme.primary : scheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _InfoRow(
      {required this.icon, required this.iconColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: iconColor),
      const SizedBox(width: AppTokens.s8),
      child,
    ]);
  }
}
