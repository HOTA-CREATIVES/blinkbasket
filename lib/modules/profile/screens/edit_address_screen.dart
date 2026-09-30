import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/customer_helper.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/leaflet_location_picker.dart';
import '../../auth/widgets/village_dropdown.dart';

class EditAddressScreen extends StatefulWidget {
  final AddressModel address;
  const EditAddressScreen({super.key, required this.address});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _pinCodeController;
  late TextEditingController _mandalController;
  late TextEditingController _landmarkController;
  String? _selectedVillage;

  bool _isLocationLoading = false;
  bool _isSaving = false;
  double? _latitudeVal;
  double? _longitudeVal;
  String? _locationError;
  LocationResult? _failedFix; // set when GPS failed for a fixable reason

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.address.name);
    _addressController = TextEditingController(text: widget.address.addressLine1);
    _pinCodeController = TextEditingController(text: widget.address.pinCode);
    _mandalController = TextEditingController(text: widget.address.mandal);
    _landmarkController = TextEditingController(text: widget.address.landmark ?? '');
    _selectedVillage = widget.address.village;
    _latitudeVal = widget.address.latitude;
    _longitudeVal = widget.address.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _pinCodeController.dispose();
    _mandalController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  /// GPS: take a fix, then handle it like any other chosen point.
  Future<void> _fetchLiveLocation() async {
    setState(() {
      _isLocationLoading = true;
      _locationError = null;
      _failedFix = null;
    });
    final fixResult = await LocationService.currentFix();
    final fix = fixResult.fix;
    if (fix == null) {
      if (!mounted) return;
      setState(() {
        _isLocationLoading = false;
        _failedFix = fixResult;
        _locationError = fixResult.message;
      });
      return;
    }
    await _applyPoint(fix.latitude, fix.longitude);
  }

  /// Map / search: the alternative when GPS is off, denied or inaccurate. The
  /// picker itself limits the pin to the delivery area.
  void _pinOnMap() {
    final zones =
        Provider.of<ConfigProvider>(context, listen: false).latestServiceZones;
    final hasPin = _latitudeVal != null && _longitudeVal != null;
    final centre = hasPin
        ? (lat: _latitudeVal!, lng: _longitudeVal!)
        : CustomerHelper.centerOf(_selectedVillage, zones);
    LeafletLocationPicker.show(
      context: context,
      initialLat: centre.lat,
      initialLng: centre.lng,
      initialIsPinned: hasPin,
      zones: zones,
      onConfirmed: (lat, lng) {
        setState(() {
          _isLocationLoading = true;
          _locationError = null;
          _failedFix = null;
        });
        _applyPoint(lat, lng);
      },
    );
  }

  /// Adopts a point (from GPS or the map): checks it against the delivery
  /// zones, sets the village from them, and pre-fills the address form.
  Future<void> _applyPoint(double lat, double lng) async {
    if (!mounted) return;
    final zones =
        Provider.of<ConfigProvider>(context, listen: false).latestServiceZones;
    // Zone membership comes from the coordinates (admin zones), not from
    // fuzzy-matching geocoder text.
    final zone = CustomerHelper.nearestZone(lat, lng, zones);
    if (!zone.isInside) {
      setState(() {
        _isLocationLoading = false;
        _locationError = "Sorry, we don't deliver to this location yet.";
      });
      return;
    }
    // Keep the point even if the address lookup below fails.
    setState(() {
      _latitudeVal = lat;
      _longitudeVal = lng;
      _selectedVillage = zone.name;
    });

    final suggestion = await GeocodingService().reverse(lat, lng);
    if (!mounted) return;
    setState(() {
      _isLocationLoading = false;
      if (suggestion == null) {
        _locationError =
            'Location saved, but address details could not be fetched — please fill them in.';
        return;
      }
      if (suggestion.road.isNotEmpty) _addressController.text = suggestion.road;
      if (suggestion.mandal.isNotEmpty) _mandalController.text = suggestion.mandal;
      if (suggestion.pincode.isNotEmpty) _pinCodeController.text = suggestion.pincode;
    });
    if (suggestion != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location updated & auto-filled.")),
      );
    }
  }

  Future<void> _updateAddress() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate() || _selectedVillage == null) {
      if (_selectedVillage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a village")),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final updatedAddress = AddressModel(
      id: widget.address.id,
      name: _nameController.text.trim(),
      addressLine1: _addressController.text.trim(),
      pinCode: _pinCodeController.text.trim(),
      village: _selectedVillage!,
      mandal: _mandalController.text.trim(),
      landmark: _landmarkController.text.isNotEmpty ? _landmarkController.text.trim() : null,
      latitude: _latitudeVal,
      longitude: _longitudeVal,
    );

    final success = await profileProvider.updateAddress(updatedAddress);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Address updated successfully."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text("Edit Address", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.s20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live Location Trigger Button
                ElevatedButton.icon(
                  onPressed: _isLocationLoading ? null : _fetchLiveLocation,
                  icon: _isLocationLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(scheme.primary),
                          ),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(_isLocationLoading ? 'Fetching Live Location...' : 'Use Current Live Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.primary.withValues(alpha: 0.08),
                    foregroundColor: scheme.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                      side: BorderSide(color: AppTokens.primary.withValues(alpha: 0.15)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: _isLocationLoading ? null : _pinOnMap,
                    icon: const Icon(Icons.pin_drop_outlined, size: 18),
                    label: const Text('Search or pin on the map'),
                  ),
                ),
                const SizedBox(height: AppTokens.s12),

                // Location Fetch Coordinates Status
                if (_latitudeVal != null && _longitudeVal != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTokens.s12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.gps_fixed_rounded, size: 14, color: scheme.primary),
                        const SizedBox(width: AppTokens.s8),
                        Text(
                          'Captured Coordinates: ${_latitudeVal!.toStringAsFixed(6)}, ${_longitudeVal!.toStringAsFixed(6)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.s16),
                ],

                // Location Fetch Errors
                if (_locationError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTokens.s12),
                    decoration: BoxDecoration(
                      color: scheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                      border: Border.all(color: scheme.error.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _locationError!,
                          style: TextStyle(color: scheme.error, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        if (_failedFix?.canOpenSettings ?? false)
                          TextButton(
                            onPressed: _failedFix!.openSettings,
                            child: const Text('Open settings'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.s16),
                ],

                // Form Field: Name/Label
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Address Title (e.g. Home, Work)",
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? "Title is required" : null,
                ),
                const SizedBox(height: AppTokens.s16),

                // Form Field: Address Line 1
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: "Address Line 1 (House No., Street)",
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? "Address Line 1 is required" : null,
                ),
                const SizedBox(height: AppTokens.s16),

                // Form Field: Village / Zone Dropdown — uses live zones from Firestore
                Builder(builder: (context) {
                  final liveZones = Provider.of<ConfigProvider>(context,
                          listen: false)
                      .latestServiceZones;
                  final zoneNames = liveZones.isNotEmpty
                      ? liveZones.map((z) => z.name).toList()
                      : null;
                  return VillageDropdown(
                    value: _selectedVillage,
                    onChanged: (v) => setState(() => _selectedVillage = v),
                    zoneNames: zoneNames,
                  );
                }),
                const SizedBox(height: AppTokens.s16),

                // Form Field: Mandal
                TextFormField(
                  controller: _mandalController,
                  decoration: const InputDecoration(
                    labelText: "Mandal",
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? "Mandal is required" : null,
                ),
                const SizedBox(height: AppTokens.s16),

                // Row: Pincode and Landmark
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pinCodeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Pincode",
                          prefixIcon: Icon(Icons.pin_drop_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Required";
                          if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(v.trim())) {
                            return "Enter a valid 6-digit pincode";
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppTokens.s12),
                    Expanded(
                      child: TextFormField(
                        controller: _landmarkController,
                        decoration: const InputDecoration(
                          labelText: "Landmark (Opt)",
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.s32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _updateAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: AppTokens.s16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: scheme.onPrimary),
                        )
                      : const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
