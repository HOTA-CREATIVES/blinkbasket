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
import '../../../core/utils/route_generator.dart';
import '../../profile/screens/user_profile_screen.dart';
import 'rider_map_screen.dart';
import 'earnings_screen.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/money.dart';

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

  Widget _buildRiderHeaderCard(BuildContext context, UserModel user,
      OrderProvider orderProvider, ColorScheme scheme) {
    final isOnDuty = user.onDuty;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s12, AppTokens.s16, AppTokens.s4),
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16, vertical: 10.0),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(
          color: isOnDuty
              ? AppTokens.primary.withValues(alpha: 0.3)
              : scheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Flexible + Expanded below: the name/village column had no width
          // limit next to the duty switch and overflowed on long names.
          Flexible(
            child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (isOnDuty ? AppTokens.primary : scheme.onSurfaceVariant)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delivery_dining_rounded,
                  color: isOnDuty ? AppTokens.primary : scheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppTokens.primary),
                      const SizedBox(width: 2),
                      Text(
                        user.village.isNotEmpty ? user.village : 'Bhimavaram',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              ),
            ],
          ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isOnDuty ? AppTokens.statusDelivered : scheme.onSurfaceVariant)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTokens.rPill),
                ),
                child: Text(
                  isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isOnDuty ? AppTokens.statusDelivered : scheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: user.onDuty,
                activeThumbColor: AppTokens.primary,
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
    );
  }

  Widget _buildTasksBody(BuildContext context, UserModel user,
      OrderProvider orderProvider, ColorScheme scheme) {
    return StreamBuilder<List<Order>>(
      stream: orderProvider.streamDeliveryBoyOrders(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(body: SkeletonList());
        }
        if (snapshot.hasError) {
          return EmptyState.error(
            title: "Couldn't load your tasks",
            message: userMessageFor(snapshot.error),
            onAction: () => orderProvider.retryDeliveryOrders(user.uid),
          );
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
            _buildRiderHeaderCard(context, user, orderProvider, scheme),
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
        if (snapshot.hasError) return const SizedBox.shrink();

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

        // Compact vertical rows instead of a fixed-height horizontal
        // carousel: scales to any offer count without hiding extras
        // off-screen with no indication more exist, and — since this
        // section sits above a non-scrolling Expanded tab view — height
        // must stay capped regardless of how many offers arrive at once.
        // A ~2.5-row cap leaves the next row peeking as a scroll hint.
        const tileHeight = 92.0;
        const tileGap = AppTokens.s8;
        final listHeight = offers.length <= 2
            ? offers.length * tileHeight + (offers.length - 1) * tileGap
            : 2.5 * tileHeight + 2 * tileGap;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16, vertical: AppTokens.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Incoming Offers',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppTokens.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(AppTokens.rPill),
                    ),
                    child: Text(
                      '${offers.length}',
                      semanticsLabel: '${offers.length} incoming offers',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.s8),
              SizedBox(
                height: listHeight,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: offers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: tileGap),
                  itemBuilder: (context, index) => _buildOfferTile(
                      context, offers[index], orderProvider, user, scheme),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfferTile(BuildContext context, Order order,
      OrderProvider orderProvider, UserModel user, ColorScheme scheme) {
    final isLocal =
        order.village.trim().toLowerCase() == user.village.trim().toLowerCase();
    final zoneColor = isLocal ? AppTokens.statusDelivered : AppTokens.statusAssigned;
    bool isAccepting = false;

    final itemsSummary = order.items.isNotEmpty
        ? order.items.map((i) => '${i.quantity}x ${i.name}').join(', ')
        : 'No items';

    return StatefulBuilder(
      builder: (context, setTileState) {
        return Semantics(
          container: true,
          label: 'Order from ${order.customerName}, $itemsSummary, '
              '${formatRupees(order.totalAmount)} cash on delivery, '
              '${isLocal ? "local order" : "nearby zone"}',
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppTokens.rMd),
              border: Border.all(color: zoneColor.withValues(alpha: 0.35), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: scheme.onSurface.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: zoneColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(
                    isLocal ? Icons.near_me_rounded : Icons.explore_outlined,
                    size: 16,
                    color: zoneColor,
                  ),
                ),
                const SizedBox(width: AppTokens.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // Offers carry the village only (no street address).
                        [order.deliveryAddress, order.village]
                            .where((part) => part.trim().isNotEmpty)
                            .join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        itemsSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.s8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatRupees(order.totalAmount),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: scheme.primary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: 'Reject offer',
                            onPressed: isAccepting
                                ? null
                                : () => setState(() => _dismissedOfferIds.add(order.id)),
                            icon: Icon(Icons.close_rounded, size: 18, color: scheme.onSurfaceVariant),
                            style: IconButton.styleFrom(
                              backgroundColor: scheme.surfaceContainerHighest,
                              shape: const CircleBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed: isAccepting
                                ? null
                                : () async {
                                    setTileState(() => isAccepting = true);
                                    try {
                                      final error = await orderProvider.acceptOrder(order.id);
                                      if (!context.mounted) return;
                                      // Always clear the spinner here, on
                                      // success too — don't rely solely on
                                      // this tile getting removed once the
                                      // offers stream catches up, or a slow
                                      // snapshot (or the order somehow still
                                      // matching the query) leaves the rider
                                      // staring at a spinner that never ends.
                                      setTileState(() => isAccepting = false);
                                      if (error != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(error),
                                            backgroundColor: AppTokens.statusCancelled,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      setTileState(() => isAccepting = false);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(userMessageFor(e, fallback: "Couldn't accept the order. Please try again.")),
                                          backgroundColor: AppTokens.statusCancelled,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
                              minimumSize: Size.zero,
                              elevation: 0,
                            ),
                            child: isAccepting
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                                  )
                                : Text('Accept', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
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
      padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s16, AppTokens.s16, 120),
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
          Navigator.pushNamed(
            context,
            RouteGenerator.taskDetail,
            arguments: order,
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
                  Text('Collect ${formatRupees(order.totalAmount)} (COD)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTokens.statusDelivered,
                          fontSize: 14)),
                ]),
              ),
          const SizedBox(height: AppTokens.s12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      RouteGenerator.taskDetail,
                      arguments: order,
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('VIEW TASK DETAILS', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rSm)),
                    padding: const EdgeInsets.symmetric(vertical: AppTokens.s12),
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
            subtitle: Text('${o.customerName} • ${formatRupees(o.totalAmount)}',
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
            color: scheme.onSurface.withValues(alpha: 0.1),
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
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
