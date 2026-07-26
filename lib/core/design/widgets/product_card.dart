  import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

  bool get _outOfStock => product.stock <= 0;
  bool get _lowStock => !_outOfStock && product.stock <= 5;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
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
                          'Only ${product.stock} left',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
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
                        child: const Text(
                          'Rx',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
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
                          style: TextStyle(
                            color: scheme.onErrorContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
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
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.unit,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(height: AppTokens.s8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${_formatPrice(product.price)}',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      quantityInCart > 0
                          ? QuantityStepper(
                              quantity: quantityInCart,
                              onIncrement: onAdd,
                              onDecrement: onRemove,
                              canIncrement: quantityInCart < product.stock,
                            )
                          : _AddButton(enabled: !_outOfStock, onAdd: onAdd),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onAdd;

  const _AddButton({required this.enabled, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 36),
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s12),
          side: BorderSide(color: enabled ? scheme.primary : scheme.outlineVariant),
          foregroundColor: scheme.primary,
          backgroundColor: scheme.primary.withValues(alpha: 0.06),
        ),
        onPressed: enabled
            ? () {
                HapticFeedback.selectionClick();
                onAdd();
              }
            : null,
        child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
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
