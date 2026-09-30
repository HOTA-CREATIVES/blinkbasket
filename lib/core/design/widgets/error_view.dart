import 'package:flutter/material.dart';
import '../app_tokens.dart';
import 'app_button.dart';

/// User-friendly error view that replaces raw exceptions with clear messaging and a Retry action.
class ErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool isContained;
  final IconData icon;

  const ErrorView({
    super.key,
    this.title = 'Unable to Load',
    this.message = 'Please check your connection and try again.',
    this.onRetry,
    this.isContained = false,
    this.icon = Icons.wifi_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTokens.s20),
              decoration: BoxDecoration(
                color: scheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: scheme.error),
            ),
            const SizedBox(height: AppTokens.s16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppTokens.s8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTokens.s24),
              SizedBox(
                width: 160,
                child: AppButton.outline(
                  text: 'Try Again',
                  leadingIcon: Icons.refresh_rounded,
                  onPressed: onRetry,
                  height: 44,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isContained) return content;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(child: content),
    );
  }
}
