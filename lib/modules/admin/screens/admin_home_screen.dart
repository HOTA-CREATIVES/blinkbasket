import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../domain/entities/order.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/repositories/product_repository.dart';
import '../../../data/repositories/firebase_product_repository.dart';
import 'assign_rider_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final ProductRepository _productRepository = FirebaseProductRepository();
  final _productNameController = TextEditingController();
  final _productDescController = TextEditingController();
  final _productPriceController = TextEditingController();
  final _productCategoryController = TextEditingController();
  final _productStockController = TextEditingController();
  final _productUnitController = TextEditingController();
  final _productImgUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _productNameController.dispose();
    _productDescController.dispose();
    _productPriceController.dispose();
    _productUnitController.dispose();
    _productCategoryController.dispose();
    _productStockController.dispose();
    _productImgUrlController.dispose();
    super.dispose();
  }

  void _showAddProductBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add New Catalog Product',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _productNameController,
                    decoration: const InputDecoration(labelText: 'Product Name (e.g. Organic Tomatoes)'),
                    validator: (val) => (val == null || val.isEmpty) ? 'Enter product name' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _productDescController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (val) => (val == null || val.isEmpty) ? 'Enter description' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _productPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Price (₹)'),
                          validator: (val) => (val == null || val.isEmpty) ? 'Enter price' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _productUnitController,
                          decoration: const InputDecoration(labelText: 'Unit (e.g. 500g, 1kg)'),
                          validator: (val) => (val == null || val.isEmpty) ? 'Enter unit' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _productCategoryController,
                          decoration: const InputDecoration(labelText: 'Category'),
                          validator: (val) => (val == null || val.isEmpty) ? 'Enter category' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _productStockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Initial Stock'),
                          validator: (val) => (val == null || val.isEmpty) ? 'Enter stock count' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _productImgUrlController,
                    decoration: const InputDecoration(labelText: 'Product Image URL (Optional)'),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        final prod = Product(
                          id: '',
                          name: _productNameController.text.trim(),
                          description: _productDescController.text.trim(),
                          price: double.parse(_productPriceController.text.trim()),
                          imageUrl: _productImgUrlController.text.trim(),
                          category: _productCategoryController.text.trim(),
                          stock: int.parse(_productStockController.text.trim()),
                          unit: _productUnitController.text.trim(),
                        );
                        await _productRepository.addProduct(prod);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Product added successfully!')),
                          );
                        }
                        _productNameController.clear();
                        _productDescController.clear();
                        _productPriceController.clear();
                        _productUnitController.clear();
                        _productCategoryController.clear();
                        _productStockController.clear();
                        _productImgUrlController.clear();
                      },
                      child: const Text('ADD PRODUCT', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'picked_up':
        return Colors.indigo;
      case 'out_for_delivery':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Operations Desk', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Colors.blue, size: 28),
            onPressed: _showAddProductBottomSheet,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Order>>(
        stream: orderProvider.streamAllOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blue));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No orders found in the database.', style: TextStyle(color: Colors.grey)));
          }

          final orders = snapshot.data!;
          final activeOrders = orders.where((o) => o.status != 'delivered' && o.status != 'cancelled').toList();
          final completedOrders = orders.where((o) => o.status == 'delivered' || o.status == 'cancelled').toList();

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  indicatorColor: Colors.blue,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: 'Incoming / Active Orders'),
                    Tab(text: 'Historical Orders'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Active orders
                      activeOrders.isEmpty
                          ? const Center(child: Text('No active orders right now.', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: activeOrders.length,
                              itemBuilder: (context, index) {
                                final order = activeOrders[index];

                                return Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  margin: const EdgeInsets.only(bottom: 16.0),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Order #${order.id.substring(0, 6).toUpperCase()}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(order.status).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                order.status.toUpperCase(),
                                                style: TextStyle(
                                                  color: _getStatusColor(order.status),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 24),
                                        Text('Customer: ${order.customerName} (${order.customerPhone})', style: const TextStyle(fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 4),
                                        Text('Location: ${order.deliveryAddress}, ${order.village}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                        const SizedBox(height: 8),
                                        Text('Total COD Amt: ₹${order.totalAmount.toStringAsFixed(1)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 12),
                                        if (order.status == 'pending') ...[
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.person_add_alt_1),
                                              label: const Text('ASSIGN DELIVERY BOY'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue.shade700,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => AssignRiderScreen(orderId: order.id),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ] else ...[
                                          Row(
                                            children: [
                                              const Icon(Icons.person_outline, size: 16, color: Colors.indigo),
                                              const SizedBox(width: 4),
                                              Text('Assigned Rider: ${order.deliveryBoyName}', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.indigo)),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                      // Historical orders
                      completedOrders.isEmpty
                          ? const Center(child: Text('No historical orders found.', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: completedOrders.length,
                              itemBuilder: (context, index) {
                                final order = completedOrders[index];

                                return Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  margin: const EdgeInsets.only(bottom: 16.0),
                                  child: ListTile(
                                    title: Text('Order #${order.id.substring(0, 6).toUpperCase()}'),
                                    subtitle: Text('Customer: ${order.customerName}\nAmount: ₹${order.totalAmount.toStringAsFixed(1)} • ${order.paymentMethod}'),
                                    trailing: Text(
                                      order.status.toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(order.status),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
