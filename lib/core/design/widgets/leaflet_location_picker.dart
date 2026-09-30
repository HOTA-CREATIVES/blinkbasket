import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../domain/entities/service_zone.dart';
import '../../services/geocoding_service.dart';
import '../../utils/customer_helper.dart';
import '../app_tokens.dart';

/// Standard OpenStreetMap raster tiles — 100% free and open, zero API key required,
/// with high availability CDN and fallback to OSM Humanitarian tiles.
const _kTileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _kFallbackTileUrlTemplate = 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
const _kTileSubdomains = ['a', 'b', 'c'];

/// Sent to the tile server so it can identify (and contact) this app.
const _kUserAgentPackage = 'com.jcmart.app';

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return const RichAttributionWidget(
      alignment: AttributionAlignment.bottomRight,
      attributions: [
        TextSourceAttribution('© OpenStreetMap contributors'),
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
/// desired location — or searches for an address / landmark — then taps
/// "Confirm". The delivery zones are drawn on the map and the sheet says live
/// whether the pin is deliverable; Confirm stays disabled outside them.
/// Returns `(lat, lng)` via the [onConfirmed] callback.
///
/// Usage:
/// ```dart
/// LeafletLocationPicker.show(
///   context: context,
///   initialLat: 16.5449,
///   initialLng: 81.5212,
///   zones: configProvider.latestServiceZones,
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

  /// The delivery zones in force. Empty falls back to the built-in villages,
  /// the same fallback the rest of the app (and the server) uses.
  final List<ServiceZone> zones;

  /// Address search backend; the default calls the `searchAddress` function.
  final GeocodingService? geocoder;

  /// Overrides how map tiles are fetched (tests use a blank provider).
  @visibleForTesting
  final TileProvider? tileProvider;

  const LeafletLocationPicker({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialIsPinned = false,
    required this.onConfirmed,
    this.zones = const [],
    this.geocoder,
    this.tileProvider,
  });

  /// Convenience method to show the picker as a modal bottom sheet.
  static void show({
    required BuildContext context,
    required double initialLat,
    required double initialLng,
    bool initialIsPinned = false,
    required void Function(double lat, double lng) onConfirmed,
    List<ServiceZone> zones = const [],
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
        zones: zones,
      ),
    );
  }

  @override
  State<LeafletLocationPicker> createState() => _LeafletLocationPickerState();
}

class _LeafletLocationPickerState extends State<LeafletLocationPicker> {
  static const _searchDebounce = Duration(milliseconds: 400);
  static const _tileErrorsBeforeWarning = 4;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  late final GeocodingService _geocoder = widget.geocoder ?? GeocodingService();
  late final List<ServiceZone> _zones = CustomerHelper.effectiveZones(widget.zones);

  late double _selectedLat;
  late double _selectedLng;
  late bool _hasMoved = widget.initialIsPinned;

  Timer? _searchTimer;
  int _searchGeneration = 0;
  bool _isSearching = false;
  String? _searchError;
  List<PlaceSuggestion>? _results;
  int _tileErrors = 0;

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  ({String name, double distanceMeters, bool isInside}) get _zoneStatus =>
      CustomerHelper.nearestZone(_selectedLat, _selectedLng, _zones);

