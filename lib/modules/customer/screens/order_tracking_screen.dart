import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/delivery_otp_card.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/leaflet_location_picker.dart';
import '../../../core/design/widgets/skeleton.dart';
import '../../../core/design/widgets/status_chip.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/utils/reorder_helper.dart';
import '../../../core/providers/product_provider.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/route_generator.dart';
import '../../../domain/entities/app_config.dart';
import '../../../domain/entities/order.dart';
import '../../../core/utils/app_exception.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  int _getStatusStep(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'assigned':
        return 1;
      case 'picked_up':
        return 2;
      case 'out_for_delivery':
        return 3;
      case 'delivered':
        return 4;
      case 'cancelled':
        return -1;
      default:
        return 0;
    }
  }

  /// Calls or WhatsApps the rider, and says so when it can't be done — a
  /// button that silently does nothing looks broken.
  Future<void> _contactRider(BuildContext context, Order order,
      {required bool whatsApp}) async {
    final messenger = ScaffoldMessenger.of(context);
    final launcher = ContactLauncher();
    final shortId = order.id.substring(0, 6).toUpperCase();
    final result = whatsApp
        ? await launcher.whatsApp(
            order.deliveryBoyPhone,
            message: 'Hi, this is ${order.customerName} about order #$shortId.',
          )
        : await launcher.call(order.deliveryBoyPhone);
    final problem = ContactLauncher.messageFor(result, what: whatsApp ? 'WhatsApp' : 'the phone app');
    if (problem != null) messenger.showSnackBar(SnackBar(content: Text(problem)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded),
            tooltip: 'Get Help for this Order',
            onPressed: () {
              Navigator.pushNamed(
                context,
                RouteGenerator.customerSupport,
                arguments: orderId,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<Order>(
        stream: Provider.of<OrderProvider>(context, listen: false).streamOrder(orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const SkeletonList();
          }
          final error = snapshot.error;
          if (error is AppException && error.code == 'not-found') {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Order not found',
              message: 'This order no longer exists.',
            );
          }
          if (error != null || !snapshot.hasData) {
            return EmptyState.error(
              title: "Couldn't load this order",
              message: userMessageFor(error),
              onAction: () => Provider.of<OrderProvider>(context, listen: false)
                  .retryOrder(orderId),
            );
          }

          final order = snapshot.data!;
          final step = _getStatusStep(order.status);

          return ListView(
            padding: const EdgeInsets.all(AppTokens.s20),
            children: [
              // Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #${order.id.substring(0, 6).toUpperCase()}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                          StatusChip(status: order.status),
                        ],
                      ),
                      const SizedBox(height: AppTokens.s8),
                      Text(
                        'COD Total: ₹${order.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (order.status != 'delivered' && order.status != 'cancelled') ...[
                        const SizedBox(height: AppTokens.s8),
                        _LiveEtaCountdown(orderCreatedAt: order.createdAt),
                      ],
                      const Divider(height: AppTokens.s24),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: AppTokens.s4),
                          Expanded(
                            child: Text(
                              '${order.deliveryAddress}, ${order.village}',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                      if (order.deliveryInstructions != null &&
                          order.deliveryInstructions!.isNotEmpty) ...[
                        const SizedBox(height: AppTokens.s8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.note_alt_outlined,
                                size: 16, color: scheme.onSurfaceVariant),
                            const SizedBox(width: AppTokens.s4),
                            Expanded(
                              child: Text(
                                order.deliveryInstructions!,
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.s16),

              // Delivery location map
              if (order.latitude != null && order.longitude != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pin_drop_rounded,
                                size: 18, color: scheme.primary),
                            const SizedBox(width: AppTokens.s8),
                            const Expanded(
                              child: Text(
                                'Your Delivery Pin',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ),
                            Text(
                              '${order.latitude!.toStringAsFixed(4)}, ${order.longitude!.toStringAsFixed(4)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.s12),
                        LeafletLocationPreview(
                          latitude: order.latitude!,
                          longitude: order.longitude!,
                          height: 180,
                        ),
                        const SizedBox(height: AppTokens.s12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=${order.latitude},${order.longitude}',
                              );
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const Text('Open in Maps',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.s16),
              ],

              // The code the rider will ask for, while the order is with a rider.
              if (const ['assigned', 'picked_up', 'out_for_delivery'].contains(order.status)) ...[
                DeliveryOtpCard(orderId: order.id, status: order.status),
                const SizedBox(height: AppTokens.s16),
              ],

              // Rider card with call and WhatsApp
              if (order.deliveryBoyName != null &&
                  order.status != 'cancelled' &&
                  order.status != 'delivered') ...[
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(Icons.sports_motorsports_rounded,
                          color: scheme.onPrimaryContainer),
                    ),
                    title: Text(
                      order.deliveryBoyName!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Your local delivery partner'),
                    trailing: (order.deliveryBoyPhone != null &&
                            order.deliveryBoyPhone!.isNotEmpty)
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.outlined(
                                icon: const Icon(Icons.chat_rounded, size: 20),
                                tooltip: 'Message rider on WhatsApp',
                                onPressed: () => _contactRider(
                                  context,
                                  order,
                                  whatsApp: true,
                                ),
                              ),
                              const SizedBox(width: AppTokens.s8),
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary,
                                ),
                                icon: const Icon(Icons.call_rounded, size: 20),
                                tooltip: 'Call rider',
                                onPressed: () => _contactRider(
                                  context,
                                  order,
                                  whatsApp: false,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: AppTokens.s16),
              ],

              // Timeline / cancelled banner
              if (order.status == 'cancelled')
                Container(
                  padding: const EdgeInsets.all(AppTokens.s20),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, color: scheme.error, size: 28),
                      const SizedBox(width: AppTokens.s12),
                      Expanded(
                        child: Text(
                          'This order has been cancelled.',
                          style: TextStyle(
                            color: scheme.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.s20),
                    child: Column(
                      children: [
                        _StepTile(
                          title: 'Processing',
                          subtitle: 'Your order is being processed',
                          isCompleted: step > 0,
                          isActive: step == 0,
                        ),
                        _StepTile(
                          title: 'Rider Assigned',
                          subtitle: order.deliveryBoyName != null
                              ? 'Assigned to ${order.deliveryBoyName}'
                              : 'Waiting to assign a delivery partner',
                          isCompleted: step > 1,
                          isActive: step == 1,
                        ),
                        _StepTile(
                          title: 'Picked Up',
                          subtitle: 'Rider has picked up your items',
                          isCompleted: step > 2,
                          isActive: step == 2,
                        ),
                        _StepTile(
                          title: 'Out for Delivery',
                          subtitle: 'Rider is on the way to your door',
                          isCompleted: step > 3,
                          isActive: step == 3,
                        ),
                        _StepTile(
                          title: 'Delivered',
                          subtitle: 'OTP verified and items received',
                          isCompleted: step >= 4,
                          isActive: false,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
              _NeedHelpButton(orderId: order.id),
              if (order.status == 'delivered') ...[
                const SizedBox(height: AppTokens.s16),
                _RatingAndReorderCard(order: order),
              ],
              const SizedBox(height: AppTokens.s16),

              // Items
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Items Ordered',
                        style:
                            TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: AppTokens.s12),
                      ...order.items.map((item) {
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: AppTokens.s4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.quantity} × ${item.name}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Text(
                                formatRupees(item.price * item.quantity),
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: AppTokens.s24),
                      _BillLine(
                        label: 'Item total',
                        value: formatRupees(order.subtotal > 0
                            ? order.subtotal
                            : order.totalAmount - order.deliveryFee),
                      ),
                      _BillLine(
                        label: 'Delivery fee',
                        value: order.deliveryFee == 0
                            ? 'Free'
                            : formatRupees(order.deliveryFee),
                      ),
                      _BillLine(
                        label: order.status == 'delivered' ? 'Total paid' : 'Total',
                        value: formatRupees(order.totalAmount),
                        emphasised: true,
                      ),
                      if (order.status == 'delivered') ...[
                        const SizedBox(height: AppTokens.s8),
                        _BillLine(
                          label: 'Paid in cash to '
                              '${order.deliveryBoyName ?? 'your delivery partner'}',
                          value: formatRupees(
                              order.codCollectedAmount ?? order.totalAmount),
                        ),
                        if (order.deliveredAt != null)
                          _BillLine(
                            label: 'Delivered',
                            value: formatDateTime(order.deliveredAt!),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.s16),

              // Need Help with this Order Card
              Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppTokens.rLg),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTokens.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: AppTokens.primary),
                  ),
                  title: Text(
                    'Need Help with this Order?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Missing items, delivery delays, or refund queries',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: scheme.onSurfaceVariant),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      RouteGenerator.customerSupport,
                      arguments: order.id,
                    );
                  },
                ),
              ),
              const SizedBox(height: AppTokens.s32),
            ],
          );
        },
      ),
    );
  }
}

