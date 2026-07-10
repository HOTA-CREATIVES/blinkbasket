import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/village_dropdown.dart';

class CustomerProfileSetupScreen extends StatefulWidget {
  const CustomerProfileSetupScreen({super.key});

  @override
  State<CustomerProfileSetupScreen> createState() => _CustomerProfileSetupScreenState();
}

class _CustomerProfileSetupScreenState extends State<CustomerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedVillage;

  @override
  void dispose() {
    _nameController.dispose();
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

  Future<void> _handleSaveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.setupCustomerProfile(
      name: _nameController.text.trim(),
      village: _selectedVillage!,
    );

    if (success) {
      _showSnackBar('Profile setup completed successfully!', isError: false);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      _showSnackBar(authProvider.errorMessage ?? 'Failed to save profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile / ప్రొఫైల్ సెటప్'),
        automaticallyImplyLeading: false, // Prevent returning since session is active but profile incomplete
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.person_pin_rounded,
                size: 90,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              const Text(
                'Tell us more about yourself to help deliver fresh groceries to your village!',
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Name Field
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Your Name / మీ పేరు',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Village Dropdown
              VillageDropdown(
                value: _selectedVillage,
                onChanged: (val) {
                  setState(() {
                    _selectedVillage = val;
                  });
                },
              ),
              const SizedBox(height: 32),

              // Submit Button
              CustomButton(
                text: 'Save & Continue / సేవ్ చేసి కొనసాగించండి',
                isLoading: authProvider.isLoading,
                onPressed: _handleSaveProfile,
              ),
              const SizedBox(height: 16),
              
              // Cancel / Sign out option
              TextButton(
                onPressed: () async {
                  await authProvider.logout();
                },
                child: const Text(
                  'Cancel & Sign Out / రద్దు చేసి నిష్క్రమించండి',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
