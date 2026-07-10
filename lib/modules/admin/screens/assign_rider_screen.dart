import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/models/user_model.dart';

class AssignRiderScreen extends StatelessWidget {
  final String orderId;
  const AssignRiderScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Delivery Partner'),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: orderProvider.streamDeliveryBoys(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blue));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No delivery partners registered / whitelisted.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final riders = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: riders.length,
            itemBuilder: (context, index) {
              final rider = riders[index];

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 12.0),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.delivery_dining),
                  ),
                  title: Text(rider.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Phone: ${rider.phone}\nRegion: ${rider.village}'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      await orderProvider.assignRider(orderId, rider.uid, rider.name);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Assigned order to ${rider.name}!')),
                        );
                      }
                    },
                    child: const Text('ASSIGN'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