  void _onQueryChanged(String query) {
    _searchTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 3) {
      // Anything in flight is now stale.
      _searchGeneration++;
      setState(() {
        _results = null;
        _searchError = null;
        _isSearching = false;
      });
      return;
    }
    _searchTimer = Timer(_searchDebounce, () => _runSearch(trimmed));
  }

  Future<void> _runSearch(String query) async {
    final generation = ++_searchGeneration;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    final outcome = await _geocoder.search(query);
    // A newer keystroke superseded this search while it was in flight.
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _isSearching = false;
      _searchError = outcome.error;
      _results = outcome.isSuccess ? outcome.places : null;
    });
  }

  void _selectPlace(PlaceSuggestion place) {
    FocusScope.of(context).unfocus();
    _mapController.move(LatLng(place.lat, place.lng), 17);
    setState(() {
      _selectedLat = place.lat;
      _selectedLng = place.lng;
      _hasMoved = true;
      _results = null;
      _searchError = null;
      _searchController.text = place.label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final status = _zoneStatus;
    final canConfirm = _hasMoved && status.isInside;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: (media.size.height - media.viewInsets.bottom) * 0.75,
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
              const SizedBox(height: AppTokens.s8),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search your street or landmark',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onQueryChanged('');
                          },
                        ),
                ),
              ),
              const SizedBox(height: AppTokens.s8),
              Text(
                'Or drag the map to place the marker on your exact location.',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.s8),
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
                            fallbackUrl: _kFallbackTileUrlTemplate,
                            subdomains: _kTileSubdomains,
                            userAgentPackageName: _kUserAgentPackage,
                            tileProvider: widget.tileProvider,
                            maxZoom: 19,
                            errorTileCallback: (tile, error, stackTrace) {
                              // Count quietly; only warn once it is clearly
                              // more than a stray missing tile.
                              _tileErrors++;
                              if (_tileErrors == _tileErrorsBeforeWarning && mounted) {
                                setState(() {});
                              }
                            },
                          ),
                          CircleLayer(
                            circles: [
                              for (final z in _zones)
                                CircleMarker(
                                  point: LatLng(z.lat, z.lng),
                                  radius: z.radiusKm * 1000,
                                  useRadiusInMeter: true,
                                  color: scheme.primary.withValues(alpha: 0.06),
                                  borderColor: scheme.primary.withValues(alpha: 0.45),
                                  borderStrokeWidth: 1.5,
                                ),
                            ],
                          ),
                          const _MapAttribution(),
                        ],
                      ),
                      // Fixed center pin. Ignoring pointer events matters: the
                      // pin sits exactly where a drag tends to start, and if it
                      // took the touch the map would not pan.
                      IgnorePointer(
                        child: Center(
                          child: _TeardropPin(color: scheme.primary),
                        ),
                      ),
                      // Crosshair shadow for better visibility
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      if (_tileErrors >= _tileErrorsBeforeWarning)
                        Positioned(
                          left: AppTokens.s8,
                          right: AppTokens.s8,
                          bottom: AppTokens.s8,
                          child: _MapNotice(
                            icon: Icons.wifi_off_rounded,
                            text: "The map isn't loading. Check your connection, "
                                'or search for your address above.',
                            color: scheme.errorContainer,
                            onColor: scheme.onErrorContainer,
                          ),
                        ),
                      if (_isSearching ||
                          _searchError != null ||
                          (_results != null))
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _SearchResults(
                            isSearching: _isSearching,
                            error: _searchError,
                            places: _results,
                            onSelect: _selectPlace,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.s8),
              // Deliverability of the pin, live.
              Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.s12, vertical: AppTokens.s8),
                  decoration: BoxDecoration(
                    color: (status.isInside ? scheme.primaryContainer : scheme.errorContainer)
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppTokens.rSm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        status.isInside
                            ? Icons.check_circle_outline_rounded
                            : Icons.location_off_outlined,
                        size: 16,
                        color: status.isInside ? scheme.primary : scheme.error,
                      ),
                      const SizedBox(width: AppTokens.s8),
                      Flexible(
                        child: Text(
                          status.isInside
                              ? 'We deliver here (${status.name})'
                              : "We don't deliver to this spot yet",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: status.isInside
                                    ? scheme.onPrimaryContainer
                                    : scheme.onErrorContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.s12),
              // Confirm button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: !canConfirm
                      ? null
                      : () {
                          // Read the camera itself so the result is the pin's
                          // true position even if a fling is still settling.
                          final center = _mapController.camera.center;
                          widget.onConfirmed(center.latitude, center.longitude);
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(!_hasMoved
                      ? 'Move the map to your exact spot'
                      : !status.isInside
                          ? 'Move the pin inside the delivery area'
                          : 'Confirm Pinned Location'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppTokens.s16),
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

/// Address-search suggestions floating over the top of the map.
class _SearchResults extends StatelessWidget {
  final bool isSearching;
  final String? error;
  final List<PlaceSuggestion>? places;
  final ValueChanged<PlaceSuggestion> onSelect;

  const _SearchResults({
    required this.isSearching,
    required this.error,
    required this.places,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final places = this.places;

    Widget body;
    if (isSearching && (places == null || places.isEmpty)) {
      body = const Padding(
        padding: EdgeInsets.all(AppTokens.s16),
        child: Center(
          child: SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    } else if (error != null) {
      body = Padding(
        padding: const EdgeInsets.all(AppTokens.s16),
        child: Text(error!, style: TextStyle(color: scheme.error)),
      );
    } else if (places != null && places.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(AppTokens.s16),
        child: Text('No matches in our delivery area. Try a nearby landmark, or drag the map.'),
      );
    } else {
      body = ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: places?.length ?? 0,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final place = places![index];
          return ListTile(
            dense: true,
            leading: Icon(
              place.isDeliverable ? Icons.place_outlined : Icons.location_off_outlined,
              color: place.isDeliverable ? scheme.primary : scheme.onSurfaceVariant,
            ),
            title: Text(place.label, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: place.isDeliverable ? null : const Text('Outside our delivery area'),
            onTap: () => onSelect(place),
          );
        },
      );
    }

    return Material(
      elevation: 4,
      color: scheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: body,
      ),
    );
  }
}

/// A one-line notice over the map.
class _MapNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color onColor;

  const _MapNotice({
    required this.icon,
    required this.text,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.s8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTokens.rSm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: onColor),
          const SizedBox(width: AppTokens.s8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: onColor)),
          ),
        ],
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
                fallbackUrl: _kFallbackTileUrlTemplate,
                subdomains: _kTileSubdomains,
                userAgentPackageName: _kUserAgentPackage,
                maxZoom: 19,
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
