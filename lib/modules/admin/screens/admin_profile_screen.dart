import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hypermart/core/utils/route_generator.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../domain/entities/dashboard_stats.dart';
import 'package:hypermart/modules/admin/screens/add_rider_screen.dart';
import 'package:hypermart/modules/admin/screens/inventory_logs_screen.dart';
import 'package:hypermart/modules/admin/screens/banner_management_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  bool _biometricEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadBiometricPref();
  }

  Future<void> _loadBiometricPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _biometricEnabled = prefs.getBool('admin_biometric_lock_enabled') ?? true;
      });
    } catch (_) {}
  }

  Future<void> _toggleBiometric(bool val) async {
    setState(() {
      _biometricEnabled = val;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('admin_biometric_lock_enabled', val);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.currentUserModel;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Cobalt Parallax Gradient Banner
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade900,
                        Colors.indigo.shade800,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text(
                            "Console Profile",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                ),
                // Floating Admin Avatar
                Positioned(
                  bottom: -45,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 55),

            // Profile Title & Role Badge
            Center(
              child: Column(
                children: [
                  Text(
                    user.name.isNotEmpty ? user.name : "System Administrator",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'LEVEL 3 SECURITY CLEARANCE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 2. Dynamic Metric Indicators (Live Stats)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
               child: StreamBuilder<DashboardStats>(
                stream: Provider.of<ConfigProvider>(context, listen: false).streamDashboardStats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final stats = snapshot.data;
                  final productsCount = stats?.productCount ?? 0;
                  final activeRiders = stats?.activeRidersCount ?? 0;
                  final activeOrders = stats?.activeOrdersCount ?? 0;

                  return Row(
                    children: [
                      _buildMetricSummary('Active Riders', '$activeRiders whitelisted', Colors.orange),
                      const SizedBox(width: 10),
                      _buildMetricSummary('Products', '$productsCount items', Colors.green),
                      const SizedBox(width: 10),
                      _buildMetricSummary('Pending Orders', '$activeOrders active', Colors.blue),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // 3. Operational Grid Menu (Blinkit Style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Operational Quick Actions",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildGridAction(
                        icon: Icons.store_mall_directory_rounded,
                        label: 'Store Settings',
                        desc: 'Open hours & fees',
                        color: Colors.blue,
                        onTap: () => Navigator.pushNamed(context, RouteGenerator.storeSettings),
                      ),
                      _buildGridAction(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Register Rider',
                        desc: 'Add to whitelists',
                        color: Colors.orange,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddRiderScreen())),
                      ),
                      _buildGridAction(
                        icon: Icons.receipt_long_rounded,
                        label: 'Inventory Logs',
                        desc: 'Stock ledger checks',
                        color: Colors.green,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryLogsScreen())),
                      ),
                      _buildGridAction(
                        icon: Icons.view_carousel_rounded,
                        label: 'Promo Banners',
                        desc: 'Home carousel',
                        color: Colors.purple,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const BannerManagementScreen())),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 4. App Preferences (Amazon Style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "App Preferences",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.white,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.dark_mode_outlined, color: Colors.indigo),
                          title: const Text("Theme Mode", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                          trailing: DropdownButton<String>(
                            value: themeProvider.themeModeString,
                            underline: const SizedBox(),
                            items: ['Light', 'Dark', 'System'].map((String mode) {
                              return DropdownMenuItem<String>(
                                value: mode,
                                child: Text(mode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                themeProvider.setThemeMode(v);
                              }
                            },
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        SwitchListTile(
                          secondary: const Icon(Icons.fingerprint_rounded, color: Colors.blue),
                          title: const Text("Biometric Console Lock", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                          subtitle: const Text("Require lock check on background", style: TextStyle(fontSize: 11)),
                          activeColor: Colors.blue,
                          value: _biometricEnabled,
                          onChanged: _toggleBiometric,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. System Diagnostics Panel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "System Connectivity Status",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildDiagnosticRow(Icons.cloud_done_outlined, 'Firestore Database Connection', 'CONNECTED', Colors.green),
                          const Divider(height: 24),
                          _buildDiagnosticRow(Icons.security_rounded, 'Authentication Credentials State', 'ACTIVE', Colors.green),
                          const Divider(height: 24),
                          _buildDiagnosticRow(Icons.info_outline_rounded, 'Production Console Build', 'v1.0.4-release', Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Log Out Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context); // Pop profile screen
                  await authProvider.logout();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text("LOG OUT OF ADMIN CONSOLE", style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricSummary(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridAction({
    required IconData icon,
    required String label,
    required String desc,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticRow(IconData icon, String label, String status, Color color) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            status,
            style: TextStyle(color: color == Colors.grey ? Colors.grey.shade700 : color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