/// Live "Arriving in Xm" countdown, ticking every second, derived from the
/// admin's free-text `etaLabel` (e.g. "Delivers in ~20 min") by pulling out
/// its first number as a minutes estimate. Hides itself once that window
/// has elapsed or if the admin hasn't set an ETA at all — the order
/// timeline below remains the source of truth either way.
class _LiveEtaCountdown extends StatefulWidget {
  final DateTime orderCreatedAt;
  const _LiveEtaCountdown({required this.orderCreatedAt});

  @override
  State<_LiveEtaCountdown> createState() => _LiveEtaCountdownState();
}

class _LiveEtaCountdownState extends State<_LiveEtaCountdown> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream: Provider.of<ConfigProvider>(context, listen: false).streamAppConfig(),
      builder: (context, snapshot) {
        final etaLabel = snapshot.data?.etaLabel;
        final minutes = etaLabel == null
            ? null
            : int.tryParse(RegExp(r'\d+').firstMatch(etaLabel)?.group(0) ?? '');
        if (minutes == null) return const SizedBox.shrink();

        final deadline = widget.orderCreatedAt.add(Duration(minutes: minutes));
        final remaining = deadline.difference(_now);
        if (remaining.isNegative) return const SizedBox.shrink();

        final mins = remaining.inMinutes;
        final secs = remaining.inSeconds % 60;
        final text = mins > 0
            ? 'Arriving in $mins:${secs.toString().padLeft(2, '0')} min'
            : 'Arriving any moment';

        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s12, vertical: AppTokens.s8),
          decoration: BoxDecoration(
            color: AppTokens.brandChrome,
            borderRadius: BorderRadius.circular(AppTokens.rMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_rounded, size: 16, color: AppTokens.onBrandChrome),
              const SizedBox(width: AppTokens.s8),
              Text(
                text,
                style: const TextStyle(
                  color: AppTokens.onBrandChrome,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One label/value row of the bill on the order screen.
class _BillLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasised;

  const _BillLine({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: emphasised ? 15 : 13.5,
      fontWeight: emphasised ? FontWeight.w800 : FontWeight.w500,
      color: emphasised ? scheme.onSurface : scheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.s4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: AppTokens.s12),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isActive;
  final bool isLast;

  const _StepTile({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isActive,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left rail: dot + connector ──
        Column(
          children: [
            if (isActive)
              _PulsingDot()
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                ),
                child: isCompleted
                    ? Icon(Icons.check_rounded,
                        size: 14, color: scheme.onPrimary)
                    : null,
              ),
            if (!isLast)
              AnimatedContainer(
                duration: AppTokens.normal,
                width: 2,
                height: 48,
                color: isCompleted
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
              ),
          ],
        ),
        const SizedBox(width: AppTokens.s16),
        // ── Right: labels ──
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: isLast ? 0 : AppTokens.s8, top: AppTokens.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isActive || isCompleted
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// An animated dot that continuously pulses (scale 1.0 → 1.35 → 1.0)
/// to indicate the currently active order stage.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Isolates the continuous 900ms pulse from the mostly-static timeline
    // around it — otherwise every tick risks repainting more than this dot.
    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTokens.statusAssigned,
            border: Border.all(
                color: scheme.surface, width: 2),
          ),
          child: const Icon(Icons.radio_button_checked_rounded,
              size: 12, color: Colors.white),
        ),
      ),
    );
  }
}

