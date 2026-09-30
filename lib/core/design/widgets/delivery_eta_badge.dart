import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/config_provider.dart';
import '../../../domain/entities/app_config.dart';
import '../app_tokens.dart';

enum DeliveryEtaBadgeStyle { chrome, surface }

class DeliveryEtaBadge extends StatelessWidget {
  final DeliveryEtaBadgeStyle style;

  const DeliveryEtaBadge({
    super.key,
    this.style = DeliveryEtaBadgeStyle.surface,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<AppConfig>(
      stream: context.read<ConfigProvider>().streamAppConfig(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.hasError ||
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final config = snapshot.data!;
        final label = config.etaLabel;
        if (label == null || label.trim().isEmpty) {
          return const SizedBox.shrink();
        }

        final isChrome = style == DeliveryEtaBadgeStyle.chrome;
        final bgColor = isChrome
            ? AppTokens.brandChrome
            : scheme.surfaceContainerHighest.withValues(alpha: 0.8);
        final textColor = isChrome
            ? AppTokens.onBrandChrome
            : scheme.onSurfaceVariant;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s8,
            vertical: AppTokens.s4,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppTokens.rPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 14,
                color: textColor,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: textColor,
                      letterSpacing: 0.2,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}
