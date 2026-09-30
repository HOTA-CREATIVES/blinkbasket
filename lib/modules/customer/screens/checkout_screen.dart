import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/leaflet_location_picker.dart';
import '../../../core/design/widgets/bill_row.dart';
import '../../../core/design/widgets/cart_changes_dialog.dart';
import '../../../core/design/widgets/product_card.dart';
import '../../../core/design/widgets/swipe_to_confirm_slider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/utils/customer_helper.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/route_generator.dart';
import '../../../domain/entities/app_config.dart';
import '../../../domain/entities/order.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  AddressModel? _selectedAddress;
  double? _pickedLat;
  double? _pickedLng;
  bool _isSubmitting = false;

  /// One id per checkout attempt, reused on retries: if the first request
  /// succeeded but its response was lost, the server hands back that order
  /// instead of rejecting the retry as a second active order.
  final String _requestId = _newRequestId();

  static String _newRequestId() {
    final rand = math.Random.secure();
    final suffix =
        List.generate(8, (_) => rand.nextInt(16).toRadixString(16)).join();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$suffix';
  }

  static const double _fallbackDeliveryFee = 30.0;
  static const double _fallbackFreeDeliveryAbove = 300.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUserModel;
      if (user != null) {
        final defaultAddress = user.defaultAddress;
        if (defaultAddress != null) {
          setState(() {
            _selectedAddress = defaultAddress;
            _addressController.text = _formatAddressLine(defaultAddress);
            _pickedLat = defaultAddress.latitude;
            _pickedLng = defaultAddress.longitude;
          });
        } else if (user.village.isNotEmpty && _addressController.text.isEmpty) {
          _addressController.text = user.village;
        }
      }
    });
  }

  ({String name, double distanceMeters, bool isInside})? _pinZone() {
    final lat = _pickedLat;
    final lng = _pickedLng;
    if (lat == null || lng == null) return null;
    return CustomerHelper.nearestZone(
      lat,
      lng,
      Provider.of<ConfigProvider>(context, listen: false).latestServiceZones,
    );
  }

  bool _pinIsOutside() => _pinZone()?.isInside == false;

  /// What the pin row says: prompt, the zone the pin is in, or that it is out
  /// of the delivery area — including when the pin and the selected saved
  /// address disagree about the village.
  String _pinLabel() {
    final zone = _pinZone();
    if (zone == null) return 'Pin Precise Location on Map';
    if (!zone.isInside) return 'Pinned location is outside our delivery area';
    final address = _selectedAddress;
    if (address != null &&
        address.village.isNotEmpty &&
        address.village != zone.name) {
      return 'Pinned in ${zone.name}, but this address is in ${address.village}';
    }
    return 'Location pinned · ${zone.name}';
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
    _instructionsController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppTokens.statusCancelled : AppTokens.statusDelivered,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleConfirmOrder(
    CartProvider cartProvider,
    AuthProvider authProvider,
    OrderProvider orderProvider,
    double grandTotal, {
    AppConfig? config,
  }) async {
    if (_isSubmitting) return;

    // Store-open guard — the Cloud Function also checks, but we surface
    // the error here to avoid the customer filling a whole form for nothing.
    if (config != null && !config.storeOpen) {
      _showSnackBar('The store is currently closed. Please try again later.');
      return;
    }

    if (!authProvider.isEmailVerified) {
      _showSnackBar(
        'Verify your email before placing an order. You can resend the link from the home screen.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        'Please complete the delivery address before placing order.',
      );
      return;
    }

    if (cartProvider.items.isEmpty) {
      _showSnackBar('Your cart is empty.');
      return;
    }

    // Prescription medicines can't be ordered until the app can verify a
    // prescription (the server rejects them too) — say so up front.
    final rxNames =
        cartProvider.items.values
            .where((c) => c.product.requiresPrescription)
            .map((c) => c.product.name)
            .toList();
    if (rxNames.isNotEmpty) {
      _showSnackBar(
        '${rxNames.first} is a prescription medicine and can\'t be ordered in the app yet. Please remove it to continue.',
      );
      return;
    }

    // Minimum order amount enforcement (if configured).
    if (config != null &&
        config.minimumOrderAmount > 0 &&
        cartProvider.totalAmount < config.minimumOrderAmount) {
      _showSnackBar(
        'Minimum order amount is ${formatRupees(config.minimumOrderAmount)}.',
      );
      return;
    }

    final user = authProvider.currentUserModel;
    if (user == null) {
      _showSnackBar('User authentication required.');
      return;
    }

    setState(() => _isSubmitting = true);

    // Last look at the live catalogue before money is committed: if a price or
    // stock changed since the cart was built, show it and let the customer
    // confirm with the new total rather than charging a surprise.
    final validation = await cartProvider.revalidate();
    if (!mounted) return;
    if (!validation.isClean) {
      setState(() => _isSubmitting = false);
      await showCartChangesDialog(
        context,
        validation.changes,
        continueLabel: 'OK',
      );
      return;
    }

    final items =
        cartProvider.items.values
            .map(
              (c) => OrderItem(
                productId: c.product.id,
                name: c.product.name,
                price: c.product.effectivePrice,
                quantity: c.quantity,
              ),
            )
            .toList();

    double? latitude = _pickedLat;
    double? longitude = _pickedLng;

    if (latitude == null || longitude == null) {
      if (_selectedAddress != null) {
        latitude = _selectedAddress!.latitude;
        longitude = _selectedAddress!.longitude;
      }
    }
    // No village-centre fallback: a centroid is not a delivery location, and
    // the rider would navigate to it as if it were the customer's pin. The
    // customer must pin (or pick a saved address that has a pin).
    if (latitude == null || longitude == null) {
      setState(() => _isSubmitting = false);
      _showSnackBar(
        'Tap "Pin Precise Location on Map" so the rider can find you.',
      );
      return;
    }

    // The server checks the delivery area too, but a customer whose pin (or
    // saved address) is outside it should hear that now, not after the swipe.
    final zone = CustomerHelper.nearestZone(
      latitude,
      longitude,
      Provider.of<ConfigProvider>(context, listen: false).latestServiceZones,
    );
    if (!zone.isInside) {
      setState(() => _isSubmitting = false);
      _showSnackBar(
        "We don't deliver to the pinned location yet. Move the pin inside the delivery area.",
      );
      return;
    }

    final instructions = _instructionsController.text.trim();
    final result = await orderProvider.createOrder(
      items: items,
      deliveryAddress: _addressController.text.trim(),
      deliveryInstructions: instructions.isEmpty ? null : instructions,
      latitude: latitude,
      longitude: longitude,
      requestId: _requestId,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.isSuccess && result.orderId != null) {
      await cartProvider.clearCart();
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        RouteGenerator.orderSuccess,
        // Prefer the server's total: it is what the customer will actually pay.
        arguments: (
          orderId: result.orderId!,
          total: result.totalAmount ?? grandTotal,
        ),
      );
    } else {
      _showSnackBar(
        orderProvider.errorMessage ??
            'Order placement failed. Please try again.',
      );
      // The usual cause is a product that changed under the cart; bring the cart
      // in line so the next attempt starts from the truth.
      unawaited(cartProvider.revalidate());
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream:
          Provider.of<ConfigProvider>(context, listen: false).streamAppConfig(),
      builder: (context, configSnapshot) {
        final deliveryFeeConfig =
            configSnapshot.data?.deliveryFee ?? _fallbackDeliveryFee;
        final freeDeliveryAboveConfig =
            configSnapshot.data?.freeDeliveryAbove ??
            _fallbackFreeDeliveryAbove;
        return _buildScaffold(
          context,
          deliveryFeeConfig,
          freeDeliveryAboveConfig,
          configSnapshot,
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    double deliveryFeeConfig,
    double freeDeliveryAboveConfig,
    AsyncSnapshot<AppConfig> configSnapshot,
  ) {
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = authProvider.currentUserModel;
    final scheme = Theme.of(context).colorScheme;

    final subtotal = cartProvider.totalAmount;
    final freeDelivery = subtotal > freeDeliveryAboveConfig;
    final deliveryFee = freeDelivery ? 0.0 : deliveryFeeConfig;
    // Must mirror placeOrder's server-side total exactly (subtotal + deliveryFee) —
    // this is the COD amount the rider collects. Any extra fee has to be added
    // server-side first, never shown here only.
    final grandTotal = subtotal + deliveryFee;
    final hasRxItem = cartProvider.items.values.any(
      (c) => c.product.requiresPrescription,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Confirm Checkout',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body:
          cartProvider.items.isEmpty
              ? const Center(child: Text('Your cart is empty.'))
              : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppTokens.s16),
                  children: [
                    // 1. Delivery Contact & Address Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTokens.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 20,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: AppTokens.s8),
                                const Text(
                                  'Delivery Address & Contact',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const Spacer(),
                                if (user != null && user.village.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTokens.rPill,
                                      ),
                                    ),
                                    child: Text(
                                      user.village,
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppTokens.s12),
                            if (user != null) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline_rounded,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      user.name.isNotEmpty
                                          ? user.name
                                          : 'Customer',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.phone_outlined,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      CustomerHelper.formatPhone(
                                        user.phone,
                                        user.email,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTokens.s12),
                            ],
                            if (user != null && user.addresses.isNotEmpty) ...[
                              DropdownButtonFormField<AddressModel>(
                                initialValue:
                                    (user.addresses.contains(_selectedAddress))
                                        ? _selectedAddress
                                        : user.addresses.first,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Saved Addresses',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items:
                                    user.addresses.map((addr) {
                                      return DropdownMenuItem<AddressModel>(
                                        value: addr,
                                        child: Text(
                                          '${addr.name} (${addr.addressLine1})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                onChanged: (addr) {
                                  if (addr != null) {
                                    setState(() {
                                      _selectedAddress = addr;
                                      _addressController
                                          .text = _formatAddressLine(addr);
                                      _pickedLat = addr.latitude;
                                      _pickedLng = addr.longitude;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: AppTokens.s12),
                            ],
                            TextFormField(
                              controller: _addressController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText:
                                    'Street Address / House No. / Landmark',
                                hintText:
                                    'Enter complete house number & landmark...',
                              ),
                              validator:
                                  (val) =>
                                      (val == null || val.trim().isEmpty)
                                          ? 'Please enter your street address'
                                          : null,
                            ),
                            const SizedBox(height: AppTokens.s12),
                            // Pin Location Action
                            InkWell(
                              onTap: () {
                                final zones =
                                    Provider.of<ConfigProvider>(
                                      context,
                                      listen: false,
                                    ).latestServiceZones;
                                // Start on the customer's own zone, not a
                                // hardcoded village.
                                final centre =
                                    (_pickedLat != null && _pickedLng != null)
                                        ? (lat: _pickedLat!, lng: _pickedLng!)
                                        : CustomerHelper.centerOf(
                                          user?.village,
                                          zones,
                                        );
                                LeafletLocationPicker.show(
                                  context: context,
                                  initialLat: centre.lat,
                                  initialLng: centre.lng,
                                  zones: zones,
                                  initialIsPinned: _pickedLat != null,
                                  onConfirmed: (lat, lng) {
                                    if (mounted) {
                                      setState(() {
                                        _pickedLat = lat;
                                        _pickedLng = lng;
                                      });
                                    }
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(AppTokens.s12),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(
                                    AppTokens.rMd,
                                  ),
                                  border: Border.all(
                                    color: scheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.pin_drop_rounded,
                                      size: 18,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _pinLabel(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color:
                                              _pinIsOutside()
                                                  ? scheme.error
                                                  : scheme.primary,
                                        ),
                                      ),
                                    ),
                                    if (_pickedLat != null && _pinIsOutside())
                                      Icon(
                                        Icons.location_off_outlined,
                                        size: 16,
                                        color: scheme.error,
                                      )
                                    else if (_pickedLat != null)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: AppTokens.statusDelivered,
                                      )
                                    else
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.s16),

                    // 2. Order Items Summary
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTokens.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Items Summary',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  '${cartProvider.itemCount} item${cartProvider.itemCount > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTokens.s8),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: cartProvider.items.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 12),
                              itemBuilder: (context, index) {
                                final item = cartProvider.items.values
                                    .elementAt(index);
                                return Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppTokens.rSm,
                                      ),
                                      child: SizedBox(
                                        width: 42,
                                        height: 42,
                                        child: ProductImage(
                                          imageUrl: item.product.imageUrl,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppTokens.s12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          Text(
                                            'Qty: ${item.quantity}  •  ${formatRupees(item.product.effectivePrice)}/${item.product.unit}',
                                            style: TextStyle(
                                              color: scheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      formatRupees(
                                        item.product.effectivePrice *
                                            item.quantity,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (hasRxItem) ...[
                              const SizedBox(height: AppTokens.s12),
                              Container(
                                padding: const EdgeInsets.all(10.0),
                                decoration: BoxDecoration(
                                  color: AppTokens.medicine.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTokens.rMd,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.medical_information_outlined,
                                      color: AppTokens.medicine,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Prescription required. Our pharmacist will verify upon arrival.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppTokens.medicine,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.s16),

                    // 3. Special Delivery Instructions
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTokens.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.note_alt_outlined,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Delivery Instructions (Optional)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _instructionsController,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                hintText:
                                    'e.g. Leave package at door, don\'t ring bell...',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.s16),

                    // 4. Payment Method Selection
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTokens.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.payments_outlined,
                                  size: 20,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Payment Method',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Only COD exists end-to-end: placeOrder writes
                            // paymentMethod: "COD" server-side. Don't offer a
                            // method the order can't actually carry.
                            ListTile(
                              leading: Icon(
                                Icons.money_rounded,
                                color: scheme.primary,
                              ),
                              title: const Text(
                                'Cash on Delivery',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: const Text(
                                'Pay cash to the delivery partner on arrival',
                                style: TextStyle(fontSize: 12),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.s16),

                    // 5. Detailed Pricing Breakdown
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTokens.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bill Details',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            BillRow(
                              label: 'Item subtotal',
                              value: formatRupees(subtotal),
                            ),
                            BillRow.deliveryFee(
                              fee:
                                  freeDelivery
                                      ? deliveryFeeConfig
                                      : deliveryFee,
                              isFree: freeDelivery,
                            ),
                            const Divider(height: 24),
                            BillRow(
                              label: 'To pay (cash on delivery)',
                              value: formatRupees(grandTotal),
                              emphasised: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
      bottomNavigationBar:
          cartProvider.items.isEmpty
              ? null
              : SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(AppTokens.s16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child:
                      _isSubmitting || orderProvider.isLoading
                          ? SizedBox(
                            height: 56,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: scheme.primary,
                              ),
                            ),
                          )
                          : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SwipeToConfirmSlider(
                                text:
                                    'SWIPE TO PLACE ORDER • ${formatRupees(grandTotal)}',
                                color: scheme.primary,
                                onSwipeCompleted:
                                    () => _handleConfirmOrder(
                                      cartProvider,
                                      authProvider,
                                      orderProvider,
                                      grandTotal,
                                      config: configSnapshot.data,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed:
                                    () => _handleConfirmOrder(
                                      cartProvider,
                                      authProvider,
                                      orderProvider,
                                      grandTotal,
                                      config: configSnapshot.data,
                                    ),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 8,
                                  ),
                                ),
                                child: Text(
                                  'Having trouble swiping? Tap to place order',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                ),
              ),
    );
  }
}
