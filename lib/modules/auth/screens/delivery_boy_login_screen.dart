import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../features/auth/presentation/widgets/social_button.dart';

class DeliveryBoyLoginScreen extends StatefulWidget {
  final bool isEmbedded;
  const DeliveryBoyLoginScreen({super.key, this.isEmbedded = false});

  @override
  State<DeliveryBoyLoginScreen> createState() => _DeliveryBoyLoginScreenState();
}

class _DeliveryBoyLoginScreenState extends State<DeliveryBoyLoginScreen> {
  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleGoogleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithGoogle(role: 'delivery');

    if (success) {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      _showSnackBar(authProvider.errorMessage ?? 'Google verification failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    final mainContent = Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.delivery_dining_outlined,
            size: 120,
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          const Text(
            'Verify Your Partner Account',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Log in using the registered Google account whitelisted by your administrator.',
            style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            height: 60,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              onPressed: authProvider.isLoading ? null : _handleGoogleLogin,
              child: authProvider.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(22, 22),
                          painter: GoogleLogoPainter(),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Sign In with Google',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return mainContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Partner'),
      ),
      body: mainContent,
    );
  }
}
