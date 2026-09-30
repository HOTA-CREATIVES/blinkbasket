import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/data/villages.dart';
import '../../../core/models/user_model.dart';
import '../../../core/design/widgets/leaflet_location_picker.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/customer_helper.dart';
import '../../../core/utils/phone.dart';
import '../widgets/custom_button.dart';
import '../widgets/village_dropdown.dart';

class CustomerProfileSetupScreen extends StatefulWidget {
  const CustomerProfileSetupScreen({super.key});

  @override
  State<CustomerProfileSetupScreen> createState() => _CustomerProfileSetupScreenState();
}

class _CustomerProfileSetupScreenState extends State<CustomerProfileSetupScreen> {
  int _currentStep = 1;
  final _step1FormKey = GlobalKey<FormState>();

  // Step 1 Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Step 2 Controllers
  final _villageController = TextEditingController();
  final _streetController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _landmarkController = TextEditingController();
  double? _latitude;
  double? _longitude;
  String? _detectedMandal;
  String? _detectedDistrict;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
      if (user != null) {
        if (user.name.isNotEmpty && _nameController.text.isEmpty) {
          _nameController.text = user.name;
        }
        if (user.phone.isNotEmpty && _phoneController.text.isEmpty) {
          _phoneController.text = user.phone;
        }
        if (user.village.isNotEmpty && _villageController.text.isEmpty) {
          _villageController.text = user.village;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    _streetController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? scheme.error : scheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  final GeocodingService _geocoder = GeocodingService();

  Future<void> _reverseGeocode(double lat, double lng) async {
    // Best effort: the village comes from the service zones (see
    // _acceptLocation); this only pre-fills the address form.
    final suggestion = await _geocoder.reverse(lat, lng);
    if (suggestion == null || !mounted) return;
    setState(() {
      if (suggestion.road.isNotEmpty && _streetController.text.trim().isEmpty) {
        _streetController.text = suggestion.road;
      }
      if (suggestion.mandal.isNotEmpty) _detectedMandal = suggestion.mandal;
      if (suggestion.district.isNotEmpty) _detectedDistrict = suggestion.district;
      if (suggestion.pincode.isNotEmpty) _pincodeController.text = suggestion.pincode;
    });
  }

  /// Checks a captured/pinned point against the admin service zones. Inside →
  /// stores it and autofills the village (the matching zone) and address
  /// details; outside → tells the user and stores nothing.
  Future<bool> _acceptLocation(double lat, double lng) async {
    final zones = Provider.of<ConfigProvider>(context, listen: false).latestServiceZones;
    final match = CustomerHelper.nearestZone(lat, lng, zones);
    if (!match.isInside) {
      if (mounted) _showSnackBar("Sorry, we don't deliver to this location yet.");
      return false;
    }
    if (!mounted) return false;
    setState(() {
      _latitude = lat;
      _longitude = lng;
      _villageController.text = match.name;
    });
    await _reverseGeocode(lat, lng);
    return true;
  }

  /// Fallback when GPS is denied/unavailable: drop a pin on the map instead.
  void _pinOnMap() {
    final zones = Provider.of<ConfigProvider>(context, listen: false).latestServiceZones;
    final center = _latitude != null && _longitude != null
        ? (lat: _latitude!, lng: _longitude!)
        : CustomerHelper.centerOf(_villageController.text.trim(), zones);
    LeafletLocationPicker.show(
      context: context,
      initialLat: center.lat,
      initialLng: center.lng,
      initialIsPinned: _latitude != null,
      zones: zones,
      onConfirmed: (lat, lng) => _acceptLocation(lat, lng),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    final result = await LocationService.currentFix();
    final fix = result.fix;
    if (fix == null) {
      if (!mounted) return;
      setState(() => _isLocating = false);
      // Explain what went wrong and, when only a system setting can fix it,
      // offer the shortcut there. The map pin button stays as the fallback.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          action: result.canOpenSettings
              ? SnackBarAction(label: 'Settings', onPressed: result.openSettings)
              : result.canRetry
                  ? SnackBarAction(label: 'Try again', onPressed: _getCurrentLocation)
                  : null,
        ),
      );
      return;
    }

    final accepted = await _acceptLocation(fix.latitude, fix.longitude);

    if (!mounted) return;
    setState(() => _isLocating = false);

    if (accepted) _showSnackBar('Location set. Check the address details below.', isError: false);
  }

  void _goToStep2() {
    if (!_step1FormKey.currentState!.validate()) return;
    setState(() => _currentStep = 2);
  }

  Future<void> _submitProfile() async {
    if (_streetController.text.trim().isEmpty) {
      _showSnackBar('Please enter your street address / house number');
      return;
    }
    final lat = _latitude;
    final lng = _longitude;
    if (lat == null || lng == null) {
      _showSnackBar('Please use your GPS location or pin it on the map so the rider can find you');
      return;
    }
    // The village of record comes from where the customer actually is (the
    // admin service zones), not from whatever text was typed or geocoded.
    final zones = Provider.of<ConfigProvider>(context, listen: false).latestServiceZones;
    final match = CustomerHelper.nearestZone(lat, lng, zones);
    if (!match.isInside) {
      _showSnackBar("Sorry, we don't deliver to this location yet.");
      return;
    }
    final village = match.name;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final villageMeta = Villages.byName(village);
    final mandal = _detectedMandal ?? villageMeta?.mandal ?? '';
    final district = _detectedDistrict ?? villageMeta?.district ?? '';
    final zoneId = villageMeta?.deliveryZoneId ?? Villages.defaultZoneId;
    final fallbackPin = villageMeta?.defaultPincode ?? '';

    final defaultAddress = AddressModel(
      id: 'addr_default_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      addressLine1: _streetController.text.trim(),
      pinCode: _pincodeController.text.trim().isEmpty ? fallbackPin : _pincodeController.text.trim(),
      village: village,
      mandal: mandal,
      district: district,
      landmark: _landmarkController.text.trim().isEmpty ? null : _landmarkController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      isDefault: true,
    );

    final success = await authProvider.setupCustomerProfile(
      name: _nameController.text.trim(),
      phone: normalizeIndianMobile(_phoneController.text) ?? _phoneController.text.trim(),
      village: village,
      mandal: mandal,
      district: district,
      deliveryZoneId: zoneId,
      defaultAddress: defaultAddress,
    );

    // On success the auth state changes and AuthWrapper replaces this screen
    // with the home screen, so there is nothing more to show here.
    if (!success) {
      _showSnackBar(authProvider.errorMessage ?? "Couldn't save your details. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Set up your account · Step $_currentStep of 2'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: scheme.error),
            tooltip: 'Sign Out',
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).logout();
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Linear Progress Indicator
            LinearProgressIndicator(
              value: _currentStep / 2,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
              minHeight: 6,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: _buildCurrentStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Form();
      default:
        return _buildStep2Form();
    }
  }

  // STEP 1: Personal Info (Name & Phone)
  Widget _buildStep1Form() {
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.person_pin_rounded,
            size: 80,
            color: scheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Your details',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your rider will use this number to reach you when your order arrives.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Mobile Phone Number',
              prefixIcon: const Icon(Icons.phone_android_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              hintText: 'e.g. 9876543210',
            ),
            validator: validateIndianMobile,
          ),
          const SizedBox(height: 36),

          CustomButton(
            text: 'Continue',
            backgroundColor: scheme.primary,
            onPressed: _goToStep2,
          ),
        ],
      ),
    );
  }

  // STEP 2: Location Coordinates & Address Edit
  Widget _buildStep2Form() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.location_on_rounded,
          size: 80,
          color: scheme.primary,
        ),
        const SizedBox(height: 16),
          Text(
            'Delivery location',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Use your current location, search for your street, or pin it on the map so the rider can find you.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 24),

        // Fetch GPS Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: scheme.primary, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: _isLocating
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.my_location, color: scheme.primary),
          label: Text(
            _isLocating
                ? 'Fetching Location...'
                : (_latitude != null ? 'Location set · ${_villageController.text}' : 'Use my current location'),
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold),
          ),
          onPressed: _isLocating ? null : _getCurrentLocation,
        ),
        TextButton.icon(
          onPressed: _pinOnMap,
          icon: const Icon(Icons.pin_drop_outlined),
          label: Text(_latitude != null ? 'Adjust on the map' : 'Search or pin on the map'),
        ),
        const SizedBox(height: 12),

        // Village is one of the admin-configured delivery zones — never free
        // text — so it always matches rider routing and the service area.
        VillageDropdown(
          value: _villageController.text.isEmpty ? null : _villageController.text,
          zoneNames: Provider.of<ConfigProvider>(context, listen: false)
              .latestServiceZones
              .map((z) => z.name)
              .toList(),
          onChanged: (v) {
            setState(() {
              _villageController.text = v ?? '';
              // A pin captured in a different village is stale now.
              final lat = _latitude;
              final lng = _longitude;
              if (v != null && lat != null && lng != null) {
                final zones = Provider.of<ConfigProvider>(context, listen: false).latestServiceZones;
                if (CustomerHelper.nearestZone(lat, lng, zones).name != v) {
                  _latitude = null;
                  _longitude = null;
                }
              }
            });
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _streetController,
          decoration: InputDecoration(
            labelText: 'Street Address / House No.',
            prefixIcon: const Icon(Icons.home_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _pincodeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Pincode',
                  prefixIcon: const Icon(Icons.pin_drop_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Mandal / District',
                  prefixIcon: const Icon(Icons.map_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: scheme.outlineVariant, width: 1.0),
                  ),
                ),
                child: Text(
                  () {
                    final vText = _villageController.text.trim();
                    final meta = Villages.byName(vText);
                    final m = _detectedMandal ?? meta?.mandal ?? (vText.isNotEmpty ? '—' : '');
                    final d = _detectedDistrict ?? meta?.district ?? '';
                    if (m.isEmpty && d.isEmpty) return '— / —';
                    return '${m.isNotEmpty ? m : '—'} / ${d.isNotEmpty ? d : '—'}';
                  }(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _landmarkController,
          decoration: InputDecoration(
            labelText: 'Landmark (Optional)',
            prefixIcon: const Icon(Icons.place_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 28),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                onPressed: () => setState(() => _currentStep = 1),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: CustomButton(
                text: 'Save and finish',
                backgroundColor: scheme.primary,
                isLoading: Provider.of<AuthProvider>(context).isLoading,
                onPressed: _submitProfile,
              ),
            ),
          ],
        )
      ],
    );
  }
}
