import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../domain/entities/order.dart';

class DeliveryHomeScreen extends StatelessWidget {
  const DeliveryHomeScreen({super.key});

  String _getNextStatusText(String currentStatus) {
    switch (currentStatus) {
      case 'assigned':
        return 'PICK UP ITEMS';
      case 'picked_up':
        return 'START DELIVERY';
      case 'out_for_delivery':
        return 'MARK DELIVERED & COLLECT COD';
      default:
        return 'DONE';
    }
  }

  String _getNextStatusValue(String currentStatus) {
    switch (currentStatus) {
      case 'assigned':
        return 'picked_up';
      case 'picked_up':
        return 'out_for_delivery';
      case 'out_for_delivery':
        return 'delivered';
      default:
        return 'delivered';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.orange;
      case 'picked_up':
        return Colors.blue;
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
    final user = authProvider.currentUserModel;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Partner Panel', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            if (user != null)
              Text(
                'Rider: ${user.name}',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.logout();
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Authentication error.'))
          : StreamBuilder<List<Order>>(
              stream: orderProvider.streamDeliveryBoyOrders(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No orders assigned to you yet.', style: TextStyle(color: Colors.grey)),
                  );
                }

                // Filter out delivered or cancelled orders to show only active tasks
                final activeOrders = snapshot.data!
                    .where((order) => order.status != 'delivered' && order.status != 'cancelled')
                    .toList();

                final completedOrders = snapshot.data!
                    .where((order) => order.status == 'delivered' || order.status == 'cancelled')
                    .toList();

                return DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        indicatorColor: Colors.orange,
                        labelColor: Colors.orange,
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          Tab(text: 'Active Tasks'),
                          Tab(text: 'Completed Runs'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Active tasks tab
                            activeOrders.isEmpty
                                ? const Center(
                                    child: Text('All caught up! No active tasks.', style: TextStyle(color: Colors.grey)),
                                  )
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
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(order.status).withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      order.status.toUpperCase(),
                                                      style: TextStyle(
                                                        color: _getStatusColor(order.status),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Divider(),
                                              Text('Customer: ${order.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text('Phone: ${order.customerPhone}', style: const TextStyle(color: Colors.blue)),
                                              const SizedBox(height: 4),
                                              Text('Address: ${order.deliveryAddress}, ${order.village}', style: const TextStyle(color: Colors.black54)),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Collect Cash: ₹${order.totalAmount.toStringAsFixed(1)} (COD)',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
                                              ),
                                              const SizedBox(height: 16),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: _getStatusColor(_getNextStatusValue(order.status)),
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                  ),
                                                  onPressed: () async {
                                                    final nextStatus = _getNextStatusValue(order.status);
                                                    await orderProvider.updateStatus(order.id, nextStatus);
                                                  },
                                                  child: Text(
                                                    _getNextStatusText(order.status),
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                            // Completed runs tab
                            completedOrders.isEmpty
                                ? const Center(
                                    child: Text('No runs completed yet.', style: TextStyle(color: Colors.grey)),
                                  )
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
                                          subtitle: Text('Customer: ${order.customerName}\nTotal: ₹${order.totalAmount.toStringAsFixed(1)} (COD)'),
                                          trailing: Icon(
                                            order.status == 'delivered' ? Icons.check_circle : Icons.cancel,
                                            color: order.status == 'delivered' ? Colors.green : Colors.red,
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
