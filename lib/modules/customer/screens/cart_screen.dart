import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/data/villages.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/design/widgets/leaflet_location_picker.dart';
import '../../../core/design/widgets/product_card.dart';
import '../../../core/design/widgets/quantity_stepper.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../domain/entities/app_config.dart';
import '../../../domain/entities/order.dart';
import '../../../core/models/user_model.dart';
import 'order_success_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  AddressModel? _selectedAddress;
  double? _pickedLat;
  double? _pickedLng;

  // Fallbacks used only until the live config/app stream (below) emits its
  // first value; the placeOrder Cloud Function is always the source of truth.
  static const double _fallbackDeliveryFee = 30.0;
  static const double _fallbackFreeDeliveryAbove = 300.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUserModel;
      if (user != null) {
        if (user.addresses.isNotEmpty) {
          setState(() {
            _selectedAddress = user.addresses.first;
            _addressController.text = _formatAddressLine(user.addresses.first);
            _pickedLat = user.addresses.first.latitude;
            _pickedLng = user.addresses.first.longitude;
          });
        } else if (user.village.isNotEmpty && _addressController.text.isEmpty) {
          _addressController.text = user.village;
        }
      }
    });
  }

  String _formatAddressLine(AddressModel address) {
    final parts = [
      address.addressLine1,
      if (address.addressLine2 != null && address.addressLine2!.isNotEmpty)
        address.addressLine2,
      if (address.landmark != null && address.landmark!.isNotEmpty)
        'Landmark: ${address.landmark}',
    ];
    return parts.join(', ');
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppTokens.statusCancelled : AppTokens.statusDelivered,
      ),
    );
  }

  Future<void> _handleCheckout(CartProvider cartProvider, AuthProvider authProvider,
      OrderProvider orderProvider, double grandTotal) async {
    if (!_formKey.currentState!.validate()) return;
    if (cartProvider.items.isEmpty) return;

    final user = authProvider.currentUserModel;
    if (user == null) {
      _showSnackBar('User authentication required.');
      return;
    }

    final items = cartProvider.items.values
        .map((c) => OrderItem(
              productId: c.product.id,
              name: c.product.name,
              price: c.product.price,
              quantity: c.quantity,
            ))
        .toList();

    // Prices, delivery fee, and total are computed server-side by the
    // placeOrder Cloud Function; the cart totals shown here are a preview.
    // Use map-picked coordinates first, then fall back to saved address,
    // then village centroid.
    double? latitude = _pickedLat;
    double? longitude = _pickedLng;

    if (latitude == null || longitude == null) {
      if (_selectedAddress != null) {
        latitude = _selectedAddress!.latitude;
        longitude = _selectedAddress!.longitude;
      }
    }
    if (latitude == null || longitude == null) {
      final village = Villages.byName(user.village.trim());
      if (village != null) {
        latitude = village.latitude;
        longitude = village.longitude;
      }
    }

    final result = await orderProvider.createOrder(
      items: items,
      deliveryAddress: _addressController.text.trim(),
      latitude: latitude,
      longitude: longitude,
    );

    if (!mounted) return;
    if (result.isSuccess && result.orderId != null) {
      cartProvider.clearCart();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: result.orderId!,
            total: grandTotal,
          ),
        ),
      );
    } else {
      _showSnackBar(orderProvider.errorMessage ?? 'Checkout failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // The delivery fee / free-delivery threshold are authoritative in
    // Firestore config/app (read server-side by placeOrder); stream them
    // here instead of hardcoding so admin changes reflect immediately.
    return StreamBuilder<AppConfig>(
      stream: Provider.of<ConfigProvider>(context, listen: false).streamAppConfig(),
      builder: (context, configSnapshot) {
        final deliveryFeeConfig =
            configSnapshot.data?.deliveryFee ?? _fallbackDeliveryFee;
        final freeDeliveryAboveConfig =
            configSnapshot.data?.freeDeliveryAbove ?? _fallbackFreeDeliveryAbove;
        return _buildScaffold(context, deliveryFeeConfig, freeDeliveryAboveConfig);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    double deliveryFeeConfig,
    double freeDeliveryAboveConfig,
  ) {
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = authProvider.currentUserModel;
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
              message: 'Browse the shop and add fresh groceries or medicines.',
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
                                      '₹${item.product.price} / ${item.product.unit}',
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
                                              item.product.stock,
                                        ),
                                        Text(
                                          '₹${(item.product.price * item.quantity).toStringAsFixed(2)}',
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
                              'Your cart has prescription medicines. Our team will verify your prescription before dispatch.',
                              style: TextStyle(
                                  fontSize: 12.5, color: AppTokens.medicine),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTokens.s16),
                  ],

                  // Delivery address
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 18, color: scheme.primary),
                              const SizedBox(width: AppTokens.s4),
                              const Text(
                                'Delivery Details',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              const Spacer(),
                              if (user != null)
                                Text(
                                  user.village,
                                  style: TextStyle(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                          if (user != null && user.addresses.isNotEmpty) ...[
                            const SizedBox(height: AppTokens.s12),
                            DropdownButtonFormField<AddressModel>(
                              value: _selectedAddress,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Select Saved Address',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: user.addresses.map((addr) {
                                return DropdownMenuItem<AddressModel>(
                                  value: addr,
                                  child: Text('${addr.name} (${addr.addressLine1})',
                                      overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (addr) {
                                if (addr != null) {
                                  setState(() {
                                    _selectedAddress = addr;
                                    _addressController.text = _formatAddressLine(addr);
                                    _pickedLat = addr.latitude;
                                    _pickedLng = addr.longitude;
                                  });
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: AppTokens.s12),
                          TextFormField(
                            controller: _addressController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Street Address / Landmark / House No.',
                            ),
                            validator: (val) =>
                                (val == null || val.trim().isEmpty)
                                    ? 'Please enter your street address'
                                    : null,
                          ),
                          const SizedBox(height: AppTokens.s16),
                          // ── Location Pin Section ──
                          Container(
                            padding: const EdgeInsets.all(AppTokens.s12),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(AppTokens.rMd),
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.map_rounded,
                                        size: 18, color: scheme.primary),
                                    const SizedBox(width: AppTokens.s8),
                                    const Text(
                                      'Delivery Pin',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14),
                                    ),
                                    const Spacer(),
                                    if (_pickedLat != null && _pickedLng != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTokens.statusDelivered
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(AppTokens.rPill),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle_rounded,
                                                size: 12,
                                                color: AppTokens.statusDelivered),
                                            SizedBox(width: 4),
                                            Text(
                                              'Pinned',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppTokens.statusDelivered,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppTokens.s8),
                                if (_pickedLat != null && _pickedLng != null) ...[
                                  LeafletLocationPreview(
                                    latitude: _pickedLat!,
                                    longitude: _pickedLng!,
                                    height: 120,
                                  ),
                                  const SizedBox(height: AppTokens.s8),
                                  Text(
                                    '${_pickedLat!.toStringAsFixed(5)}, ${_pickedLng!.toStringAsFixed(5)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ] else
                                  Text(
                                    'Pin your exact house location for accurate delivery',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant),
                                  ),
                                const SizedBox(height: AppTokens.s8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      final initialLat = _pickedLat ??  16.5449;
                                      final initialLng = _pickedLng ?? 81.5212;
                                      LeafletLocationPicker.show(
                                        context: context,
                                        initialLat: initialLat,
                                        initialLng: initialLng,
                                        onConfirmed: (lat, lng) {
                                          setState(() {
                                            _pickedLat = lat;
                                            _pickedLng = lng;
                                          });
                                        },
                                      );
                                    },
                                    icon: const Icon(
                                        Icons.pin_drop_rounded, size: 16),
                                    label: Text(
                                      _pickedLat != null
                                          ? 'Change Pin'
                                          : 'Pin Delivery Location',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.s16),

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
                                'Pay cash or scan the rider\'s UPI QR on arrival.',
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
                  onPressed: orderProvider.isLoading
                      ? null
                      : () => _handleCheckout(
                          cartProvider, authProvider, orderProvider, grandTotal),
                  child: orderProvider.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          'PLACE ORDER  •  ₹${grandTotal.toStringAsFixed(2)}'),
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
