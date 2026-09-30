import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/design/widgets/legal_document_view.dart';
import '../../../core/providers/config_provider.dart';
import '../../../domain/entities/app_config.dart';
import '../../../core/design/app_tokens.dart';

/// Privacy Policy & Version Details screen for JC Mart
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  String _version = "v1.0.0";
  String _buildNumber = "1";

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (_) {}
  }

  // Shows the admin-authored policy (Store Settings) when one is set, and the
  // bundled default text below otherwise.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream: Provider.of<ConfigProvider>(context, listen: false).streamAppConfig(),
      builder: (context, snapshot) {
        final custom = snapshot.data?.privacyPolicy;
        if (custom != null && custom.trim().isNotEmpty) {
          return LegalDocumentView(title: 'Privacy Policy', body: custom);
        }
        return _buildBundled(context);
      },
    );
  }

  Widget _buildBundled(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text(
          "Privacy Policy & App Info",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App Version Card
            Container(
              padding: const EdgeInsets.all(AppTokens.s20),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(AppTokens.rXl),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: AppTokens.shadowSm(Colors.black),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTokens.brandChrome,
                      shape: BoxShape.circle,
                      boxShadow: AppTokens.shadowSm(AppTokens.brandChrome),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: AppTokens.onBrandChrome,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppTokens.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "J C Mart Quick-Commerce",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "App Version: $_version (Build $_buildNumber)",
                          style: const TextStyle(fontSize: 13, color: AppTokens.primary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Platform: Android / iOS (Production)",
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTokens.s20),

            // Privacy Policy Card
            Container(
              padding: const EdgeInsets.all(AppTokens.s20),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(AppTokens.rXl),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: AppTokens.shadowSm(Colors.black),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTokens.medicine.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.privacy_tip_rounded, color: AppTokens.medicine, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Privacy & Data Protection",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "How we safeguard your information",
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.s20),
                  const Divider(),
                  const SizedBox(height: AppTokens.s16),

                  _buildPolicyTile(
                    icon: Icons.location_on_outlined,
                    title: "GPS Location Data",
                    description:
                        "GPS coordinates are accessed strictly during address selection & live delivery ETA calculations to ensure accurate 10-minute order routing.",
                  ),
                  _buildPolicyTile(
                    icon: Icons.phone_android_outlined,
                    title: "Phone & Contact Info",
                    description:
                        "Your mobile number is used exclusively for authentication OTPs, order updates, and delivery rider communications.",
                  ),
                  _buildPolicyTile(
                    icon: Icons.notifications_active_outlined,
                    title: "Push Notifications",
                    description:
                        "Firebase Cloud Messaging (FCM) is used to alert you when your order is accepted, picked up, or out for delivery.",
                  ),
                  _buildPolicyTile(
                    icon: Icons.security_rounded,
                    title: "Data Security",
                    description:
                        "We employ encrypted transport layer security (TLS) and strict Firestore security rules to protect user data against unauthorized access.",
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.s32),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.s8),
            decoration: BoxDecoration(
              color: AppTokens.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTokens.rMd),
            ),
            child: Icon(icon, color: AppTokens.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: scheme.onSurface),
                ),
                const SizedBox(height: AppTokens.s4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
