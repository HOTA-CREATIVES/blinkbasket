import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/route_generator.dart';

class LoginSelectionScreen extends StatelessWidget {
  const LoginSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Header Brand Section
              const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_basket_rounded,
                      size: 80,
                      color: Colors.green,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'BlinkBasket',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'hyperlocal delivery to your doorstep',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Text(
                'Choose your Role / పాత్రను ఎంచుకోండి:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Customer Option
              _buildRoleCard(
                context: context,
                title: 'Customer',
                subtitle: 'Buy groceries & household items\n(సరుకులు & ఇతర వస్తువులు కొనండి)',
                icon: Icons.shopping_bag_rounded,
                color: Colors.green.shade600,
                onTap: () {
                  authProvider.setSelectedRole('customer');
                  Navigator.pushNamed(context, RouteGenerator.customerLogin);
                },
              ),
              const SizedBox(height: 16),

              // Delivery Boy Option
              _buildRoleCard(
                context: context,
                title: 'Delivery Partner',
                subtitle: 'Deliver orders & earn money\n(ఆర్డర్లు డెలివరీ చేసి సంపాదించండి)',
                icon: Icons.delivery_dining_rounded,
                color: Colors.orange.shade700,
                onTap: () {
                  authProvider.setSelectedRole('delivery');
                  Navigator.pushNamed(context, RouteGenerator.deliveryLogin);
                },
              ),
              const SizedBox(height: 16),

              // Admin Option
              _buildRoleCard(
                context: context,
                title: 'Administrator',
                subtitle: 'Manage store, partners & settings\n(స్టోర్ మరియు డెలివరీ మేనేజ్మెంట్)',
                icon: Icons.admin_panel_settings_rounded,
                color: Colors.blue.shade800,
                onTap: () {
                  authProvider.setSelectedRole('admin');
                  Navigator.pushNamed(context, RouteGenerator.adminLogin);
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
