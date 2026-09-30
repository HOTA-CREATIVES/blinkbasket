import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/providers/config_provider.dart';
import '../../../domain/entities/app_config.dart';

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deliveryFeeController = TextEditingController();
  final _freeDeliveryController = TextEditingController();
  final _etaLabelController = TextEditingController();
  final _riderPayoutController = TextEditingController();
  final _supportPhoneController = TextEditingController();
  final _supportWhatsappController = TextEditingController();
  final _minimumOrderController = TextEditingController();
  final _privacyController = TextEditingController();
  final _termsController = TextEditingController();
  bool _storeOpen = true;
  bool _maintenanceMode = false;
  // The config as last loaded — fields this screen doesn't edit (service
  // zones, slot limit) are carried through on save. Rebuilding AppConfig from
  // only the form fields used to reset them to defaults / wipe the zone list.
  AppConfig? _loadedConfig;
  bool _isSaving = false;
  bool _configLoaded = false;
  final _categoryInputController = TextEditingController();
  List<String> _categories = [];

  @override
  void dispose() {
    _deliveryFeeController.dispose();
    _freeDeliveryController.dispose();
    _etaLabelController.dispose();
    _riderPayoutController.dispose();
    _supportPhoneController.dispose();
    _supportWhatsappController.dispose();
    _minimumOrderController.dispose();
    _privacyController.dispose();
    _termsController.dispose();
    _categoryInputController.dispose();
    super.dispose();
  }

  void _addCategory() {
    final value = _categoryInputController.text.trim();
    if (value.isEmpty || _categories.contains(value)) return;
    setState(() {
      _categories.add(value);
      _categoryInputController.clear();
    });
  }

  void _removeCategory(String value) {
    setState(() => _categories.remove(value));
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final fee = double.parse(_deliveryFeeController.text.trim());
      final threshold = double.parse(_freeDeliveryController.text.trim());
      final payout = double.parse(_riderPayoutController.text.trim());
      final minimumOrder = double.tryParse(_minimumOrderController.text.trim()) ?? 0.0;

      final config = AppConfig(
        storeOpen: _storeOpen,
        maintenanceMode: _maintenanceMode,
        minimumOrderAmount: minimumOrder,
        maxOrdersPerSlot: _loadedConfig?.maxOrdersPerSlot ?? 20,
        serviceZones: _loadedConfig?.serviceZones ?? const [],
        privacyPolicy: _privacyController.text.trim().isEmpty ? null : _privacyController.text.trim(),
        termsAndConditions: _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
        deliveryFee: fee,
        freeDeliveryAbove: threshold,
        updatedAt: DateTime.now(),
        etaLabel: _etaLabelController.text.trim().isEmpty
            ? null
            : _etaLabelController.text.trim(),
        riderPayoutPerDelivery: payout,
        supportPhone: _supportPhoneController.text.trim().isEmpty
            ? null
            : _supportPhoneController.text.trim(),
        supportWhatsapp: _supportWhatsappController.text.trim().isEmpty
            ? null
            : _supportWhatsappController.text.trim(),
        categories: _categories,
      );

      final success = await Provider.of<ConfigProvider>(context, listen: false)
          .updateAppConfig(config);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store settings updated successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppTokens.statusDelivered,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        final error = Provider.of<ConfigProvider>(context, listen: false).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update settings: $error'),
            backgroundColor: AppTokens.statusCancelled,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update settings: $e'),
            backgroundColor: AppTokens.statusCancelled,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: const Text(
          'Store Configurations',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<AppConfig>(
        stream: Provider.of<ConfigProvider>(context, listen: false).streamAppConfig(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: scheme.primary));
          }

          if (snapshot.hasData) {
            final config = snapshot.data!;
            // Populate form once when stream emits first time
            if (!_configLoaded) {
              _configLoaded = true;
              _loadedConfig = config;
              _privacyController.text = config.privacyPolicy ?? '';
              _termsController.text = config.termsAndConditions ?? '';
              _storeOpen = config.storeOpen;
              _maintenanceMode = config.maintenanceMode;
              _minimumOrderController.text = config.minimumOrderAmount == 0
                  ? ''
                  : config.minimumOrderAmount.toString();
              _deliveryFeeController.text = config.deliveryFee.toString();
              _freeDeliveryController.text = config.freeDeliveryAbove.toString();
              _etaLabelController.text = config.etaLabel ?? '';
              _riderPayoutController.text = config.riderPayoutPerDelivery.toString();
              _supportPhoneController.text = config.supportPhone ?? '';
              _supportWhatsappController.text = config.supportWhatsapp ?? '';
              _categories = List<String>.from(config.categories);
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Store operational switch card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    // SwitchListTile instead of a hand-rolled Row: the old
                    // Row(icon+Column, Switch) had no Expanded and overflowed
                    // on narrow phones.
                    child: SwitchListTile(
                      value: _storeOpen,
                      activeThumbColor: Colors.green,
                      onChanged: (val) => setState(() => _storeOpen = val),
                      secondary: Icon(
                        Icons.store_mall_directory_rounded,
                        color: _storeOpen ? AppTokens.statusDelivered : Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      title: const Text(
                        'Store Status',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Text(
                        _storeOpen ? 'Accepting Customer Orders' : 'Store is Closed (No Checkout)',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Maintenance mode — blocks checkout server-side (placeOrder).
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: SwitchListTile(
                      value: _maintenanceMode,
                      onChanged: (val) => setState(() => _maintenanceMode = val),
                      secondary: Icon(Icons.build_circle_outlined, color: scheme.primary),
                      title: const Text(
                        'Maintenance Mode',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Text(
                        _maintenanceMode
                            ? 'Checkout is blocked for customers'
                            : 'Off — orders are accepted normally',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pricing/Delivery fee configuration card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.delivery_dining_rounded, color: scheme.primary),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Delivery Logistics Surcharges',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Delivery fee field
                          TextFormField(
                            controller: _deliveryFeeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Standard Delivery Fee (₹)',
                              prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTokens.rSm),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Delivery fee is required';
                              final num = double.tryParse(val.trim());
                              if (num == null || num < 0) return 'Enter a valid non-negative number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Free delivery threshold field
                          TextFormField(
                            controller: _freeDeliveryController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Free Delivery Threshold (₹)',
                              prefixIcon: const Icon(Icons.shopping_bag_outlined, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTokens.rSm),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Threshold is required';
                              final num = double.tryParse(val.trim());
                              if (num == null || num < 0) return 'Enter a valid non-negative number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Minimum order amount field (0 / empty = no minimum)
                          TextFormField(
                            controller: _minimumOrderController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Minimum Order Amount (₹, optional)',
                              prefixIcon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTokens.rSm),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return null;
                              final num = double.tryParse(val.trim());
                              if (num == null || num < 0) return 'Enter a valid non-negative number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Rider payout field
                          TextFormField(
                            controller: _riderPayoutController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Rider Payout per Delivery (₹)',
                              prefixIcon: const Icon(Icons.two_wheeler_rounded, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTokens.rSm),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Rider payout is required';
                              final num = double.tryParse(val.trim());
                              if (num == null || num < 0) return 'Enter a valid non-negative number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Applies going forward only — past deliveries keep their original payout.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Legal pages — shown to customers under Profile. Blank keeps
                  // the built-in default text.
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.gavel_rounded, color: scheme.primary),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Legal Pages',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Leave a box empty to use the built-in text. Put a blank line between paragraphs and start a line with # for a heading.',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                          const Divider(height: 24),
                          TextFormField(
                            controller: _privacyController,
                            minLines: 4,
                            maxLines: 10,
                            maxLength: 20000,
                            decoration: InputDecoration(
                              labelText: 'Privacy Policy',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rSm)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _termsController,
                            minLines: 4,
                            maxLines: 10,
                            maxLength: 20000,
                            decoration: InputDecoration(
                              labelText: 'Terms & Conditions',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rSm)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Support contact configuration card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.support_agent_rounded, color: scheme.primary),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Support Contact',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          TextFormField(
                            controller: _supportPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Support phone (optional)',
                              hintText: 'e.g. +91 99999 99999',
                              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTokens.rSm),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _supportWhatsappController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Support WhatsApp number (optional)',
                              hintText: 'e.g. 919876543210 (digits only, country code first)',
                              prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTokens.rSm),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Shown as tap-to-contact actions for customers and riders. Leave blank to hide.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Delivery-time promise badge configuration card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.timer_outlined, color: scheme.primary),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Delivery Time Promise',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          TextFormField(
                            controller: _etaLabelController,
                            decoration: InputDecoration(
                              labelText: 'ETA badge text (optional)',
                              hintText: 'e.g. Delivers in ~20 min',
                              prefixIcon: const Icon(Icons.bolt_rounded, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTokens.rSm),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Shown as a badge on the customer home screen. Leave blank to hide it.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Product categories editor
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.rMd),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.category_rounded, color: scheme.primary),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Shop-by-Category Rail',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _categoryInputController,
                                  decoration: InputDecoration(
                                    labelText: 'Add a category',
                                    hintText: 'e.g. Frozen Foods',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTokens.rSm),
                                    ),
                                  ),
                                  onFieldSubmitted: (_) => _addCategory(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _addCategory,
                                icon: const Icon(Icons.add_rounded),
                                style: IconButton.styleFrom(backgroundColor: scheme.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_categories.isEmpty)
                            Text(
                              'No custom categories set — the app shows its built-in defaults.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories
                                  .map((cat) => Chip(
                                        label: Text(cat),
                                        onDeleted: () => _removeCategory(cat),
                                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.rSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: scheme.onPrimary, strokeWidth: 2),
                          )
                        : const Text(
                            'SAVE CONFIGURATIONS',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.1),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
