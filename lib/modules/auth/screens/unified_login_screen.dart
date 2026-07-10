import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'customer_login_screen.dart';
import 'delivery_boy_login_screen.dart';
import 'admin_login_screen.dart';

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> with SingleTickerProviderStateMixin {
  late TabController _roleTabController;

  final List<Map<String, dynamic>> _roles = [
    {
      'name': 'customer',
      'title': 'Customer',
      'color': AppColors.customerPrimary,
      'icon': Icons.shopping_basket_rounded,
    },
    {
      'name': 'delivery',
      'title': 'Delivery Partner',
      'color': Colors.orange.shade800,
      'icon': Icons.delivery_dining_rounded,
    },
    {
      'name': 'admin',
      'title': 'Administrator',
      'color': Colors.blue.shade800,
      'icon': Icons.admin_panel_settings_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _roleTabController = TabController(length: 3, vsync: this);
    
    // Listen to tab changes to sync selected role in AuthProvider
    _roleTabController.addListener(() {
      if (!_roleTabController.indexIsChanging) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.setSelectedRole(_roles[_roleTabController.index]['name']);
        setState(() {}); // Trigger rebuild to update dynamic accent colors
      }
    });

    // Default select role
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.setSelectedRole(_roles[0]['name']);
    });
  }

  @override
  void dispose() {
    _roleTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _roles[_roleTabController.index]['color'] as Color;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_roles[_roleTabController.index]['icon'] as IconData, color: activeColor),
            const SizedBox(width: 8),
            Text(
              'BlinkBasket',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: activeColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _roleTabController,
          indicatorColor: activeColor,
          labelColor: activeColor,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _roles.map((role) {
            return Tab(
              icon: Icon(role['icon'] as IconData),
              text: role['title'] as String,
            );
          }).toList(),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _roleTabController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            CustomerLoginScreen(isEmbedded: true),
            DeliveryBoyLoginScreen(isEmbedded: true),
            AdminLoginScreen(isEmbedded: true),
          ],
        ),
      ),
    );
  }
}
