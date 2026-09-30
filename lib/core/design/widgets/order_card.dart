import 'package:flutter/material.dart';
import 'package:hypermart/domain/entities/order.dart';
import '../app_tokens.dart';
import 'app_card.dart';
import 'status_chip.dart';
import '../../utils/date_format.dart';
import '../../utils/money.dart';

/// Consolidated, responsive order card used across Customer History, Rider, and Admin views.
class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  final Widget? trailingAction;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.trailingAction,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return 'Today, ${formatTime(dt)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return formatDate(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final itemsCount = order.items.fold<int>(0, (sum, i) => sum + i.quantity);
    final itemsSummary = order.items.map((i) => '${i.quantity}x ${i.name}').take(2).join(', ');
    final remainingCount = order.items.length - 2;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTokens.s16),
      margin: const EdgeInsets.only(bottom: AppTokens.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(order.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.s8),
              Flexible(child: StatusChip(status: order.status)),
            ],
          ),
          const Divider(height: AppTokens.s20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTokens.rSm),
                ),
                child: Icon(Icons.shopping_bag_outlined, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemsSummary + (remainingCount > 0 ? ' +$remainingCount more' : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '$itemsCount ${itemsCount == 1 ? 'item' : 'items'} • ${order.village}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.s8),
              Text(
                formatRupees(order.totalAmount),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
              ),
            ],
          ),
          if (trailingAction != null) ...[
            const SizedBox(height: AppTokens.s12),
            trailingAction!,
          ],
        ],
      ),
    );
  }
}
