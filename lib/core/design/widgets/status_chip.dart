import 'package:flutter/material.dart';
import '../app_tokens.dart';

/// Color-coded pill for an order status with an accessible icon.
class StatusChip extends StatelessWidget {
  final String status;
  final bool showIcon;

  const StatusChip({super.key, required this.status, this.showIcon = true});

  @override
  Widget build(BuildContext context) {
    final color = AppTokens.statusColor(status);
    final icon = AppTokens.statusIcon(status);

    return Semantics(
      label: 'Order status: ${AppTokens.statusLabel(status)}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s12,
          vertical: AppTokens.s4 + 2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTokens.rPill),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppTokens.s4 + 2),
            ] else ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppTokens.s8),
            ],
            Flexible(
              child: Text(
                AppTokens.statusLabel(status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
