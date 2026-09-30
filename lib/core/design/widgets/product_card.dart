  import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../domain/entities/product.dart';
import '../app_tokens.dart';
import 'quantity_stepper.dart';

/// Product tile for the shop grid: cached image, price/unit,
/// prescription badge, ADD button or quantity stepper, and an
/// out-of-stock overlay.
class ProductCard extends StatelessWidget {
  final Product product;
  final int quantityInCart;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.quantityInCart,
    required this.onAdd,
    required this.onRemove,
    this.onTap,
  });

  bool get _outOfStock => product.isOutOfStock;
  bool get _lowStock => !_outOfStock && product.sellableStock <= 5;

  /// Whole-number discount percentage vs. [Product.discountedPrice], or
  /// null when there's no active discount.
  int? get _discountPercent => product.hasDiscount ? product.discountPercent : null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final discountPercent = _discountPercent;

    final effectivePrice = product.effectivePrice;
    final stockInfo = _outOfStock ? 'Out of stock' : (_lowStock ? 'Only ${product.sellableStock} left' : '');
    final rxInfo = product.requiresPrescription ? 'Requires prescription' : '';
    final semanticSummary = '${product.name}, ${product.unit}, Rupees ${_formatPrice(effectivePrice)}. $stockInfo $rxInfo'.trim();

    return Semantics(
      container: true,
      label: semanticSummary,
      hint: onTap != null ? 'Double tap to view details' : null,
      button: onTap != null,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(imageUrl: product.imageUrl),
                    if (discountPercent != null)
                      Positioned(
                        bottom: AppTokens.s8,
                        left: AppTokens.s8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.s8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.tertiary,
                            borderRadius: BorderRadius.circular(AppTokens.rPill),
                            boxShadow: AppTokens.shadowSm(scheme.tertiary),
                          ),
                          child: Text(
                            '$discountPercent% OFF',
                            style: textTheme.labelSmall?.copyWith(color: scheme.onTertiary),
                          ),
                        ),
                      ),
                    if (_lowStock)
                      Positioned(
                        top: AppTokens.s8,
                        right: AppTokens.s8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.s8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTokens.accent,
                            borderRadius: BorderRadius.circular(AppTokens.rPill),
                          ),
                          child: Text(
                            'Only ${product.sellableStock} left',
                            style: textTheme.labelSmall?.copyWith(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    if (product.requiresPrescription)
                      Positioned(
                        top: AppTokens.s8,
                        left: AppTokens.s8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.s8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTokens.medicine,
                            borderRadius: BorderRadius.circular(AppTokens.rPill),
                          ),
                          child: Text(
                            'Rx',
                            style: textTheme.labelSmall?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    if (_outOfStock)
                      Container(
                        color: scheme.surface.withValues(alpha: 0.7),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.s12, vertical: AppTokens.s4),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(AppTokens.rPill),
                          ),
                          child: Text(
                            'OUT OF STOCK',
                            style: textTheme.labelSmall?.copyWith(color: scheme.onErrorContainer),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTokens.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.unit,
                      style: textTheme.labelMedium,
                    ),
                    const SizedBox(height: AppTokens.s8),
                    if (discountPercent != null) ...[
                      Text(
                        '₹${_formatPrice(product.price)}',
                        style: textTheme.labelMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 1),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '₹${_formatPrice(product.effectivePrice)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 4),
                        quantityInCart > 0
                            ? QuantityStepper(
                                quantity: quantityInCart,
                                onIncrement: onAdd,
                                onDecrement: onRemove,
                                canIncrement: quantityInCart < product.sellableStock,
                                productName: product.name,
                              )
                            : _AddButton(enabled: !_outOfStock, onAdd: onAdd, productName: product.name),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onAdd;
  final String productName;

  const _AddButton({required this.enabled, required this.onAdd, required this.productName});

  @override
  Widget build(BuildContext context) {
    final label = enabled ? 'Add $productName to cart' : '$productName out of stock';
    if (!enabled) {
      return Semantics(
        button: false,
        label: label,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            border: Border.all(color: Colors.grey.shade300),
          ),
          alignment: Alignment.center,
          child: Text(
            'NO STOCK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppTokens.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onAdd();
            try {
              SemanticsService.sendAnnouncement(
                View.of(context),
                'Added $productName to cart',
                TextDirection.ltr,
              );
            } catch (_) {}
          },
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          child: Container(
            height: 36,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.rMd),
              border: Border.all(color: AppTokens.primary, width: 1.5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ADD',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: AppTokens.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.add_rounded, size: 16, color: AppTokens.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cached product image with graceful placeholder / fallback.
class ProductImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const ProductImage({super.key, required this.imageUrl, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: Icon(Icons.shopping_basket_outlined,
          size: 40, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
    );

    if (imageUrl.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      placeholder: (_, __) => Container(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

String _formatPrice(double price) {
  return price == price.roundToDouble()
      ? price.toStringAsFixed(0)
      : price.toStringAsFixed(2);
}
