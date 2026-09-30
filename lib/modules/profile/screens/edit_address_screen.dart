import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../../core/models/user_model.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/customer_helper.dart';
import '../../../core/design/app_tokens.dart';
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

  Future<void> _fetchLiveLocation() async {
    // Read from the widget tree before any await, then use the captured value
    // across async gaps (avoids use_build_context_synchronously).
    final liveZones =
        Provider.of<ConfigProvider>(context, listen: false).latestServiceZones;
    setState(() {
      _isLocationLoading = true;
      _locationError = null;
      _failedFix = null;
    });
    try {
      final fixResult = await LocationService.currentFix();
      final fix = fixResult.fix;
      if (fix == null) {
        if (mounted) setState(() => _failedFix = fixResult);
        throw fixResult.message;
      }

      final lat = fix.latitude;
      final lng = fix.longitude;

      // Zone membership comes from the coordinates (admin zones), not from
      // fuzzy-matching Nominatim's free text — that matched the FIRST zone
      // whenever the geocoder returned no village name.
      final zoneMatch = CustomerHelper.nearestZone(lat, lng, liveZones);
      if (!zoneMatch.isInside) {
        throw "Sorry, we don't deliver to this location yet.";
      }
      // Keep the GPS fix even if the reverse-geocode below fails.
      if (mounted) {
        setState(() {
          _latitudeVal = lat;
          _longitudeVal = lng;
          _selectedVillage = zoneMatch.name;
        });
      }

      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'jc_mart_app'}).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw 'Connection timed out. Please check your network speed.',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final road = address['road'] ?? address['suburb'] ?? address['neighbourhood'] ?? '';
        final mandalName = address['county'] ?? address['state_district'] ?? '';
        final postcode = address['postcode'] ?? '';

        if (!mounted) return;
        setState(() {
          if (road.toString().isNotEmpty) {
            _addressController.text = road.toString();
          }
          if (mandalName.toString().isNotEmpty) {
            _mandalController.text = mandalName.toString();
          }
          if (postcode.toString().isNotEmpty) {
            _pinCodeController.text = postcode.toString();
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location updated & auto-filled.")),
          );
        }
      } else {
        throw 'Location saved, but address details could not be fetched — please fill them in.';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
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
