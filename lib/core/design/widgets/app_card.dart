import 'package:flutter/material.dart';
import '../app_tokens.dart';

/// Standard container card conforming to JC Mart design system.
/// Provides consistent border, radius, surface background, and interactive ink states.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool hasShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.s16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = AppTokens.rLg,
    this.hasShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = color ?? scheme.surface;
    final border = BorderSide(
      color: borderColor ?? scheme.outlineVariant.withValues(alpha: 0.5),
      width: 1,
    );

    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.fromBorderSide(border),
        boxShadow: hasShadow ? AppTokens.shadowSm(scheme.shadow) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}
