import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/status_chip.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/utils/route_generator.dart';
import '../../../domain/entities/order.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/utils/money.dart';

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
        title: Text(
          'Active Deliveries Map',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
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
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: scheme.primary));
          }
          if (snapshot.hasError) {
            return EmptyState.error(
              title: "Couldn't load your deliveries",
              message: userMessageFor(snapshot.error),
              onAction: () => orderProvider.retryDeliveryOrders(user.uid),
            );
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
                    fallbackUrl: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.jcmart.app',
                    maxZoom: 19,
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
                    color: scheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.s16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${_selectedOrder!.id.substring(0, 6).toUpperCase()}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              StatusChip(status: _selectedOrder!.status),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _selectedOrder!.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 16, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${_selectedOrder!.deliveryAddress}, ${_selectedOrder!.village}',
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.currency_rupee_rounded, size: 16, color: AppTokens.statusDelivered),
                              const SizedBox(width: 6),
                              Text(
                                'Collect: ${formatRupees(_selectedOrder!.totalAmount)}',
                                style: const TextStyle(
                                  color: AppTokens.statusDelivered,
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
                                    foregroundColor: scheme.onSurfaceVariant,
                                    side: BorderSide(color: scheme.outlineVariant),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTokens.rSm),
                                    ),
                                  ),
                                  child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: AppTokens.s12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    final selected = _selectedOrder!;
                                    setState(() => _selectedOrder = null);
                                    Navigator.pushNamed(
                                      context,
                                      RouteGenerator.taskDetail,
                                      arguments: selected,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: scheme.primary,
                                    foregroundColor: scheme.onPrimary,
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
