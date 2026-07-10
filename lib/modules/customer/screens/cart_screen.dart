import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../domain/entities/order.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
      if (user != null && user.village.isNotEmpty) {
        _addressController.text = user.village;
      }
    });
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
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleCheckout(CartProvider cartProvider, AuthProvider authProvider, OrderProvider orderProvider) async {
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

    final deliveryFee = cartProvider.totalAmount > 300 ? 0.0 : 30.0;
    final totalAmount = cartProvider.totalAmount + deliveryFee;

    final success = await orderProvider.createOrder(
      customerId: user.uid,
      customerName: user.name,
      customerPhone: user.phone,
      deliveryAddress: _addressController.text.trim(),
      village: user.village,
      items: items,
      totalAmount: totalAmount,
    );

    if (success) {
      cartProvider.clearCart();
      _showSnackBar('Order placed successfully via Cash on Delivery!', isError: false);
      if (mounted) {
        Navigator.pop(context); // Back to Home
        Navigator.pushNamed(context, '/order-history');
      }
    } else {
      _showSnackBar(orderProvider.errorMessage ?? 'Checkout failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);
    final user = authProvider.currentUserModel;

    final deliveryFee = cartProvider.totalAmount > 300 ? 0.0 : 30.0;
    final grandTotal = cartProvider.totalAmount + deliveryFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
      ),
      body: cartProvider.items.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Your cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Cart items list
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 1,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cartProvider.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final key = cartProvider.items.keys.elementAt(index);
                        final item = cartProvider.items[key]!;

                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${item.product.price} / ${item.product.unit}',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.green),
                                    onPressed: () => cartProvider.decrementItem(item.product.id),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                    onPressed: () => cartProvider.addItem(item.product),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹${(item.product.price * item.quantity).toStringAsFixed(1)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Delivery Address section
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery Details',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          if (user != null)
                            Text(
                              'Village/Region: ${user.village}',
                              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.green),
                            ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Street Address / Landmarks / House No.',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (val) =>
                                (val == null || val.trim().isEmpty) ? 'Please enter your street address' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment method indicator (COD ONLY)
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.green.shade50,
                    elevation: 0,
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.monetization_on, color: Colors.green, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Method: Cash on Delivery',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Pay cash or scan UPI QR code to rider on arrival.',
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Receipt card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Item Subtotal', style: TextStyle(color: Colors.grey)),
                              Text('₹${cartProvider.totalAmount.toStringAsFixed(1)}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Delivery Partner Fee', style: TextStyle(color: Colors.grey)),
                              Text(deliveryFee == 0.0 ? 'FREE' : '₹${deliveryFee.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    color: deliveryFee == 0.0 ? Colors.green : Colors.black,
                                    fontWeight: deliveryFee == 0.0 ? FontWeight.bold : FontWeight.normal,
                                  )),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              Text(
                                '₹${grandTotal.toStringAsFixed(1)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Checkout Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: orderProvider.isLoading
                        ? null
                        : () => _handleCheckout(cartProvider, authProvider, orderProvider),
                    child: orderProvider.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'PLACE ORDER (CASH ON DELIVERY)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }
}
