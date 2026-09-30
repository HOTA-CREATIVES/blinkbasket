import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/delivery_eta_badge.dart';
import '../../../core/design/widgets/product_card.dart';
import '../../../core/design/widgets/quantity_stepper.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/product_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/utils/route_generator.dart';
import '../../../domain/entities/product.dart';

/// Full-page product details screen, Blinkit-style: hero image with a
/// floating ADD/quantity control, delivery ETA badge, price, product
/// highlights and a "similar products" rail.
class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    // The catalog is a shared broadcast stream — resolve the live product so
    // price and stock stay current instead of trusting the (possibly stale)
    // entity we were constructed with.
    return StreamBuilder<List<Product>>(
      stream: context.read<ProductProvider>().streamProducts(),
      builder: (context, snapshot) {
        var product = widget.product;
        final list = snapshot.data;
        if (list != null) {
          for (final p in list) {
            if (p.id == widget.product.id) {
              product = p;
              break;
            }
          }
        }
        return _buildScaffold(context, product);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Product product) {
    final scheme = Theme.of(context).colorScheme;
    final cart = context.watch<CartProvider>();
    final quantity = cart.items[product.id]?.quantity ?? 0;
    final outOfStock = product.stock <= 0;
    final lowStock = !outOfStock && product.stock <= 5;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            backgroundColor: scheme.surface,
            surfaceTintColor: scheme.surface,
            leading: Padding(
              padding: const EdgeInsets.all(AppTokens.s8),
              child: _RoundIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(AppTokens.s8),
                child: Tooltip(
                  message: 'Favorite',
                  child: _FavoriteIconButton(product: product),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTokens.s8),
                child: Tooltip(
                  message: 'Share',
                  child: _RoundIconButton(
                    icon: Icons.share_outlined,
                    onTap: () => Share.share(
                      'Check out ${product.name} on J C Mart — ₹${_formatPrice(product.price)} (${product.unit})',
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, AppTokens.s8, AppTokens.s16, AppTokens.s8),
                child: Tooltip(
                  message: 'View Cart',
                  child: _CartIconButton(),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'product-image-${product.id}',
                    child: ProductImage(imageUrl: product.imageUrl),
                  ),
                  Positioned(
                    right: AppTokens.s16,
                    bottom: AppTokens.s16,
                    child: quantity > 0
                        ? Material(
                            elevation: 3,
                            borderRadius: BorderRadius.circular(AppTokens.rMd),
                            child: QuantityStepper(
                              quantity: quantity,
                              onIncrement: () => cart.addItem(product),
                              onDecrement: () => cart.decrementItem(product.id),
                              canIncrement: quantity < product.stock,
                            ),
                          )
                        : _FloatingAddButton(
                            outOfStock: outOfStock,
                            onAdd: () => cart.addItem(product),
                          ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.s16, AppTokens.s16, AppTokens.s16, AppTokens.s32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DeliveryEtaBadge(),
                  const SizedBox(height: AppTokens.s16),
                  Text(
                    product.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.unit,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                  ),
                  const SizedBox(height: AppTokens.s12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${_formatPrice(product.price)}',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                      if (product.requiresPrescription) ...[
                        const SizedBox(width: AppTokens.s12),
                        _RxBadge(),
                      ],
                    ],
                  ),
                  if (lowStock) ...[
                    const SizedBox(height: AppTokens.s8),
                    Text(
                      'Only ${product.stock} left — order soon!',
                      style: const TextStyle(
                        color: AppTokens.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (outOfStock) ...[
                    const SizedBox(height: AppTokens.s8),
                    Text(
                      'Currently out of stock',
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTokens.s24),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: AppTokens.s16),
                  Text(
                    'Product highlights',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppTokens.s12),
                  _HighlightRow(label: 'Category', value: product.category),
                  _HighlightRow(label: 'Unit', value: product.unit),
                  _HighlightRow(
                    label: 'Availability',
                    value: outOfStock ? 'Out of stock' : 'In stock',
                  ),
                  if (product.requiresPrescription)
                    _HighlightRow(label: 'Prescription', value: 'Required'),
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.s24),
                    Divider(color: scheme.outlineVariant),
                    const SizedBox(height: AppTokens.s16),
                    Text(
                      'About this product',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppTokens.s8),
                    Text(
                      product.description,
                      style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
                    ),
                  ],
                  if (product.requiresPrescription) ...[
                    const SizedBox(height: AppTokens.s16),
                    Container(
                      padding: const EdgeInsets.all(AppTokens.s12),
                      decoration: BoxDecoration(
                        color: AppTokens.medicine.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTokens.rMd),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.medical_information_outlined,
                              color: AppTokens.medicine, size: 20),
                          SizedBox(width: AppTokens.s8),
                          Expanded(
                            child: Text(
                              'Prescription required — this medicine can\'t be ordered in the app yet.',
                              style: TextStyle(fontSize: 13, color: AppTokens.medicine),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTokens.s24),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: AppTokens.s16),
                  Text(
                    'Similar products',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppTokens.s12),
                  _SimilarProducts(
                    category: product.category,
                    excludeId: product.id,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          AppTokens.s16,
          AppTokens.s12,
          AppTokens.s16,
          AppTokens.s12 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
          boxShadow: AppTokens.shadowSm(scheme.shadow),
        ),
        child: outOfStock
            ? Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTokens.rMd),
                ),
                child: Text(
                  'Item Currently Out of Stock',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              )
            : product.requiresPrescription
                ? Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTokens.medicine.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                    ),
                    child: const Text(
                      'Requires Prescription (In-Store Only)',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppTokens.medicine),
                    ),
                  )
                : Row(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                          ),
                          Text(
                            '₹${_formatPrice(product.discountedPrice ?? product.price)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppTokens.s16),
                      Expanded(
                        child: quantity > 0
                            ? Row(
                                children: [
                                  QuantityStepper(
                                    quantity: quantity,
                                    onIncrement: () => cart.addItem(product),
                                    onDecrement: () => cart.decrementItem(product.id),
                                    canIncrement: quantity < product.stock,
                                  ),
                                  const SizedBox(width: AppTokens.s12),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: scheme.primary,
                                        foregroundColor: scheme.onPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppTokens.rMd),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      onPressed: () => Navigator.pushNamed(context, RouteGenerator.cart),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'View Cart',
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.arrow_forward_rounded, size: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTokens.rMd),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                                label: const Text(
                                  'Add to Cart',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                onPressed: () => cart.addItem(product),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}


class _RxBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTokens.medicine,
        borderRadius: BorderRadius.circular(AppTokens.rPill),
      ),
      child: const Text(
        'Rx',
        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  final String label;
  final String value;

  const _HighlightRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.s8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s8),
          child: Icon(icon, size: 20, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _FavoriteIconButton extends StatelessWidget {
  final Product product;

  const _FavoriteIconButton({required this.product});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final favorites = context.watch<AuthProvider>().currentUserModel?.favoriteProductIds ?? const [];
    final isFavorite = favorites.contains(product.id);

    return Material(
      color: scheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          context.read<ProfileProvider>().toggleFavorite(product.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s8),
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 20,
            color: isFavorite ? Colors.red : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _CartIconButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cart = context.watch<CartProvider>();
    return Material(
      color: scheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.pushNamed(context, RouteGenerator.cart),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s8),
          child: Badge(
            isLabelVisible: cart.itemCount > 0,
            label: Text('${cart.itemCount}'),
            child: Icon(Icons.shopping_cart_outlined, size: 20, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _FloatingAddButton extends StatelessWidget {
  final bool outOfStock;
  final VoidCallback onAdd;

  const _FloatingAddButton({required this.outOfStock, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(AppTokens.rMd),
      color: scheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        onTap: outOfStock
            ? null
            : () {
                HapticFeedback.selectionClick();
                onAdd();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s20, vertical: AppTokens.s12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            border: Border.all(color: outOfStock ? scheme.outlineVariant : scheme.primary),
          ),
          child: Text(
            outOfStock ? 'OUT OF STOCK' : 'ADD',
            style: TextStyle(
              color: outOfStock ? scheme.onSurfaceVariant : scheme.primary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _SimilarProducts extends StatelessWidget {
  final String category;
  final String excludeId;

  const _SimilarProducts({
    required this.category,
    required this.excludeId,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cart = context.read<CartProvider>();

    return StreamBuilder<List<Product>>(
      stream: context.read<ProductProvider>().streamProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator(color: scheme.primary)),
          );
        }
        final similar = (snapshot.data ?? [])
            .where((p) => p.id != excludeId && p.category == category)
            .toList();

        if (similar.isEmpty) {
          return Text(
            'No similar products found.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          );
        }

        return SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: similar.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppTokens.s12),
            itemBuilder: (context, index) {
              final product = similar[index];
              return SizedBox(
                width: 150,
                child: Builder(
                  builder: (context) {
                    final inCartQty = context
                        .select<CartProvider, int>((c) => c.quantityOf(product.id));
                    return ProductCard(
                      product: product,
                      quantityInCart: inCartQty,
                      onAdd: () => cart.addItem(product),
                      onRemove: () => cart.decrementItem(product.id),
                      // Replace rather than stack: hopping product -> similar
                      // product -> similar product... should not build an
                      // unbounded back stack.
                      onTap: () => Navigator.pushReplacementNamed(
                        context,
                        RouteGenerator.productDetails,
                        arguments: product,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

String _formatPrice(double price) {
  return price == price.roundToDouble()
      ? price.toStringAsFixed(0)
      : price.toStringAsFixed(2);
}
