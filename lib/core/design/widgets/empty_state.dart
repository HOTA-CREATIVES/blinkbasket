import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app_tokens.dart';

/// Friendly empty / error placeholder with an optional action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  /// Optional bundled SVG (e.g. from `assets/svgs/`) shown instead of the
  /// icon-in-a-circle treatment, for the handful of empty states that have
  /// a genuine illustration to match — most should leave this null and use
  /// the icon fallback rather than force-fitting an unrelated illustration.
  final String? illustrationAsset;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
    this.illustrationAsset,
  });

  const EmptyState.error({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Please check your connection and try again.',
    this.actionLabel = 'Retry',
    this.onAction,
  })  : icon = Icons.cloud_off_rounded,
        isError = true,
        illustrationAsset = null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = isError ? scheme.error : scheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (illustrationAsset != null)
              SvgPicture.asset(illustrationAsset!, height: 140)
            else
              Container(
                padding: const EdgeInsets.all(AppTokens.s20),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 44, color: tint),
              ),
            const SizedBox(height: AppTokens.s16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: AppTokens.s8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTokens.s20),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
