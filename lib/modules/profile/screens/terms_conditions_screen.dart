import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/legal_document_view.dart';
import '../../../core/providers/config_provider.dart';
import '../../../domain/entities/app_config.dart';

/// Terms & Conditions screen for JC Mart Quick-Commerce
class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  // Shows the admin-authored terms (Store Settings) when set, and the bundled
  // default text below otherwise.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream: Provider.of<ConfigProvider>(context, listen: false).streamAppConfig(),
      builder: (context, snapshot) {
        final custom = snapshot.data?.termsAndConditions;
        if (custom != null && custom.trim().isNotEmpty) {
          return LegalDocumentView(title: 'Terms & Conditions', body: custom);
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
          "Terms & Conditions",
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
        child: Container(
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
                      color: AppTokens.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gavel_rounded, color: AppTokens.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "J C Mart Terms of Service",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Last updated: July 2026",
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

              _buildSection(
                context: context,
                number: "1",
                title: "Service Overview",
                content:
                    "J C Mart provides 10-minute hyperlocal quick-commerce grocery and daily essential delivery services in Bhimavaram and designated surrounding coverage zones. By accessing or placing orders through our mobile application, you agree to comply with these terms.",
              ),
              _buildSection(
                context: context,
                number: "2",
                title: "User Accounts & Eligibility",
                content:
                    "Users must provide accurate contact numbers and village/location details during profile setup. You are responsible for all order activities performed through your account session.",
              ),
              _buildSection(
                context: context,
                number: "3",
                title: "Pricing & Cash on Delivery (COD)",
                content:
                    "All product prices listed include applicable taxes. Cash on Delivery (COD) requires full cash payment upon arrival of the delivery rider. Fraudulent order placement or refusal of valid deliveries may result in account restriction.",
              ),
              _buildSection(
                context: context,
                number: "4",
                title: "Order Cancellations & Returns",
                content:
                    "Due to the 10-minute instant dispatch model, orders can only be cancelled before rider assignment. Damaged, spoiled, or incorrect items reported immediately upon delivery will be verified for instant replacement or refund credit.",
              ),
              _buildSection(
                context: context,
                number: "5",
                title: "Inventory & Availability",
                content:
                    "Product availability is subject to physical dark-store stock. In case of unexpected inventory discrepancies, items will be marked out-of-stock and excluded from your bill.",
              ),
              _buildSection(
                context: context,
                number: "6",
                title: "Contact & Support",
                content:
                    "For disputes, order assistance, or service queries, reach out to J C Mart Customer Care via in-app WhatsApp support or direct phone hotline.",
              ),
              const SizedBox(height: AppTokens.s20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String number,
    required String title,
    required String content,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTokens.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: scheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
          Padding(
            padding: const EdgeInsets.only(left: 34.0),
            child: Text(
              content,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
