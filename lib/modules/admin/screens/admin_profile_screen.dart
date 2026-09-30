import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hypermart/core/utils/route_generator.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../domain/entities/dashboard_stats.dart';

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
      if (!mounted) return;
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
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTokens.primary)),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
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
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ADMINISTRATOR',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
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
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return Center(child: CircularProgressIndicator(color: AppTokens.primary));
                  }
                  final stats = snapshot.data;
                  final productsCount = stats?.productCount ?? 0;
                  final activeRiders = stats?.activeRidersCount ?? 0;
                  final activeOrders = stats?.activeOrdersCount ?? 0;

                  return Row(
                    children: [
                      _buildMetricSummary('Riders', '$activeRiders registered', Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      _buildMetricSummary('Products', '$productsCount items', AppTokens.statusDelivered),
                      const SizedBox(width: 10),
                      _buildMetricSummary('Active Orders', '$activeOrders in flight', AppTokens.statusAssigned),
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
                  Text(
                    "Operational Quick Actions",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () => Navigator.pushNamed(context, RouteGenerator.storeSettings),
                      ),
                      _buildGridAction(
                        icon: Icons.person_add_alt_1_rounded,
                        label: 'Register Rider',
                        desc: 'Add to whitelists',
                        color: AppTokens.accent,
                        onTap: () => Navigator.pushNamed(context, RouteGenerator.addRider),
                      ),
                      _buildGridAction(
                        icon: Icons.receipt_long_rounded,
                        label: 'Inventory Logs',
                        desc: 'Stock ledger checks',
                        color: AppTokens.statusDelivered,
                        onTap: () => Navigator.pushNamed(context, RouteGenerator.inventoryLogs),
                      ),
                      _buildGridAction(
                        icon: Icons.view_carousel_rounded,
                        label: 'Promo Banners',
                        desc: 'Home carousel',
                        color: AppTokens.statusPickedUp,
                        onTap: () => Navigator.pushNamed(context, RouteGenerator.bannerManagement),
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
                  Text(
                    "App Preferences",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.dark_mode_outlined, color: Theme.of(context).colorScheme.primary),
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
                          secondary: Icon(Icons.fingerprint_rounded, color: Theme.of(context).colorScheme.primary),
                          title: const Text("Biometric Console Lock", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                          subtitle: const Text("Require lock check on background", style: TextStyle(fontSize: 11)),
                          activeThumbColor: Theme.of(context).colorScheme.primary,
                          value: _biometricEnabled,
                          onChanged: _toggleBiometric,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Legal & Policies
                  Text(
                    "Legal & Platform Policies",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.privacy_tip_outlined, color: Theme.of(context).colorScheme.primary),
                          title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          onTap: () => Navigator.pushNamed(context, RouteGenerator.privacyPolicy),
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary),
                          title: const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                          onTap: () => Navigator.pushNamed(context, RouteGenerator.termsConditions),
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
                  Text(
                    "About this Console",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Real values only. This panel used to show hardcoded
                          // "CONNECTED" / "ACTIVE" / "v1.0.4-release" regardless of
                          // the actual state.
                          _buildDiagnosticRow(
                            Icons.person_outline_rounded,
                            'Signed in as',
                            user.email.isNotEmpty ? user.email : user.name,
                            Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const Divider(height: 24),
                          FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, info) => _buildDiagnosticRow(
                              Icons.info_outline_rounded,
                              'App version',
                              info.hasData ? '${info.data!.version}+${info.data!.buildNumber}' : '—',
                              Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
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
              child:               OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context); // Pop profile screen
                  await authProvider.logout();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text("LOG OUT OF ADMIN CONSOLE", style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.errorContainer, width: 1.5),
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
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
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
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10),
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
        Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        // Flexible + ellipsis: a long value (e.g. an email address) used to push
        // the row past the card edge.
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
