import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/design/app_tokens.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/order_provider.dart';

class EditRiderSheet extends StatefulWidget {
  final UserModel rider;
  const EditRiderSheet({super.key, required this.rider});

  @override
  State<EditRiderSheet> createState() => _EditRiderSheetState();
}

class _EditRiderSheetState extends State<EditRiderSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _villageController;
  late final TextEditingController _vehicleNoController;
  late final TextEditingController _licenseNoController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rider.name);
    _emailController = TextEditingController(text: widget.rider.email);
    _phoneController = TextEditingController(text: widget.rider.phone);
    _villageController = TextEditingController(text: widget.rider.village);
    _vehicleNoController = TextEditingController(text: widget.rider.vehicleNo ?? '');
    _licenseNoController = TextEditingController(text: widget.rider.licenseNo ?? '');
  }

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
        backgroundColor: isError ? Theme.of(context).colorScheme.error : AppTokens.statusDelivered,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatVehicleNumber(String rawVehicle) {
    final cleaned = rawVehicle.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (cleaned.length < 5) return cleaned;

    final state = cleaned.substring(0, 2);
    final district = cleaned.substring(2, 4);

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

  Future<void> _submitEdit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final rawVehicle = _vehicleNoController.text.trim();
    final formattedVehicle = rawVehicle.isNotEmpty ? _formatVehicleNumber(rawVehicle) : '';
    final rawLicense = _licenseNoController.text.trim();
    final formattedLicense = rawLicense.isNotEmpty ? _formatLicenseNumber(rawLicense) : '';

    try {
      await orderProvider.updateRiderDetails(
        docId: widget.rider.docId ?? widget.rider.uid,
        name: _nameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        phone: _phoneController.text.trim(),
        village: _villageController.text.trim(),
        vehicleNo: formattedVehicle,
        licenseNo: formattedLicense,
      );

      _showSnackBar('Rider updated successfully!', isError: false);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Failed to update rider: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Edit Delivery Partner Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Rider Full Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter rider name';
                    if (value.trim().length < 3) return 'Name must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Google Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter rider email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter phone number';
                    if (value.trim().length != 10 || int.tryParse(value.trim()) == null) {
                      return 'Enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _villageController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Assigned Region / Village',
                    prefixIcon: const Icon(Icons.map_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Enter assigned region';
                    if (value.trim().length < 3) return 'Region name must be at least 3 characters';
                    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                      return 'Region name can only contain letters and spaces';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _vehicleNoController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Number (Optional)',
                    prefixIcon: const Icon(Icons.directions_bike_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    hintText: 'XX NN XX XXXX (e.g. AP 39 XX 1234)',
                    helperText: 'Enter in XX NN XX XXXX format (e.g. AP 39 XX 1234).',
                  ),
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

                TextFormField(
                  controller: _licenseNoController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Driving Licence Number (Optional)',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    hintText: 'SS-RR-YYYY-NNNNNNN (e.g. DL-14-2011-0012345)',
                    helperText: 'Enter in SS-RR-YYYY-NNNNNNN format (e.g. DL-14-2011-0012345).',
                  ),
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
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            const Text('Saving...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        )
                      : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
