import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app_tokens.dart';

/// A reusable Leaflet-based map picker shown as a modal bottom sheet.
///
/// The user drags the map so the fixed center-screen pin lands on their
/// desired location, then taps "Confirm". Returns `(lat, lng)` via the
/// [onConfirmed] callback, or `null` if dismissed.
///
/// Usage:
/// ```dart
/// LeafletLocationPicker.show(
///   context: context,
///   initialLat: 16.5449,
///   initialLng: 81.5212,
///   onConfirmed: (lat, lng) { /* use coordinates */ },
/// );
/// ```
class LeafletLocationPicker extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final void Function(double lat, double lng) onConfirmed;

  const LeafletLocationPicker({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.onConfirmed,
  });

  /// Convenience method to show the picker as a modal bottom sheet.
  static void show({
    required BuildContext context,
    required double initialLat,
    required double initialLng,
    required void Function(double lat, double lng) onConfirmed,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.rXl)),
      ),
      builder: (_) => LeafletLocationPicker(
        initialLat: initialLat,
        initialLng: initialLng,
        onConfirmed: onConfirmed,
      ),
    );
  }

  @override
  State<LeafletLocationPicker> createState() => _LeafletLocationPickerState();
}

class _LeafletLocationPickerState extends State<LeafletLocationPicker> {
  late double _selectedLat;
  late double _selectedLng;

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppTokens.s16, 0, AppTokens.s16, AppTokens.s16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pinpoint on Map',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppTokens.s4),
            Text(
              'Drag the map to center the red marker on your exact location.',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.s12),
            // Map
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.rLg),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter:
                            LatLng(widget.initialLat, widget.initialLng),
                        initialZoom: 16.0,
                        onPositionChanged: (position, hasGesture) {
                          if (hasGesture) {
                            setState(() {
                              _selectedLat = position.center.latitude;
                              _selectedLng = position.center.longitude;
                            });
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.hypermart',
                        ),
                      ],
                    ),
                    // Fixed center pin
                    const Center(
                      child: Icon(Icons.location_pin,
                          color: AppTokens.statusCancelled, size: 44),
                    ),
                    // Crosshair shadow for better visibility
                    Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTokens.s12),
            // Coordinate readout
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.s12, vertical: AppTokens.s8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTokens.rSm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.my_location_rounded,
                      size: 14, color: scheme.primary),
                  const SizedBox(width: AppTokens.s8),
                  Text(
                    '${_selectedLat.toStringAsFixed(6)}, ${_selectedLng.toStringAsFixed(6)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.s12),
            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onConfirmed(_selectedLat, _selectedLng);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Confirm Pinned Location',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTokens.s16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small, non-interactive map preview widget that displays a single marker.
///
/// Used in the cart screen and order tracking to show the pinned
/// delivery location at a glance.
class LeafletLocationPreview extends StatelessWidget {
  final double latitude;
  final double longitude;
  final double height;

  const LeafletLocationPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.rMd),
      child: SizedBox(
        height: height,
        child: AbsorbPointer(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(latitude, longitude),
              initialZoom: 15.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.hypermart',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(latitude, longitude),
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_pin,
                      color: AppTokens.statusCancelled,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
