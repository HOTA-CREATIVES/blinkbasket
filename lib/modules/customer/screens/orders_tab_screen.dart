import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/skeleton.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/utils/route_generator.dart';
import '../../../domain/entities/order.dart';
import 'order_history_screen.dart';
import 'order_tracking_screen.dart';

/// Embedded Orders tab in the customer navbar.
///
/// When an active/live order is in progress, this tab directly presents the
/// full live tracking interface with ETA, live status steps, map pin,
/// delivery OTP, and rider contact options.
///
/// If multiple orders are in progress, it provides an order switcher chip bar.
/// If there are no active orders, or when the user toggles "All Orders",
/// it presents the complete order history.
class OrdersTabScreen extends StatefulWidget {
  final VoidCallback onBrowse;

  const OrdersTabScreen({super.key, required this.onBrowse});

  @override
  State<OrdersTabScreen> createState() => _OrdersTabScreenState();
}

class _OrdersTabScreenState extends State<OrdersTabScreen> {
  bool _forceShowHistory = false;
  String? _selectedOrderId;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = authProvider.currentUserModel;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Please log in to view orders',
        ),
      );
    }

    return StreamBuilder<List<Order>>(
      stream: orderProvider.streamCustomerOrders(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Orders')),
            body: const SkeletonList(),
          );
        }

        final orders = snapshot.data ?? [];
        final activeOrders = orders.where((o) =>
            o.status != 'delivered' && o.status != 'cancelled').toList();

        // If the customer has manually toggled to view full history, or if there
        // are no live orders in progress, render the history screen.
        if (_forceShowHistory || activeOrders.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My Orders'),
              automaticallyImplyLeading: false,
              actions: [
                if (activeOrders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _forceShowHistory = false),
                      icon: const Icon(Icons.location_on_rounded, size: 16),
                      label: const Text('Track Live', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            body: Column(
              children: [
                if (activeOrders.isNotEmpty)
                  Material(
                    color: AppTokens.primary.withValues(alpha: 0.1),
                    child: InkWell(
                      onTap: () => setState(() => _forceShowHistory = false),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.delivery_dining_rounded,
                                color: AppTokens.primary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You have ${activeOrders.length} live order${activeOrders.length > 1 ? 's' : ''} in progress',
                                style: const TextStyle(
                                  color: AppTokens.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTokens.primary,
                                borderRadius:
                                    BorderRadius.circular(AppTokens.rPill),
                              ),
                              child: const Text(
                                'Track Live',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: OrderHistoryScreen(
                    hideAppBar: true,
                    onBrowse: widget.onBrowse,
                    onOrderTap: (selectedOrder) {
                      if (activeOrders.any((o) => o.id == selectedOrder.id)) {
                        setState(() {
                          _selectedOrderId = selectedOrder.id;
                          _forceShowHistory = false;
                        });
                      } else {
                        Navigator.pushNamed(
                          context,
                          RouteGenerator.orderTracking,
                          arguments: selectedOrder.id,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        }

        // Live Order Tracking View
        final targetOrderId = (_selectedOrderId != null &&
                activeOrders.any((o) => o.id == _selectedOrderId))
            ? _selectedOrderId!
            : activeOrders.first.id;

        return OrderTrackingScreen(
          orderId: targetOrderId,
          isEmbeddedInTab: true,
          activeOrders: activeOrders.length > 1 ? activeOrders : null,
          onSelectOrder: (id) => setState(() => _selectedOrderId = id),
          onViewAllOrders: () => setState(() => _forceShowHistory = true),
        );
      },
    );
  }
}
