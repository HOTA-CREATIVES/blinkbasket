import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/product_card.dart';
import '../../../core/design/widgets/quantity_stepper.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/utils/money.dart';
import '../../../core/providers/config_provider.dart';
import '../../../domain/entities/app_config.dart';
import '../../../core/utils/route_generator.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();

  // Fallbacks used only until the live config/app stream (below) emits its
  // first value; the placeOrder Cloud Function is always the source of truth.
  //
  // The delivery address / map pin is chosen on the checkout screen only. The
  // cart used to carry its own copy of that form, which was thrown away when
  // "Proceed to checkout" was tapped (checkout starts from the saved default).
  static const double _fallbackDeliveryFee = 30.0;
  static const double _fallbackFreeDeliveryAbove = 300.0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream: Provider.of<ConfigProvider>(context, listen: false).streamAppConfig(),
      builder: (context, configSnapshot) {
        final deliveryFeeConfig =
            configSnapshot.data?.deliveryFee ?? _fallbackDeliveryFee;
        final freeDeliveryAboveConfig =
            configSnapshot.data?.freeDeliveryAbove ?? _fallbackFreeDeliveryAbove;
        return _buildScaffold(
          context,
          deliveryFeeConfig,
          freeDeliveryAboveConfig,
          storeOpen: configSnapshot.data?.storeOpen ?? true,
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    double deliveryFeeConfig,
    double freeDeliveryAboveConfig, {
    required bool storeOpen,
  }) {
    final cartProvider = Provider.of<CartProvider>(context);
    final scheme = Theme.of(context).colorScheme;

    final subtotal = cartProvider.totalAmount;
    final freeDelivery = subtotal > freeDeliveryAboveConfig;
    final deliveryFee = freeDelivery ? 0.0 : deliveryFeeConfig;
    final grandTotal = subtotal + deliveryFee;
    final amountToFree = freeDeliveryAboveConfig - subtotal;
    final hasRxItem =
        cartProvider.items.values.any((c) => c.product.requiresPrescription);

    return Scaffold(
      appBar: AppBar(title: const Text('My Cart')),
      body: cartProvider.items.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Browse the shop and add items to your cart.',
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppTokens.s16),
                children: [
                  // Free delivery nudge
                  if (!freeDelivery && amountToFree > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: AppTokens.s12),
                      padding: const EdgeInsets.all(AppTokens.s12),
                      decoration: BoxDecoration(
                        color: AppTokens.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTokens.rMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.electric_moped_rounded,
                              color: AppTokens.accent, size: 20),
                          const SizedBox(width: AppTokens.s8),
                          Expanded(
                            child: Text(
                              'Add ₹${amountToFree.toStringAsFixed(0)} more for FREE delivery!',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Cart items
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cartProvider.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item =
                            cartProvider.items.values.elementAt(index);

                        return Padding(
                          padding: const EdgeInsets.all(AppTokens.s12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppTokens.rMd),
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: ProductImage(
                                      imageUrl: item.product.imageUrl),
                                ),
                              ),
                              const SizedBox(width: AppTokens.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${formatRupees(item.product.effectivePrice)} / ${item.product.unit}',
                                      style: TextStyle(
                                          color: scheme.onSurfaceVariant,
                                          fontSize: 12),
                                    ),
                                    const SizedBox(height: AppTokens.s8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        QuantityStepper(
                                          quantity: item.quantity,
                                          onIncrement: () => cartProvider
                                              .addItem(item.product),
                                          onDecrement: () =>
                                              cartProvider.decrementItem(
                                                  item.product.id),
                                          canIncrement: item.quantity <
                                              item.product.sellableStock,
                                        ),
                                        Text(
                                          formatRupees(item.product.effectivePrice * item.quantity),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppTokens.s16),

                  // Prescription notice
                  if (hasRxItem) ...[
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
                              'Prescription medicines can\'t be ordered in the app yet. Remove them from your cart to check out.',
                              style: TextStyle(
                                  fontSize: 12.5, color: AppTokens.medicine),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTokens.s16),
                  ],


                  // Bill summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.s16),
                      child: Column(
                        children: [
                          _billRow(context, 'Item Subtotal',
                              '₹${subtotal.toStringAsFixed(2)}'),
                          const SizedBox(height: AppTokens.s8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Delivery Fee',
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant)),
                              freeDelivery
                                  ? Row(
                                      children: [
                                        Text(
                                          '₹${deliveryFeeConfig.toStringAsFixed(0)} ',
                                          style: TextStyle(
                                            color: scheme.onSurfaceVariant,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                        Text(
                                          'FREE',
                                          style: TextStyle(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text('₹${deliveryFee.toStringAsFixed(2)}'),
                            ],
                          ),
                          const Divider(height: AppTokens.s24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Grand Total',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17)),
                              Text(
                                '₹${grandTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.s16),

                  // COD notice
                  Container(
                    padding: const EdgeInsets.all(AppTokens.s12),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.payments_rounded,
                            color: scheme.primary, size: 22),
                        const SizedBox(width: AppTokens.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cash on Delivery',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: scheme.primary,
                                ),
                              ),
                              Text(
                                'Pay the rider in cash when your order arrives.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 110),
                ],
              ),
            ),
      bottomNavigationBar: cartProvider.items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTokens.s16, AppTokens.s8, AppTokens.s16, AppTokens.s16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppTokens.s16),
                  ),
                  onPressed: hasRxItem || !storeOpen
                      ? null
                      : () {
                          Navigator.pushNamed(context, RouteGenerator.checkout);
                        },
                  child: Text(
                    !storeOpen
                        ? 'Store is closed'
                        : hasRxItem
                            ? 'Remove prescription items to proceed'
                            : 'Checkout  •  ${formatRupees(grandTotal)}',
                  ),
                ),
              ),
            ),
    );
  }

  Widget _billRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
        Text(value),
      ],
    );
  }
}
