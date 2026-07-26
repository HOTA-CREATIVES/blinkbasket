import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/skeleton.dart';
import '../../../core/providers/product_provider.dart';
import '../../../domain/entities/inventory_ledger.dart';

/// Admin-only screen that lists the last 50 inventory audit log entries
/// from /inventoryLogs collection in descending timestamp order.
class InventoryLogsScreen extends StatelessWidget {
  const InventoryLogsScreen({super.key});

  IconData _iconForChangeType(String type) {
    switch (type) {
      case 'reserve':
        return Icons.lock_outline_rounded;
      case 'release':
        return Icons.lock_open_rounded;
      case 'cancel_release':
        return Icons.undo_rounded;
      case 'stock_update':
        return Icons.edit_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  Color _colorForChangeType(String type) {
    switch (type) {
      case 'reserve':
        return AppTokens.statusPending;
      case 'release':
        return AppTokens.statusDelivered;
      case 'cancel_release':
        return AppTokens.statusAssigned;
      case 'stock_update':
        return AppTokens.statusPickedUp;
      default:
        return AppTokens.statusPending;
    }
  }

  String _formatTs(DateTime? ts) {
    if (ts == null) return '';
    final dt = ts.toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$h:$m\n$d/$mo';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Audit Logs',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Shows the last 50 stock-change events',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Showing the last 50 inventory events.'),
                behavior: SnackBarBehavior.floating,
              ));
            },
          ),
        ],
      ),
      body: StreamBuilder<List<InventoryLedger>>(
        stream: Provider.of<ProductProvider>(context, listen: false)
            .streamAllInventoryLogs(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return const EmptyState.error();
          }
          if (!snap.hasData || snap.data!.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No audit logs yet',
              message: 'Inventory changes will appear here in real time.',
            );
          }

          final logs = snap.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(AppTokens.s16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s8),
            itemBuilder: (context, i) {
              final log = logs[i];
              final changeType = log.changeType;
              final productId = log.productId;
              final qtyChange = log.physicalDelta != 0 ? log.physicalDelta : log.reservedDelta;
              final actorUid = log.adminId;
              final ts = log.timestamp;
              final iconColor = _colorForChangeType(changeType);

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.s16, vertical: AppTokens.s8),
                  leading: Container(
                     width: 44,
                     height: 44,
                     decoration: BoxDecoration(
                       color: iconColor.withValues(alpha: 0.10),
                       borderRadius: BorderRadius.circular(AppTokens.rSm),
                     ),
                     child: Icon(_iconForChangeType(changeType),
                         color: iconColor, size: 22),
                  ),
                  title: Text(
                    '${productId.length > 14 ? productId.substring(0, 14) : productId}'
                    '  •  ${changeType.replaceAll('_', ' ').toUpperCase()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        'Qty: ${qtyChange > 0 ? '+' : ''}$qtyChange',
                        style: TextStyle(
                          color: qtyChange < 0 ? scheme.error : AppTokens.statusDelivered,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Actor: ${actorUid.length > 12 ? actorUid.substring(0, 12) : actorUid}...',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                  trailing: Text(
                    _formatTs(ts),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()]),
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
