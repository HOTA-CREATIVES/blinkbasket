import 'package:flutter/material.dart';
import '../app_tokens.dart';

enum PriceSize { small, medium, large, hero }

/// Formats and displays product or order pricing with optional MRP strikethrough and discount badge.
class PriceDisplay extends StatelessWidget {
  final double price;
  final double? mrp;
  final PriceSize size;
  final Color? color;
  final bool showDiscountBadge;

  const PriceDisplay({
    super.key,
    required this.price,
    this.mrp,
    this.size = PriceSize.medium,
    this.color,
    this.showDiscountBadge = true,
  });

  String _format(double val) {
    if (val == val.roundToDouble()) {
      return '₹${val.toInt()}';
    }
    return '₹${val.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryColor = color ?? scheme.onSurface;

    TextStyle? priceStyle;
    TextStyle? mrpStyle;
    double badgeFontSize = 10;

    switch (size) {
      case PriceSize.small:
        priceStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: primaryColor,
            );
        mrpStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            );
        badgeFontSize = 9;
        break;
      case PriceSize.medium:
        priceStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: primaryColor,
            );
        mrpStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            );
        badgeFontSize = 10;
        break;
      case PriceSize.large:
        priceStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: primaryColor,
            );
        mrpStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            );
        badgeFontSize = 11;
        break;
      case PriceSize.hero:
        priceStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: primaryColor,
            );
        mrpStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            );
        badgeFontSize = 12;
        break;
    }

    final hasDiscount = mrp != null && mrp! > price;
    final discountPercent = hasDiscount ? (((mrp! - price) / mrp!) * 100).round() : 0;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppTokens.s8,
      children: [
        Text(
          _format(price),
          style: priceStyle,
        ),
        if (hasDiscount)
          Text(
            _format(mrp!),
            style: mrpStyle,
          ),
        if (hasDiscount && showDiscountBadge && discountPercent > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTokens.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTokens.rSm),
              border: Border.all(
                color: AppTokens.success.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Text(
              '$discountPercent% OFF',
              style: TextStyle(
                color: AppTokens.success,
                fontSize: badgeFontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}
