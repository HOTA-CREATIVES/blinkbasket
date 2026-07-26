import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/status_chip.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../domain/entities/order.dart';
import 'task_detail_screen.dart';

class RiderMapScreen extends StatefulWidget {
  final bool isEmbedded;
  const RiderMapScreen({super.key, this.isEmbedded = false});

  @override
  State<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen> {
  Order? _selectedOrder;
  final MapController _mapController = MapController();

  // Bhimavaram centroid coordinates
  static const double _defaultLat = 16.5449;
  static const double _defaultLng = 81.5212;

  void _onMarkerTapped(Order order) {
    setState(() {
      _selectedOrder = order;
    });
    if (order.latitude != null && order.longitude != null) {
      _mapController.move(LatLng(order.latitude!, order.longitude!), 15.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Non-listening: user.uid only seeds the stream below, and the map's own
    // reactivity comes from that StreamBuilder, not from these providers.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final user = authProvider.currentUserModel;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Authentication error')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Active Deliveries Map',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        automaticallyImplyLeading: !widget.isEmbedded,
        leading: widget.isEmbedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: StreamBuilder<List<Order>>(
        stream: orderProvider.streamDeliveryBoyOrders(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          final activeOrders = snapshot.data
                  ?.where((o) =>
                      o.status != 'delivered' &&
                      o.status != 'cancelled' &&
                      o.latitude != null &&
                      o.longitude != null)
                  .toList() ??
              [];

          final markers = activeOrders.map((order) {
            final isSelected = _selectedOrder?.id == order.id;

            return Marker(
              point: LatLng(order.latitude!, order.longitude!),
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () => _onMarkerTapped(order),
                child: Icon(
                  Icons.location_pin,
                  color: isSelected ? Colors.orange.shade800 : Colors.orange.shade500,
                  size: isSelected ? 46 : 38,
                ),
              ),
            );
          }).toList();

          return Stack(
            children: [
              // Interactive Leaflet Map
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(_defaultLat, _defaultLng),
                  initialZoom: 14.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.hypermart',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

              // Bottom details card if an order marker is selected
              if (_selectedOrder != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: widget.isEmbedded ? 100 : 24,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${_selectedOrder!.id.substring(0, 6).toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              StatusChip(status: _selectedOrder!.status),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Text(
                                _selectedOrder!.customerName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${_selectedOrder!.deliveryAddress}, ${_selectedOrder!.village}',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.currency_rupee_rounded, size: 16, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                'Collect: ₹${_selectedOrder!.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => setState(() => _selectedOrder = null),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade600,
                                    side: BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTokens.rSm),
                                    ),
                                  ),
                                  child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    final selected = _selectedOrder!;
                                    setState(() => _selectedOrder = null);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TaskDetailScreen(order: selected),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: scheme.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTokens.rSm),
                                    ),
                                  ),
                                  child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
