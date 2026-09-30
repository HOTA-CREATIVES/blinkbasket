import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/biometric_reveal.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/skeleton.dart';
import '../../../core/design/widgets/status_chip.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/product_provider.dart';
import '../../../domain/entities/order.dart';
import '../../../core/utils/reorder_helper.dart';
import '../../../core/utils/route_generator.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Non-listening: the order list's own reactivity comes from the
    // StreamBuilder below, not from these providers' notifyListeners().
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = authProvider.currentUserModel;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: user == null
          ? const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Please log in to view orders',
            )
          : StreamBuilder<List<Order>>(
              stream: orderProvider.streamCustomerOrders(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const SkeletonList();
                }
                if (snapshot.hasError) {
                  return const EmptyState.error();
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No orders yet',
                    message: 'Start shopping to see your orders here.',
                    actionLabel: 'Browse Products',
                    onAction: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  );
                }

                final orders = snapshot.data!;

                return ListView.separated(
                  padding: const EdgeInsets.all(AppTokens.s16),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTokens.s12),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final isActive = order.status != 'delivered' &&
                        order.status != 'cancelled';

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            RouteGenerator.orderTracking,
                            arguments: order.id,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Order #${order.id.substring(0, 6).toUpperCase()}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15),
                                  ),
                                  StatusChip(status: order.status),
                                ],
                              ),
                              const SizedBox(height: AppTokens.s8),
                              Text(
                                '${order.items.length} item(s) • ₹${order.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Placed on ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} at ${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12),
                              ),
                              if (isActive) ...[
                                const SizedBox(height: AppTokens.s12),
                                _DeliveryOtpBadge(orderId: order.id),
                              ],
                              const SizedBox(height: AppTokens.s12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Track Order',
                                        style: TextStyle(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13),
                                      ),
                                      const SizedBox(width: AppTokens.s4),
                                      Icon(Icons.arrow_forward_ios_rounded,
                                          size: 12, color: scheme.primary),
                                    ],
                                  ),
                                  if (order.status == 'delivered')
                                    _ReorderButton(items: order.items),
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
            ),
    );
  }
}

/// Shows the delivery OTP for an active order. The OTP lives in a private
/// subdocument only the ordering customer can read (enforced by rules).
class _DeliveryOtpBadge extends StatefulWidget {
  final String orderId;
  const _DeliveryOtpBadge({required this.orderId});

  @override
  State<_DeliveryOtpBadge> createState() => _DeliveryOtpBadgeState();
}

class _DeliveryOtpBadgeState extends State<_DeliveryOtpBadge> {
  late final Future<String?> _otpFuture;

  @override
  void initState() {
    super.initState();
    _otpFuture = Provider.of<OrderProvider>(context, listen: false)
        .getOrderOtp(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<String?>(
      future: _otpFuture,
      builder: (context, snapshot) {
        final otp = snapshot.data;
        if (otp == null || otp.isEmpty) return const SizedBox.shrink();

        return BiometricReveal(
          reason: 'Authenticate to view the delivery OTP',
          child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s12, vertical: AppTokens.s8),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTokens.rSm),
            border:
                Border.all(color: scheme.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.vpn_key_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: AppTokens.s8),
              Text(
                'Delivery OTP: ',
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              Text(
                otp,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                  fontSize: 15,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(width: AppTokens.s4),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: otp));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('OTP copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppTokens.rSm),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.copy_all_rounded,
                      size: 16, color: scheme.primary),
                ),
              ),
            ],
          ),
        ));
      },
    );
  }
}

/// One-tap reorder for a delivered order: re-adds each item to the cart
/// using current price/stock, then offers a shortcut to the Cart tab.
class _ReorderButton extends StatefulWidget {
  final List<OrderItem> items;
  const _ReorderButton({required this.items});

  @override
  State<_ReorderButton> createState() => _ReorderButtonState();
}

class _ReorderButtonState extends State<_ReorderButton> {
  bool _isReordering = false;

  Future<void> _handleReorder() async {
    setState(() => _isReordering = true);

    try {
      final outcome = await ReorderHelper.reorderOrderItems(
        widget.items,
        Provider.of<ProductProvider>(context, listen: false).getProductById,
        Provider.of<CartProvider>(context, listen: false),
      );

      if (!mounted) return;
      setState(() => _isReordering = false);

      final message = outcome.skippedCount == 0
          ? '${outcome.addedCount} item(s) added to cart'
          : '${outcome.addedCount} item(s) added • ${outcome.skippedCount} no longer available';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: outcome.addedCount > 0
              ? SnackBarAction(
                  label: 'View Cart',
                  onPressed: () {
                    Navigator.pushNamed(context, RouteGenerator.cart);
                  },
                )
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isReordering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reorder: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: _isReordering ? null : _handleReorder,
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s8, vertical: AppTokens.s4),
        visualDensity: VisualDensity.compact,
      ),
      icon: _isReordering
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: scheme.primary),
            )
          : const Icon(Icons.replay_rounded, size: 16),
      label: const Text('Reorder',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
