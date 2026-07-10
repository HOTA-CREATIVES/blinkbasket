import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../widgets/custom_button.dart';

class AdminLoginScreen extends StatefulWidget {
  final bool isEmbedded;
  const AdminLoginScreen({super.key, this.isEmbedded = false});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String? _verificationId;
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
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

  Future<void> _handleSendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String rawPhone = _phoneController.text.trim();
    
    // Auto-append country code +91 if not provided for convenience in India/Andhra Pradesh
    if (!rawPhone.startsWith('+')) {
      rawPhone = '+91$rawPhone';
    }

    await authProvider.verifyPhone(
      phoneNumber: rawPhone,
      codeSent: (verificationId, resendToken) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
        });
        _showSnackBar('OTP sent successfully to $rawPhone', isError: false);
      },
      verificationFailed: (errorMsg) {
        _showSnackBar(errorMsg);
      },
    );
  }

  Future<void> _handleVerifyOtp() async {
    if (!_otpFormKey.currentState!.validate() || _verificationId == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.verifyOtp(
      verificationId: _verificationId!,
      smsCode: _otpController.text.trim(),
    );

    if (success) {
      if (mounted) {
        // Will auto-redirect to Biometric Gate screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      _showSnackBar(authProvider.errorMessage ?? 'OTP verification failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    final inputDecorationTheme = InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(100),
        borderSide: const BorderSide(color: Color(0xFFDADCE0), width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(100),
        borderSide: const BorderSide(color: Color(0xFFDADCE0), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(100),
        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(100),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(100),
        borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
      ),
    );

    final mainContent = SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            size: 100,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          const Text(
            'Administrator Access Gate',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Whitelisted phone OTP authentication only. Session will require local biometrics verification.',
            style: TextStyle(color: Colors.grey, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          if (!_otpSent) ...[
            // Phone Input Form
            Form(
              key: _phoneFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: inputDecorationTheme.copyWith(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone_iphone),
                      helperText: 'e.g. +91 98765 43210 or 9876543210',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Enter your phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Send Verification OTP',
                    backgroundColor: Colors.blue.shade800,
                    isLoading: authProvider.isLoading,
                    onPressed: _handleSendOtp,
                  ),
                ],
              ),
            ),
          ] else ...[
            // OTP Code Input Form
            Form(
              key: _otpFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: inputDecorationTheme.copyWith(
                      labelText: '6-digit OTP Code',
                      prefixIcon: const Icon(Icons.password_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length != 6) {
                        return 'Enter valid 6-digit OTP code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Verify OTP & Log In',
                    backgroundColor: Colors.blue.shade800,
                    isLoading: authProvider.isLoading,
                    onPressed: _handleVerifyOtp,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _otpSent = false;
                        _otpController.clear();
                      });
                    },
                    child: const Text('Back to Phone Number'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.isEmbedded) {
      return mainContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
      ),
      body: mainContent,
    );
  }
}
