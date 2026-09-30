import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/product_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/product_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/utils/route_generator.dart';
import '../../../domain/entities/product.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  Widget build(BuildContext context) {
    final favoriteIds = context.watch<AuthProvider>().currentUserModel?.favoriteProductIds ?? const [];
    final cart = context.watch<CartProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(
          "Your Wishlist",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: favoriteIds.isEmpty
          ? const EmptyState(
              icon: Icons.favorite_border_rounded,
              title: "Your wishlist is empty",
              message: "Tap the heart on any product to save it here.",
            )
          : StreamBuilder<List<Product>>(
              stream: context.read<ProductProvider>().streamProducts(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: "Couldn't load your wishlist",
                    message: 'Check your connection and try again.',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: scheme.primary));
                }
                final favorites = (snapshot.data ?? [])
                    .where((p) => favoriteIds.contains(p.id))
                    .toList();

                if (favorites.isEmpty) {
                  return const EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: "Your wishlist is empty",
                    message: "Tap the heart on any product to save it here.",
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(AppTokens.s16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: AppTokens.s16,
                    mainAxisSpacing: AppTokens.s16,
                  ),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final product = favorites[index];
                    final inCartQty = cart.quantityOf(product.id);

                    return Stack(
                      children: [
                        ProductCard(
                          product: product,
                          quantityInCart: inCartQty,
                          onAdd: () => cart.addItem(product),
                          onRemove: () => cart.decrementItem(product.id),
                          onTap: () => Navigator.pushNamed(
                            context,
                            RouteGenerator.productDetails,
                            arguments: product,
                          ),
                        ),
                        Positioned(
                          top: AppTokens.s8,
                          right: AppTokens.s8,
                          child: Material(
                            color: scheme.surface,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => context.read<ProfileProvider>().toggleFavorite(product.id),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.favorite_rounded, size: 18, color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}
