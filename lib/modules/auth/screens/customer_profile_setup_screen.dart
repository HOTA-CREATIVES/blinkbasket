import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
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
  final _streetController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _landmarkController = TextEditingController();
  String? _selectedVillage;
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUserModel;
      if (user != null) {
        if (user.name.isNotEmpty && _nameController.text.isEmpty) {
          _nameController.text = user.name;
        }
        if (user.phone.isNotEmpty && _phoneController.text.isEmpty) {
          _phoneController.text = user.phone;
        }
        if (user.village.isNotEmpty && _selectedVillage == null) {
          _selectedVillage = user.village;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled. Please turn on GPS.');
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permission denied.');
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permission permanently denied. Enable in Settings.');
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        if (_pincodeController.text.isEmpty) {
          _pincodeController.text = '534198'; // Default area pincode
        }
        _isLocating = false;
      });

      _showSnackBar('Coordinates fetched successfully!', isError: false);
    } catch (e) {
      setState(() => _isLocating = false);
      _showSnackBar('Failed to fetch location: $e');
    }
  }

  void _goToStep2() {
    if (!_step1FormKey.currentState!.validate()) return;
    setState(() => _currentStep = 2);
  }

  Future<void> _submitProfileAndGoToStep3() async {
    if (_selectedVillage == null || _selectedVillage!.isEmpty) {
      _showSnackBar('Please select your village');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final defaultAddress = AddressModel(
      id: 'addr_default_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      addressLine1: _streetController.text.trim().isEmpty ? 'Main Road' : _streetController.text.trim(),
      pinCode: _pincodeController.text.trim().isEmpty ? '534198' : _pincodeController.text.trim(),
      village: _selectedVillage!,
      mandal: 'Undi',
      district: 'West Godavari',
      landmark: _landmarkController.text.trim().isEmpty ? null : _landmarkController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      isDefault: true,
    );

    final success = await authProvider.setupCustomerProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      village: _selectedVillage!,
      mandal: 'Undi',
      district: 'West Godavari',
      defaultAddress: defaultAddress,
    );

    if (success) {
      setState(() => _currentStep = 3);
    } else {
      _showSnackBar(authProvider.errorMessage ?? 'Failed to save onboarding profile.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Customer Onboarding (Step $_currentStep of 3)'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
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
              value: _currentStep / 3,
              backgroundColor: Colors.grey.shade200,
              color: AppColors.primary,
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
      case 2:
        return _buildStep2Form();
      case 3:
      default:
        return _buildStep3KeepShopping();
    }
  }

  // STEP 1: Personal Info (Name & Phone)
  Widget _buildStep1Form() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.person_pin_rounded,
            size: 80,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Step 1: Personal Details',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Please provide your full name and contact number for seamless delivery updates.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
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
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter mobile number';
              if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(val.trim())) {
                return 'Enter valid 10-digit mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 36),

          CustomButton(
            text: 'Next: Location Setup',
            backgroundColor: AppColors.primary,
            onPressed: _goToStep2,
          ),
        ],
      ),
    );
  }

  // STEP 2: Location Coordinates & Address Edit
  Widget _buildStep2Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.location_on_rounded,
          size: 80,
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),
        const Text(
          'Step 2: Delivery Location',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Autofill coordinates or edit your address to ensure accurate quick-commerce delivery.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Fetch GPS Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: _isLocating
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location, color: AppColors.primary),
          label: Text(
            _isLocating
                ? 'Fetching Location...'
                : (_latitude != null ? 'Location Captured (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})' : 'Use Current GPS Location'),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          onPressed: _isLocating ? null : _getCurrentLocation,
        ),
        const SizedBox(height: 20),

        VillageDropdown(
          value: _selectedVillage,
          onChanged: (val) => setState(() => _selectedVillage = val),
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
              child: TextFormField(
                initialValue: 'Undi / W.Godavari',
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Mandal/District',
                  prefixIcon: const Icon(Icons.map_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
                text: 'Save & Continue',
                backgroundColor: AppColors.primary,
                isLoading: Provider.of<AuthProvider>(context).isLoading,
                onPressed: _submitProfileAndGoToStep3,
              ),
            ),
          ],
        )
      ],
    );
  }

  // STEP 3: Keep Shopping Screen & Redirection
  Widget _buildStep3KeepShopping() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Container(
          height: 140,
          width: 140,
          decoration: const BoxDecoration(
            color: AppColors.greenPastel,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 90,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Onboarding Complete!',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome to J C Mart, ${_nameController.text.trim()}!\nYour location and customer profile have been saved successfully.',
          style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Quick-Commerce Express', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Fresh groceries ready for 10-minute delivery to ${_selectedVillage ?? "your village"}.',
                style: const TextStyle(color: Colors.black87),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),

        CustomButton(
          text: 'Keep Shopping (Go to Home)',
          backgroundColor: AppColors.primary,
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ],
    );
  }
}
