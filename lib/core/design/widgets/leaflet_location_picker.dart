import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../app_tokens.dart';

/// Free, no-API-key CartoDB Voyager tiles — a more polished/legible look
/// than plain OpenStreetMap raster tiles at zero cost. CartoDB's free tier
/// asks for attribution, added below each map via [_MapAttribution].
const _kTileUrlTemplate = 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
const _kTileSubdomains = ['a', 'b', 'c', 'd'];

/// Sent to the tile server so it can identify (and contact) this app. Must be
/// the real application id — it was the `com.example` placeholder.
const _kUserAgentPackage = 'com.jcmart.app';

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return const RichAttributionWidget(
      alignment: AttributionAlignment.bottomRight,
      attributions: [
        TextSourceAttribution('© OpenStreetMap contributors © CARTO'),
      ],
    );
  }
}

/// Small brand-colored teardrop map marker, replacing the generic Material
/// `Icons.location_pin` so pins read as "J C Mart" rather than a stock icon.
class _TeardropPin extends StatelessWidget {
  final Color color;
  final double size;

  const _TeardropPin({required this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.3),
      painter: _TeardropPainter(color: color),
    );
  }
}

class _TeardropPainter extends CustomPainter {
  final Color color;
  const _TeardropPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final radius = w / 2;
    final center = Offset(w / 2, radius);

    final path = Path()
      ..moveTo(w / 2, size.height)
      ..quadraticBezierTo(0, radius * 1.4, 0, radius)
      ..arcToPoint(Offset(w, radius), radius: Radius.circular(radius), clockwise: true)
      ..quadraticBezierTo(w, radius * 1.4, w / 2, size.height)
      ..close();

    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(center, radius * 0.35, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TeardropPainter oldDelegate) => oldDelegate.color != color;
}

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

  /// True when [initialLat]/[initialLng] is a location the customer already
  /// pinned/saved. When false they're just a map-centering default (e.g. the
  /// village centre), so Confirm stays disabled until the map is moved —
  /// otherwise a bare "Confirm" would submit the default as a real pin.
  final bool initialIsPinned;
  final void Function(double lat, double lng) onConfirmed;

  const LeafletLocationPicker({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialIsPinned = false,
    required this.onConfirmed,
  });

  /// Convenience method to show the picker as a modal bottom sheet.
  static void show({
    required BuildContext context,
    required double initialLat,
    required double initialLng,
    bool initialIsPinned = false,
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
        initialIsPinned: initialIsPinned,
        onConfirmed: onConfirmed,
      ),
    );
  }

  @override
  State<LeafletLocationPicker> createState() => _LeafletLocationPickerState();
}

class _LeafletLocationPickerState extends State<LeafletLocationPicker> {
  final MapController _mapController = MapController();
  late double _selectedLat;
  late double _selectedLng;
  late bool _hasMoved = widget.initialIsPinned;

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
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
              'Drag the map to center the marker on your exact location.',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
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
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter:
                            LatLng(widget.initialLat, widget.initialLng),
                        initialZoom: 16.0,
                        // Track every camera change, not just gesture-driven
                        // ones — fling/inertia frames report hasGesture=false
                        // and would otherwise leave a stale selection.
                        onPositionChanged: (position, hasGesture) {
                          setState(() {
                            _selectedLat = position.center.latitude;
                            _selectedLng = position.center.longitude;
                            if (hasGesture) _hasMoved = true;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _kTileUrlTemplate,
                          subdomains: _kTileSubdomains,
                          userAgentPackageName: _kUserAgentPackage,
                        ),
                        const _MapAttribution(),
                      ],
                    ),
                    // Fixed center pin
                    Center(
                      child: _TeardropPin(color: scheme.primary),
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
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.s12),
            // Confirm button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: !_hasMoved
                    ? null
                    : () {
                        // Read the camera itself so the result is the pin's
                        // true position even if a fling is still settling.
                        final center = _mapController.camera.center;
                        widget.onConfirmed(center.latitude, center.longitude);
                        Navigator.pop(context);
                      },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(_hasMoved
                    ? 'Confirm Pinned Location'
                    : 'Move the map to your exact spot'),
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
    final scheme = Theme.of(context).colorScheme;
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
                urlTemplate: _kTileUrlTemplate,
                subdomains: _kTileSubdomains,
                userAgentPackageName: _kUserAgentPackage,
              ),
              const _MapAttribution(),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(latitude, longitude),
                    width: 36,
                    height: 47,
                    alignment: Alignment.bottomCenter,
                    child: _TeardropPin(color: scheme.primary, size: 36),
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
