import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/utils/phone.dart';

class EditProfileDialog extends StatefulWidget {
  final UserModel user;

  const EditProfileDialog({super.key, required this.user});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _villageController;
  late final TextEditingController _vehicleDetailsController;
  late final TextEditingController _vehicleNoController;
  late final TextEditingController _licenseNoController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _villageController = TextEditingController(text: widget.user.village);
    _vehicleDetailsController = TextEditingController(text: widget.user.vehicleDetails ?? '');
    _vehicleNoController = TextEditingController(text: widget.user.vehicleNo ?? '');
    _licenseNoController = TextEditingController(text: widget.user.licenseNo ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    _vehicleDetailsController.dispose();
    _vehicleNoController.dispose();
    _licenseNoController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    
    final success = await profileProvider.updateProfileDetails(
      name: _nameController.text.trim(),
      phone: normalizeIndianMobile(_phoneController.text) ?? _phoneController.text.trim(),
      village: _villageController.text.trim(),
      vehicleDetails: widget.user.role == 'delivery' ? _vehicleDetailsController.text.trim() : null,
      vehicleNo: widget.user.role == 'delivery' ? _vehicleNoController.text.trim().toUpperCase() : null,
      licenseNo: widget.user.role == 'delivery' ? _licenseNoController.text.trim().toUpperCase() : null,
    );

    if (success && mounted) {
      Navigator.of(context).pop(true);
    } else if (mounted) {
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(profileProvider.errorMessage ?? "Failed to update profile"),
          backgroundColor: scheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<ProfileProvider>().isLoading;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: AppTokens.s24,
        right: AppTokens.s24,
        top: AppTokens.s24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTokens.s24,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTokens.rXl),
          topRight: Radius.circular(AppTokens.rXl),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom Sheet handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.s24),

              Text(
                'Edit Profile Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.s24),

              // Name Field
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                  prefixIcon: Icon(Icons.person_outline_rounded, color: scheme.primary),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    borderSide: BorderSide(color: scheme.error, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    borderSide: BorderSide(color: scheme.error, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.s20),

              // Phone Field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                  prefixIcon: Icon(Icons.phone_android_rounded, color: scheme.primary),
                  hintText: 'e.g. 9876543210',
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    borderSide: BorderSide(color: scheme.error, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    borderSide: BorderSide(color: scheme.error, width: 2),
                  ),
                ),
                validator: validateIndianMobile,
              ),
              const SizedBox(height: AppTokens.s20),

              // Village Field
              TextFormField(
                controller: _villageController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Village / Town Name',
                  labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                  prefixIcon: Icon(Icons.location_city_rounded, color: scheme.primary),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    borderSide: BorderSide(color: scheme.error, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                    borderSide: BorderSide(color: scheme.error, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your village name';
                  }
                  return null;
                },
              ),
              if (widget.user.role == 'delivery') ...[
                const SizedBox(height: AppTokens.s20),
                TextFormField(
                  controller: _vehicleDetailsController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Model & Color',
                    labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.motorcycle_rounded, color: scheme.primary),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      borderSide: BorderSide(color: scheme.primary, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter vehicle model details';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTokens.s20),
                TextFormField(
                  controller: _vehicleNoController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Plate Number',
                    hintText: 'e.g. AP 39 XX 1234',
                    labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.pin_outlined, color: scheme.primary),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      borderSide: BorderSide(color: scheme.primary, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      borderSide: BorderSide(color: scheme.error, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      borderSide: BorderSide(color: scheme.error, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter vehicle number';
                    }
                    final cleanVal = value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
                    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}$').hasMatch(cleanVal)) {
                      return 'Invalid plate format (e.g. AP 39 XX 1234)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTokens.s20),
                TextFormField(
                  controller: _licenseNoController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Driving License Number',
                    hintText: 'e.g. AP-39-2026-1234567',
                    labelStyle: TextStyle(color: scheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.badge_outlined, color: scheme.primary),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      borderSide: BorderSide(color: scheme.primary, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      borderSide: BorderSide(color: scheme.error, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rLg),
                      borderSide: BorderSide(color: scheme.error, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter driving license number';
                    }
                    final cleanVal = value.replaceAll(RegExp(r'[\s\-]+'), '').toUpperCase();
                    if (!RegExp(r'^[A-Z]{2}[0-9]{13}$').hasMatch(cleanVal)) {
                      return 'Invalid license number format';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: AppTokens.s32),

              // Submit Button
              ElevatedButton(
                onPressed: isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppTokens.s16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.rLg),
                  ),
                ),
                child: isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
              const SizedBox(height: AppTokens.s12),
              
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(vertical: AppTokens.s12),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
