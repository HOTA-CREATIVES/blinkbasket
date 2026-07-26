import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/providers/order_provider.dart';

class AddRiderScreen extends StatefulWidget {
  const AddRiderScreen({super.key});

  @override
  State<AddRiderScreen> createState() => _AddRiderScreenState();
}

class _AddRiderScreenState extends State<AddRiderScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _villageController = TextEditingController();
  final _vehicleNoController = TextEditingController();
  final _licenseNoController = TextEditingController();
  
  int _activeStep = 0; // 0 for Personal Details, 1 for Compliance & Region
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    _vehicleNoController.dispose();
    _licenseNoController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
      ),
    );
  }

  String _sanitizePhoneNumber(String rawPhone) {
    var cleaned = rawPhone.replaceAll(RegExp(r'\s+'), ''); // remove all whitespace
    if (cleaned.startsWith('+91')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }
    return cleaned;
  }

  bool _validateStep0() {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Rider full name is required');
      return false;
    }
    if (_nameController.text.trim().length < 3) {
      _showSnackBar('Name must be at least 3 characters');
      return false;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Google Email Address is required');
      return false;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnackBar('Please enter a valid email address');
      return false;
    }
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      _showSnackBar('Phone number is required');
      return false;
    }
    final phone = _sanitizePhoneNumber(rawPhone);
    if (phone.length != 10 || int.tryParse(phone) == null) {
      _showSnackBar('Please enter a valid 10-digit phone number');
      return false;
    }
    // Update the controller so user sees the cleaned up 10-digit number
    _phoneController.text = phone;
    return true;
  }

  String _formatVehicleNumber(String rawVehicle) {
    final cleaned = rawVehicle.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (cleaned.length < 5) return cleaned;
    
    final state = cleaned.substring(0, 2);
    final district = cleaned.substring(2, 4);
    
    // Find where the numbers at the end start
    int numIndex = cleaned.length;
    for (int i = cleaned.length - 1; i >= 4; i--) {
      final code = cleaned.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        numIndex = i;
      } else {
        break;
      }
    }
    
    final series = cleaned.substring(4, numIndex);
    final number = cleaned.substring(numIndex);
    
    return '$state $district $series $number'.trim();
  }

  String _formatLicenseNumber(String rawLicense) {
    final cleaned = rawLicense.replaceAll(RegExp(r'[\s\-/]+'), '').toUpperCase();
    if (cleaned.length != 15) return cleaned;
    
    final state = cleaned.substring(0, 2);
    final rto = cleaned.substring(2, 4);
    final year = cleaned.substring(4, 8);
    final serial = cleaned.substring(8);
    
    return '$state-$rto-$year-$serial';
  }

  Future<void> _submitRider() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final sanitizedPhone = _sanitizePhoneNumber(_phoneController.text.trim());
    final rawVehicle = _vehicleNoController.text.trim();
    final formattedVehicle = rawVehicle.isNotEmpty ? _formatVehicleNumber(rawVehicle) : '';
    final rawLicense = _licenseNoController.text.trim();
    final formattedLicense = rawLicense.isNotEmpty ? _formatLicenseNumber(rawLicense) : '';

    try {
      final temporaryPassword = await orderProvider.whitelistRider(
        _nameController.text.trim(),
        _emailController.text.trim().toLowerCase(),
        sanitizedPhone,
        _villageController.text.trim(),
        vehicleNo: formattedVehicle,
        licenseNo: formattedLicense,
      );

      if (mounted) {
        await _showTemporaryPasswordDialog(temporaryPassword);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Failed to whitelist rider: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showTemporaryPasswordDialog(String temporaryPassword) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Rider Whitelisted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this one-time login password with the rider now — it will not be shown again.'),
            const SizedBox(height: 16),
            SelectableText(
              temporaryPassword,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DONE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Register Delivery Partner',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Top Progressive Step Indicator
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
              child: Row(
                children: [
                  _buildStepIndicator(
                    index: 0,
                    title: 'Profile Info',
                    icon: Icons.person_outline_rounded,
                  ),
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: _activeStep > 0 ? AppTokens.primary : Colors.grey.shade200,
                    ),
                  ),
                  _buildStepIndicator(
                    index: 1,
                    title: 'Region & Vehicle',
                    icon: Icons.directions_bike_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _activeStep == 0 ? _buildStep0() : _buildStep1(),
                ),
              ),
            ),

            // Bottom Navigation Actions
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_activeStep > 0) ...[
                    OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _activeStep = 0),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'BACK',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              if (_activeStep == 0) {
                                if (_validateStep0()) {
                                  setState(() => _activeStep = 1);
                                }
                              } else {
                                _submitRider();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTokens.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _activeStep == 0 ? 'CONTINUE' : 'WHITELIST PARTNER',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator({required int index, required String title, required IconData icon}) {
    final isActive = _activeStep == index;
    final isDone = _activeStep > index;

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: isDone
              ? AppTokens.primary
              : isActive
                  ? AppTokens.primary.withValues(alpha: 0.15)
                  : Colors.grey.shade100,
          child: Icon(
            isDone ? Icons.check : icon,
            size: 18,
            color: isDone
                ? Colors.white
                : isActive
                    ? AppTokens.primary
                    : Colors.grey.shade400,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.w500,
            color: isActive || isDone ? Colors.black87 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  // STEP 0: Personal Contact details
  Widget _buildStep0() {
    return Column(
      key: const ValueKey('step0'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _buildSectionHeader(
          title: 'Personal Information',
          subtitle: 'Required details to whitelist and invite the delivery partner.',
        ),
        const SizedBox(height: 20),

        // Rider Name
        _buildTextField(
          controller: _nameController,
          label: 'Full Name',
          hint: 'e.g. Ramesh Kumar',
          icon: Icons.person_outline_rounded,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Full name is required';
            if (value.trim().length < 3) return 'Name must be at least 3 characters';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Google Email
        _buildTextField(
          controller: _emailController,
          label: 'Google Email Address',
          hint: 'e.g. rider1@gmail.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          helperText: 'Partner must use this Google email to authenticate upon first login.',
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Email is required';
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Phone Number
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: '9876543210',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          prefixText: '+91 ',
          helperText: 'Enter 10-digit number. Country code (+91) is handled automatically.',
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Phone number is required';
            final sanitized = _sanitizePhoneNumber(value);
            if (sanitized.length != 10 || int.tryParse(sanitized) == null) {
              return 'Enter a valid 10-digit number';
            }
            return null;
          },
        ),
      ],
    );
  }

  // STEP 1: Region & Vehicle compliance info
  Widget _buildStep1() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _buildSectionHeader(
          title: 'Region & Compliance Assets',
          subtitle: 'Select service boundaries and transport registration assets.',
        ),
        const SizedBox(height: 20),

        // Region / Village
        _buildTextField(
          controller: _villageController,
          label: 'Assigned Region / Village',
          hint: 'e.g. Bhimavaram',
          icon: Icons.map_outlined,
          helperText: 'Rider is prioritized for delivery assignments heading to this village.',
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Assigned region is required';
            if (value.trim().length < 3) return 'Region name must be at least 3 characters';
            if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
              return 'Region name can only contain letters and spaces';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Vehicle registration
        _buildTextField(
          controller: _vehicleNoController,
          label: 'Vehicle Registration Number (Optional)',
          hint: 'XX NN XX XXXX (e.g. AP 39 XX 1234)',
          icon: Icons.directions_bike_rounded,
          helperText: 'Enter in XX NN XX XXXX format (e.g. AP 39 XX 1234).',
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            final cleaned = value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
            final regExp = RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{1,4}$');
            if (!regExp.hasMatch(cleaned)) {
              return 'Must match format: XX NN XX XXXX (e.g., AP 39 XX 1234)';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Driving License
        _buildTextField(
          controller: _licenseNoController,
          label: 'Driving Licence Number (Optional)',
          hint: 'SS-RR-YYYY-NNNNNNN (e.g. DL-14-2011-0012345)',
          icon: Icons.badge_outlined,
          helperText: 'Enter in SS-RR-YYYY-NNNNNNN format (e.g. DL-14-2011-0012345).',
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            final cleaned = value.replaceAll(RegExp(r'[\s\-/]+'), '').toUpperCase();
            final regExp = RegExp(r'^[A-Z]{2}[0-9]{13}$');
            if (!regExp.hasMatch(cleaned)) {
              return 'Must match standard format (e.g., DL-14-2011-0012345)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? helperText,
    String? prefixText,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        enabled: !_isSubmitting,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          helperMaxLines: 2,
          prefixIcon: Icon(icon, color: Colors.grey.shade400),
          prefixText: prefixText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            borderSide: const BorderSide(color: AppTokens.primary, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }
}