/// Tap-to-contact support action, pre-filling the order id into the WhatsApp
/// message. Hidden entirely when the admin hasn't configured a support
/// WhatsApp number in Store Settings.
class _NeedHelpButton extends StatelessWidget {
  final String orderId;
  const _NeedHelpButton({required this.orderId});

  Future<void> _openWhatsapp(String number, String orderId) async {
    final shortId = orderId.substring(0, 6).toUpperCase();
    final message = Uri.encodeComponent('Hi, I need help with order #$shortId');
    final uri = Uri.parse('https://wa.me/$number?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream: Provider.of<ConfigProvider>(context, listen: false).streamAppConfig(),
      builder: (context, snapshot) {
        final whatsapp = snapshot.data?.supportWhatsapp;
        if (whatsapp == null || whatsapp.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.s16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openWhatsapp(whatsapp, orderId),
              icon: const Icon(Icons.support_agent_rounded, size: 16),
              label: const Text('Need help with this order?',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        );
      },
    );
  }
}

class _CancelOrderButton extends StatefulWidget {
  final String orderId;
  const _CancelOrderButton({required this.orderId});

  @override
  State<_CancelOrderButton> createState() => _CancelOrderButtonState();
}

class _CancelOrderButtonState extends State<_CancelOrderButton> {
  bool _isCancelling = false;

