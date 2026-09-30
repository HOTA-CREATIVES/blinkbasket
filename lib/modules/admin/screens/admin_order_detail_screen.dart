import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/leaflet_location_picker.dart';
import '../../../core/design/widgets/status_chip.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/utils/route_generator.dart';
import '../../../domain/entities/order.dart';
import 'widgets/order_actions_sheet.dart';

/// Read-only operations view of one order, kept live from Firestore: where it
/// is in its lifecycle, who's carrying it, where it's going, and what's in it.
///
/// There is no live rider GPS in the system (riders don't publish their
/// position), so "tracking" is the status timeline plus the delivery
/// destination on the map.
class AdminOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const AdminOrderDetailScreen({super.key, required this.orderId});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late final Stream<Order> _orderStream =
      Provider.of<OrderProvider>(context, listen: false).streamOrder(widget.orderId);

  static const _steps = ['pending', 'assigned', 'picked_up', 'out_for_delivery', 'delivered'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _fmt(DateTime d) {
    final t = d.toLocal();
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.day} ${_months[t.month - 1]}, $h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s+|-'), ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a maps app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        title: Text('Order #${widget.orderId.substring(0, widget.orderId.length < 6 ? widget.orderId.length : 6).toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: scheme.surface,
        elevation: 0.5,
      ),
      body: StreamBuilder<Order>(
        stream: _orderStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTokens.primary));
          }
          final order = snapshot.data;
          if (order == null) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Order not found',
              message: 'It may have been removed.',
            );
          }
          final isActive = order.status != 'delivered' && order.status != 'cancelled';

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppTokens.s16),
                  children: [
                    _header(order, scheme),
                    _card(
                      icon: Icons.timeline_rounded,
                      title: 'Order tracking',
                      child: _timeline(order, scheme),
                    ),
                    _destinationCard(order, scheme),
                    _card(
                      icon: Icons.person_outline_rounded,
                      title: 'Customer',
                      child: _contactRow(order.customerName, order.customerPhone, scheme),
                    ),
                    _riderCard(order, scheme),
                    _itemsCard(order, scheme),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s12, AppTokens.s16, AppTokens.s12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border(top: BorderSide(color: scheme.outlineVariant)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () => showOrderActionsSheet(context, order),
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Manage order', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ───────────── sections ─────────────

  Widget _card({required IconData icon, required String title, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.s12),
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: AppTokens.s8),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s12),
          child,
        ],
      ),
    );
  }

  Widget _header(Order order, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.s12),
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cash on delivery',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${order.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: scheme.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Placed ${_fmt(order.createdAt)}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          StatusChip(status: order.status),
        ],
      ),
    );
  }

  Widget _timeline(Order order, ColorScheme scheme) {
    if (order.status == 'cancelled') {
      final by = order.cancelledBy;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTokens.s12),
        decoration: BoxDecoration(
          color: AppTokens.statusCancelled.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTokens.rMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cancelled',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppTokens.statusCancelled)),
            const SizedBox(height: 4),
            Text(
              [
                if (by != null && by.isNotEmpty) 'By $by',
                if (order.cancelReason != null && order.cancelReason!.isNotEmpty) order.cancelReason!,
                _fmt(order.updatedAt),
              ].join(' · '),
              style: TextStyle(fontSize: 13, color: scheme.onSurface),
            ),
          ],
        ),
      );
    }

    final current = _steps.indexOf(order.status).clamp(0, _steps.length - 1);
    final labels = {
      'pending': 'Order placed',
      'assigned': 'Rider assigned',
      'picked_up': 'Picked up from store',
      'out_for_delivery': 'Out for delivery',
      'delivered': 'Delivered',
    };
    String? detail(String step) {
      switch (step) {
        case 'pending':
          if (order.status == 'pending') {
            return (order.notifyTier ?? 1) >= 2
                ? 'Searching for a rider (wide search)…'
                : 'Searching for a nearby rider…';
          }
          return _fmt(order.createdAt);
        case 'assigned':
          return (order.deliveryBoyName ?? '').isNotEmpty && current >= 1 ? order.deliveryBoyName : null;
        case 'delivered':
          if (order.status == 'delivered') return _fmt(order.deliveredAt ?? order.updatedAt);
          return null;
        default:
          return null;
      }
    }

    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          _timelineRow(
            label: labels[_steps[i]]!,
            detail: detail(_steps[i]),
            done: i < current || (i == current && order.status == 'delivered'),
            active: i == current && order.status != 'delivered',
            last: i == _steps.length - 1,
            color: AppTokens.statusColor(_steps[i]),
            scheme: scheme,
          ),
      ],
    );
  }

  Widget _timelineRow({
    required String label,
    String? detail,
    required bool done,
    required bool active,
    required bool last,
    required Color color,
    required ColorScheme scheme,
  }) {
    final reached = done || active;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: reached ? color : scheme.surfaceContainerHighest,
                    border: active ? Border.all(color: color.withValues(alpha: 0.35), width: 4) : null,
                  ),
                  child: done ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: done ? color : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.s8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: reached ? FontWeight.w800 : FontWeight.w500,
                      color: reached ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (detail != null)
                    Text(detail, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _destinationCard(Order order, ColorScheme scheme) {
    final lat = order.latitude;
    final lng = order.longitude;
    return _card(
      icon: Icons.location_on_outlined,
      title: 'Delivery destination',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${order.deliveryAddress}, ${order.village}',
            style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600),
          ),
          if ((order.deliveryInstructions ?? '').isNotEmpty) ...[
            const SizedBox(height: AppTokens.s8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTokens.s8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTokens.rSm),
              ),
              child: Text('Note: ${order.deliveryInstructions}',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ),
          ],
          const SizedBox(height: AppTokens.s12),
          if (lat != null && lng != null) ...[
            LeafletLocationPreview(latitude: lat, longitude: lng, height: 190),
            const SizedBox(height: AppTokens.s8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openMaps(lat, lng),
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Open in Maps'),
                ),
              ],
            ),
            Text(
              "Live rider position isn't tracked — the map shows the customer's pinned drop-off point.",
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ] else
            Text('No map pin was saved for this order.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _contactRow(String name, String phone, ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.isEmpty ? 'Unknown' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (phone.isNotEmpty)
                Text(phone, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        if (phone.isNotEmpty)
          IconButton.filledTonal(
            tooltip: 'Call',
            onPressed: () => _call(phone),
            icon: const Icon(Icons.call_rounded, size: 20),
          ),
      ],
    );
  }

  Widget _riderCard(Order order, ColorScheme scheme) {
    final riderId = order.deliveryBoyId ?? '';
    if (riderId.isEmpty) {
      return _card(
        icon: Icons.delivery_dining_rounded,
        title: 'Rider',
        child: Text(
          order.status == 'pending' ? 'No rider yet — the order is being offered to riders.' : 'No rider assigned.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return _card(
      icon: Icons.delivery_dining_rounded,
      title: 'Rider',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _contactRow(order.deliveryBoyName ?? 'Rider', order.deliveryBoyPhone ?? '', scheme),
          const SizedBox(height: AppTokens.s8),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, RouteGenerator.adminRiderDetail, arguments: riderId),
            icon: const Icon(Icons.person_search_outlined, size: 18),
            label: const Text('View rider & workload'),
          ),
        ],
      ),
    );
  }

  Widget _itemsCard(Order order, ColorScheme scheme) {
    Widget line(String left, String right, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(left,
                    style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 15 : 14)),
              ),
              Text(right, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? 15 : 14)),
            ],
          ),
        );

    return _card(
      icon: Icons.shopping_bag_outlined,
      title: 'Items (${order.items.length})',
      child: Column(
        children: [
          for (final item in order.items)
            line('${item.quantity} × ${item.name}', '₹${(item.price * item.quantity).toStringAsFixed(2)}'),
          const Divider(height: 20),
          line('Subtotal', '₹${order.subtotal.toStringAsFixed(2)}'),
          line('Delivery fee', order.deliveryFee == 0 ? 'FREE' : '₹${order.deliveryFee.toStringAsFixed(2)}'),
          const SizedBox(height: 4),
          line('Collect from customer', '₹${order.totalAmount.toStringAsFixed(2)}', bold: true),
        ],
      ),
    );
  }
}
