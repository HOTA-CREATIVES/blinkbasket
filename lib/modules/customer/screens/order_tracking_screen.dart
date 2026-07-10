import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../../domain/entities/order.dart';
import '../../../data/models/order_dto.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  int _getStatusStep(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'assigned':
        return 1;
      case 'picked_up':
        return 2;
      case 'out_for_delivery':
        return 3;
      case 'delivered':
        return 4;
      case 'cancelled':
        return -1;
      default:
        return 0;
    }
  }

  Widget _buildStepTile({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? Colors.green
                    : isActive
                        ? Colors.blue
                        : Colors.grey.shade300,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : isActive
                      ? const Icon(Icons.radio_button_checked, size: 16, color: Colors.white)
                      : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 48,
                color: isCompleted ? Colors.green : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isActive || isCompleted ? Colors.black87 : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Order'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order details not found.'));
          }

          final order = OrderDto.fromMap(snapshot.data!.data() as Map<String, dynamic>, snapshot.data!.id);
          final step = _getStatusStep(order.status);

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              // Order Header card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order #${order.id.substring(0, 6).toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'COD Total: ₹${order.totalAmount.toStringAsFixed(1)}',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          Icon(
                            order.status == 'delivered'
                                ? Icons.task_alt
                                : order.status == 'cancelled'
                                    ? Icons.cancel_outlined
                                    : Icons.local_shipping_outlined,
                            size: 48,
                            color: order.status == 'delivered'
                                ? Colors.green
                                : order.status == 'cancelled'
                                    ? Colors.red
                                    : Colors.green,
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        'Delivery to: ${order.deliveryAddress}, ${order.village}',
                        style: const TextStyle(color: Colors.grey, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tracking steps
              if (order.status == 'cancelled') ...[
                Card(
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  child: const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This order has been cancelled.',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      _buildStepTile(
                        title: 'Order Placed',
                        subtitle: 'We have received your order',
                        isCompleted: step > 0,
                        isActive: step == 0,
                        isLast: false,
                      ),
                      _buildStepTile(
                        title: 'Rider Assigned',
                        subtitle: order.deliveryBoyName != null
                            ? 'Assigned to partner: ${order.deliveryBoyName}'
                            : 'Waiting to assign a delivery partner',
                        isCompleted: step > 1,
                        isActive: step == 1,
                        isLast: false,
                      ),
                      _buildStepTile(
                        title: 'Picked Up',
                        subtitle: 'Rider has picked up items from store',
                        isCompleted: step > 2,
                        isActive: step == 2,
                        isLast: false,
                      ),
                      _buildStepTile(
                        title: 'Out for Delivery',
                        subtitle: 'Rider is on the way to your door',
                        isCompleted: step > 3,
                        isActive: step == 3,
                        isLast: false,
                      ),
                      _buildStepTile(
                        title: 'Delivered',
                        subtitle: 'Payment verified and items received',
                        isCompleted: step > 4,
                        isActive: step == 4,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Items details card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Items Ordered',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ...order.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item.quantity}x ${item.name}', style: const TextStyle(fontSize: 15)),
                              Text('₹${(item.price * item.quantity).toStringAsFixed(1)}'),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }
}