  Future<void> _showCancelConfirmation(BuildContext context) async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final onErrorColor = Theme.of(context).colorScheme.onError;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this order? Stock will be released immediately.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: AppTokens.s12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation (optional)',
                hintText: 'e.g., Ordered by mistake',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
              foregroundColor: onErrorColor,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isCancelling = true);

    final error = await orderProvider.cancelOrder(
      widget.orderId,
      reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isCancelling = false);

    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Order cancelled successfully.'),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.error,
          side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: _isCancelling ? null : () => _showCancelConfirmation(context),
        icon: _isCancelling
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.error,
                ),
              )
            : const Icon(Icons.cancel_outlined, size: 18),
        label: Text(
          _isCancelling ? 'Cancelling Order...' : 'Cancel Order',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// Post-delivery moment: a 1-tap star rating (written immediately, no
/// submit button), followed by a Reorder shortcut once rated. Shows a
/// static "you rated this" line if the order already has a rating.
class _RatingAndReorderCard extends StatefulWidget {
  final Order order;
  const _RatingAndReorderCard({required this.order});

  @override
  State<_RatingAndReorderCard> createState() => _RatingAndReorderCardState();
}

class _RatingAndReorderCardState extends State<_RatingAndReorderCard> {
  int? _submittedRating;
  bool _isSubmittingRating = false;
  bool _isReordering = false;

  int? get _rating => _submittedRating ?? widget.order.rating;

  Future<void> _submitRating(int stars) async {
    setState(() {
      _isSubmittingRating = true;
      _submittedRating = stars;
    });
    try {
      await Provider.of<OrderProvider>(context, listen: false)
          .submitRating(widget.order.id, stars, null);
    } catch (_) {
      if (mounted) setState(() => _submittedRating = null);
    } finally {
      if (mounted) setState(() => _isSubmittingRating = false);
    }
  }

  Future<void> _handleReorder() async {
    setState(() => _isReordering = true);

    final outcome = await ReorderHelper.reorderOrderItems(
      widget.order.items,
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
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rated = _rating != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rated ? 'Thanks for rating this order!' : 'How was your order?',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: AppTokens.s12),
            Row(
              children: List.generate(5, (i) {
                final starIndex = i + 1;
                final filled = _rating != null && starIndex <= _rating!;
                return Tooltip(
                  message: 'Rate $starIndex star${starIndex == 1 ? '' : 's'}',
                  child: IconButton(
                    onPressed: (rated || _isSubmittingRating)
                        ? null
                        : () => _submitRating(starIndex),
                    icon: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled ? AppTokens.accent : scheme.onSurfaceVariant,
                      size: 28,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
                );
              })
                  .expand((star) => [star, const SizedBox(width: AppTokens.s4)])
                  .toList(),
            ),
            if (rated) ...[
              const SizedBox(height: AppTokens.s16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isReordering ? null : _handleReorder,
                  icon: _isReordering
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: scheme.primary),
                        )
                      : const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Reorder',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
