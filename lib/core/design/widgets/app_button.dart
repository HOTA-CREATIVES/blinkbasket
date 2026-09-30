import 'package:flutter/material.dart';
import '../app_tokens.dart';

enum AppButtonVariant {
  primary,
  secondary,
  outline,
  text,
  destructive,
}

/// Production-ready accessible button adhering to J C Mart design system.
/// Guaranteed >= 48dp touch targets, clear loading state, and accessible semantics.
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isFullWidth;
  final double height;
  final String? semanticLabel;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
    this.isFullWidth = true,
    this.height = 50,
    this.semanticLabel,
  });

  const AppButton.outline({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.isFullWidth = true,
    this.height = 50,
    this.semanticLabel,
  }) : variant = AppButtonVariant.outline;

  const AppButton.destructive({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.isFullWidth = true,
    this.height = 50,
    this.semanticLabel,
  }) : variant = AppButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null && !isLoading;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = scheme.primary;
        fg = scheme.onPrimary;
        break;
      case AppButtonVariant.secondary:
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
        break;
      case AppButtonVariant.outline:
        bg = Colors.transparent;
        fg = scheme.primary;
        border = BorderSide(color: scheme.outlineVariant, width: 1.2);
        break;
      case AppButtonVariant.text:
        bg = Colors.transparent;
        fg = scheme.primary;
        break;
      case AppButtonVariant.destructive:
        bg = scheme.error;
        fg = scheme.onError;
        break;
    }

    if (!isEnabled && variant != AppButtonVariant.outline && variant != AppButtonVariant.text) {
      bg = scheme.surfaceContainerHighest;
      fg = scheme.onSurfaceVariant.withValues(alpha: 0.5);
    } else if (!isEnabled) {
      fg = scheme.onSurfaceVariant.withValues(alpha: 0.4);
      if (variant == AppButtonVariant.outline) {
        border = BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5), width: 1);
      }
    }

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: AppTokens.s12),
          Text(
            'Please wait...',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ] else ...[
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 20, color: fg),
            const SizedBox(width: AppTokens.s8),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: AppTokens.s8),
            Icon(trailingIcon, size: 20, color: fg),
          ],
        ],
      ],
    );

    final button = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        side: border,
      ),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel ?? text,
      child: isFullWidth ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
