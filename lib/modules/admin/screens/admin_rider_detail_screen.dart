import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/status_chip.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/utils/route_generator.dart';
import '../../../domain/entities/order.dart';
import 'widgets/edit_rider_sheet.dart';

/// One rider: profile, live workload, the orders they're carrying right now
/// (each opens the order tracking page) and their recent history.
///
/// Workload and history are computed from the shared admin orders stream, which
/// is capped at the latest 300 orders — enough for "now" and "recent", but not
/// an all-time delivery count.
class AdminRiderDetailScreen extends StatelessWidget {
  final String riderId;
  const AdminRiderDetailScreen({super.key, required this.riderId});

  static const _activeStatuses = {'assigned', 'picked_up', 'out_for_delivery'};

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s+|-'), ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    return StreamBuilder<List<UserModel>>(
      stream: orderProvider.streamAllDeliveryBoys(),
      builder: (context, ridersSnap) {
        if (ridersSnap.connectionState == ConnectionState.waiting && !ridersSnap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Rider')),
            body: const Center(child: CircularProgressIndicator(color: AppTokens.primary)),
          );
        }
        final rider = (ridersSnap.data ?? const <UserModel>[])
            .where((r) => (r.docId ?? r.uid) == riderId)
            .firstOrNull;
        if (rider == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Rider')),
            body: const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Rider not found',
              message: 'This rider may have been removed.',
            ),
          );
        }

        return Scaffold(
          backgroundColor: scheme.surfaceContainerLow,
          appBar: AppBar(
            title: Text(rider.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            backgroundColor: scheme.surface,
            elevation: 0.5,
            actions: [
              IconButton(
                tooltip: 'Edit rider',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: scheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => EditRiderSheet(rider: rider),
                ),
              ),
            ],
          ),
          body: StreamBuilder<List<Order>>(
            stream: orderProvider.streamAllOrders(),
            builder: (context, ordersSnap) {
              final mine = (ordersSnap.data ?? const <Order>[])
                  .where((o) => o.deliveryBoyId == riderId)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              final active = mine.where((o) => _activeStatuses.contains(o.status)).toList();
              final delivered = mine.where((o) => o.status == 'delivered').length;
              final recent = mine.where((o) => !_activeStatuses.contains(o.status)).take(8).toList();

              return ListView(
                padding: const EdgeInsets.all(AppTokens.s16),
                children: [
                  _profileCard(context, rider, orderProvider, scheme),
                  _statsRow(active.length, delivered, scheme),
                  _sectionTitle('Current assignments', active.length, scheme),
                  if (ordersSnap.connectionState == ConnectionState.waiting && !ordersSnap.hasData)
                    const Padding(
                      padding: EdgeInsets.all(AppTokens.s24),
                      child: Center(child: CircularProgressIndicator(color: AppTokens.primary)),
                    )
                  else if (active.isEmpty)
                    _emptyNote('No active deliveries — this rider is free.', scheme)
                  else
                    for (final o in active) _orderTile(context, o, scheme),
                  const SizedBox(height: AppTokens.s8),
                  _sectionTitle('Recent activity', recent.length, scheme),
                  if (recent.isEmpty)
                    _emptyNote('No completed or cancelled orders yet.', scheme)
                  else
                    for (final o in recent) _orderTile(context, o, scheme),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _profileCard(BuildContext context, UserModel rider, OrderProvider orderProvider, ColorScheme scheme) {
    final dutyLabel = !rider.isActive ? 'DISABLED' : (rider.onDuty ? 'ON DUTY' : 'OFF DUTY');
    final dutyColor = !rider.isActive
        ? scheme.error
        : (rider.onDuty ? AppTokens.statusDelivered : scheme.onSurfaceVariant);

    Widget chip(String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTokens.rSm),
          ),
          child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
        );

    Widget infoRow(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
              ),
            ],
          ),
        );

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
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTokens.accent.withValues(alpha: 0.12),
                child: const Icon(Icons.delivery_dining_rounded, size: 30, color: AppTokens.accent),
              ),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rider.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        chip(dutyLabel, dutyColor),
                        if (rider.village.isNotEmpty) chip(rider.village, scheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
              if (rider.phone.isNotEmpty)
                IconButton.filledTonal(
                  tooltip: 'Call rider',
                  onPressed: () => _call(rider.phone),
                  icon: const Icon(Icons.call_rounded, size: 20),
                ),
            ],
          ),
          const Divider(height: 24),
          if (rider.phone.isNotEmpty) infoRow(Icons.phone_outlined, rider.phone),
          if (rider.email.isNotEmpty) infoRow(Icons.email_outlined, rider.email),
          if ((rider.vehicleNo ?? '').isNotEmpty) infoRow(Icons.two_wheeler_rounded, 'Vehicle: ${rider.vehicleNo}'),
          if ((rider.licenseNo ?? '').isNotEmpty) infoRow(Icons.badge_outlined, 'Licence: ${rider.licenseNo}'),
          const SizedBox(height: AppTokens.s8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Account enabled', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('A disabled rider stops receiving order offers'),
            value: rider.isActive,
            onChanged: (v) => orderProvider.updateDeliveryBoyActiveStatus(rider.docId ?? rider.uid, v),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(int activeNow, int delivered, ColorScheme scheme) {
    Widget stat(String label, int value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppTokens.rLg),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.s16),
      child: Row(
        children: [
          stat('Active now', activeNow, activeNow > 2 ? scheme.error : AppTokens.accent),
          const SizedBox(width: AppTokens.s12),
          stat('Delivered (recent)', delivered, AppTokens.statusDelivered),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, int count, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, AppTokens.s8),
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(width: AppTokens.s8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTokens.rPill),
            ),
            child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _emptyNote(String text, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.s8),
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
    );
  }

  Widget _orderTile(BuildContext context, Order o, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.s8),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.rLg),
          onTap: () => Navigator.pushNamed(context, RouteGenerator.adminOrderDetail, arguments: o.id),
          child: Container(
            padding: const EdgeInsets.all(AppTokens.s12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.rLg),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('#${o.id.substring(0, o.id.length < 6 ? o.id.length : 6).toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(width: AppTokens.s8),
                          StatusChip(status: o.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${o.customerName} · ${o.village}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.s8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${o.totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.w900, color: scheme.primary)),
                    Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
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
