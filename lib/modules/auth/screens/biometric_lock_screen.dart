import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/route_generator.dart';
import '../widgets/custom_button.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _checkingBiometrics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Automatically trigger biometrics prompt on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Lock again when app goes to background & resumes
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _isAuthenticated = false;
      });
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_checkingBiometrics) return;
    setState(() {
      _checkingBiometrics = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.checkBiometrics();

    setState(() {
      _checkingBiometrics = false;
      _isAuthenticated = success;
    });

    if (success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Granted / అనుమతి లభించింది'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isAuthenticated) {
      // Once authenticated, render the dashboard
      return const DummyHomeScreen(title: 'Admin Dashboard');
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.fingerprint_rounded,
                size: 100,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Admin Console Locked',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Verification required using device fingerprint, face, or security PIN to continue.',
                style: TextStyle(color: Colors.grey, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              CustomButton(
                text: 'Authenticate Now',
                backgroundColor: Colors.blueAccent,
                isLoading: _checkingBiometrics,
                onPressed: _authenticate,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await authProvider.logout();
                },
                child: const Text(
                  'Log Out Admin / అడ్మిన్ లాగౌట్',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
