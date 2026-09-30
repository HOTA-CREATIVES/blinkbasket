import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/product_provider.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../domain/entities/app_config.dart';
import '../../../domain/entities/product.dart' as ent;
import 'widgets/product_ledger_sheet.dart';
import '../../../core/utils/app_exception.dart';

/// Full-screen product add / edit page (replaces the old cramped bottom sheet).
///
/// Stock is only *entered* when creating a product; afterwards every change
/// goes through the inventory ledger ("Adjust stock"), so the ledger and the
/// stock counters can't drift apart.
class ProductEditorScreen extends StatefulWidget {
  final ent.Product? existing;
  const ProductEditorScreen({super.key, this.existing});

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  static const _fallbackCategories = [
    'Fruits & Vegetables',
    'Staples & Grains',
    'Dairy & Eggs',
    'Bakery',
    'Snacks & Beverages',
    'Medicines',
    'Household',
  ];
  static const _unitSuggestions = ['1 kg', '500 g', '250 g', '1 L', '500 ml', '1 pc', '1 dozen', '1 pack'];

  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.existing?.name);
  late final _descriptionController = TextEditingController(text: widget.existing?.description);
  late final _priceController = TextEditingController(text: widget.existing?.price.toString());
  late final _discountController = TextEditingController(
      text: widget.existing?.discountedPrice?.toString() ?? '');
  late final _unitController = TextEditingController(text: widget.existing?.unit);
  late final _stockController = TextEditingController();
  late final _thresholdController =
      TextEditingController(text: (widget.existing?.lowStockThreshold ?? 10).toString());

  late String _category = widget.existing?.category ?? '';
  late bool _requiresPrescription = widget.existing?.requiresPrescription ?? false;
  late bool _isAvailable = widget.existing?.isAvailable ?? true;
  late final Stream<List<ent.Product>> _productsStream =
      Provider.of<ProductProvider>(context, listen: false).streamProducts();

  XFile? _pickedImage;
  Uint8List? _previewBytes;
  bool _isSubmitting = false;
  bool _dirty = false;
  bool _imageError = false;
  bool _categoryError = false;

  bool get _isEditing => widget.existing != null;
  bool get _isMedicine => _category.toLowerCase().contains('medicine');

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _unitController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _snack(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : AppTokens.statusDelivered,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedImage = image;
        _previewBytes = bytes;
        _imageError = false;
        _dirty = true;
      });
    } catch (e) {
      _snack(userMessageFor(e, fallback: "Couldn't open the photo library."));
    }
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes on this product.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() {
      _categoryError = _category.isEmpty;
      _imageError = !_isEditing && _pickedImage == null;
    });
    if (!formOk || _categoryError || _imageError) {
      _snack('Please fix the highlighted fields.');
      return;
    }

    setState(() => _isSubmitting = true);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final old = widget.existing;

    try {
      var imageUrl = old?.imageUrl ?? '';
      if (_pickedImage != null && _previewBytes != null) {
        final uploaded = await CloudinaryService().uploadBytes(
          _previewBytes!,
          filename: _pickedImage!.name,
        );
        if (uploaded == null) throw Exception('Image upload failed.');
        imageUrl = uploaded;
      }

      final physical = _isEditing ? old!.physicalStock : int.parse(_stockController.text.trim());
      final reserved = _isEditing ? old!.reservedStock : 0;
      final available = physical - reserved;
      final oldGallery = old == null
          ? const <String>[]
          : old.imageUrls.where((u) => u != old.imageUrl).toList();

      // Everything the form doesn't show is carried over from the existing
      // product — the old sheet rebuilt the product from defaults, so every
      // edit silently reset tags, the featured flag, availability and the
      // image gallery.
      final product = ent.Product(
        id: old?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        price: double.parse(_priceController.text.trim()),
        // Empty field = no discount (the update removes any stored one).
        discountedPrice: double.tryParse(_discountController.text.trim()),
        imageUrl: imageUrl,
        imageUrls: _pickedImage != null ? [imageUrl, ...oldGallery] : (old?.imageUrls ?? const []),
        unit: _unitController.text.trim(),
        stock: available,
        physicalStock: physical,
        reservedStock: reserved,
        availableStock: available,
        lowStockThreshold: int.parse(_thresholdController.text.trim()),
        isAvailable: _isAvailable,
        isFeatured: old?.isFeatured ?? false,
        tags: old?.tags ?? const [],
        requiresPrescription: _isMedicine && _requiresPrescription,
      );

      final ok = _isEditing
          ? await productProvider.updateProduct(product)
          : await productProvider.addProduct(product);
      if (!mounted) return;
      if (ok) {
        _dirty = false;
        _snack(_isEditing ? 'Product updated.' : 'Product added to the catalog.', isError: false);
        Navigator.pop(context);
      } else {
        _snack('Failed to save: ${productProvider.errorMessage ?? 'unknown error'}');
      }
    } catch (e) {
      _snack(userMessageFor(e, fallback: "Couldn't save the product. Please try again."));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ───────────────────────── UI ─────────────────────────

  InputDecoration _decoration(String label, {IconData? icon, String? hint, String? helper, String? prefixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixText: prefixText,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
    );
  }

  Widget _section({required IconData icon, required String title, String? subtitle, required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.s16),
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.rSm),
                ),
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    if (subtitle != null)
                      Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s16),
          child,
        ],
      ),
    );
  }

  Widget _photoSection() {
    final scheme = Theme.of(context).colorScheme;
    final existingUrl = widget.existing?.imageUrl ?? '';

    Widget image;
    if (_previewBytes != null) {
      image = Image.memory(_previewBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else if (existingUrl.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: existingUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 40)),
      );
    } else {
      image = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppTokens.s8),
            Text('Add a product photo',
                style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text('Square, plain background works best',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final hasImage = _previewBytes != null || existingUrl.isNotEmpty;

    return _section(
      icon: Icons.photo_camera_outlined,
      title: 'Photo',
      subtitle: _isEditing ? 'Tap to replace the current photo' : 'Required for new products',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _isSubmitting ? null : _pickImage,
            borderRadius: BorderRadius.circular(AppTokens.rMd),
            child: Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                border: Border.all(
                  color: _imageError ? scheme.error : scheme.outlineVariant,
                  width: _imageError ? 1.6 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image,
                    if (hasImage)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppTokens.rPill),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              Text('Change', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_imageError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('Please add a product photo', style: TextStyle(color: scheme.error, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _detailsSection(List<String> categories) {
    final scheme = Theme.of(context).colorScheme;
    return _section(
      icon: Icons.inventory_2_outlined,
      title: 'Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            enabled: !_isSubmitting,
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            decoration: _decoration('Product name', icon: Icons.shopping_bag_outlined),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a product name' : null,
          ),
          const SizedBox(height: AppTokens.s8),
          TextFormField(
            controller: _descriptionController,
            enabled: !_isSubmitting,
            maxLines: 3,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Description', icon: Icons.notes_rounded),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a short description' : null,
          ),
          const SizedBox(height: AppTokens.s8),
          Text('Category', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: AppTokens.s8),
          Wrap(
            spacing: AppTokens.s8,
            runSpacing: AppTokens.s8,
            children: [
              for (final c in categories)
                ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  showCheckmark: false,
                  selectedColor: scheme.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _category == c ? scheme.primary : scheme.onSurface,
                  ),
                  onSelected: _isSubmitting
                      ? null
                      : (_) => setState(() {
                            _category = c;
                            _categoryError = false;
                            _dirty = true;
                            if (!_isMedicine) _requiresPrescription = false;
                          }),
                ),
            ],
          ),
          if (_categoryError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('Pick a category', style: TextStyle(color: scheme.error, fontSize: 12)),
            ),
          if (_isMedicine) ...[
            const SizedBox(height: AppTokens.s8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Requires prescription', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Customers see a prescription notice at checkout'),
              value: _requiresPrescription,
              onChanged: _isSubmitting
                  ? null
                  : (v) => setState(() {
                        _requiresPrescription = v;
                        _dirty = true;
                      }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pricingSection() {
    return _section(
      icon: Icons.sell_outlined,
      title: 'Pricing',
      subtitle: 'What the customer pays per unit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: _decoration('Price', prefixText: '₹ '),
                  validator: (v) {
                    final p = double.tryParse((v ?? '').trim());
                    if (p == null || p <= 0) return 'Enter a price above 0';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: TextFormField(
                  controller: _unitController,
                  enabled: !_isSubmitting,
                  decoration: _decoration('Unit', hint: 'e.g. 1 kg'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a unit' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s12),
          TextFormField(
            controller: _discountController,
            enabled: !_isSubmitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: (_) => _dirty = true,
            decoration: _decoration(
              'Discounted price (optional)',
              prefixText: '₹ ',
              hint: 'Leave empty for no discount',
            ),
            validator: (v) {
              final text = (v ?? '').trim();
              if (text.isEmpty) return null;
              final discounted = double.tryParse(text);
              final price = double.tryParse(_priceController.text.trim());
              if (discounted == null || discounted <= 0) return 'Enter an amount above 0';
              if (price != null && discounted >= price) {
                return 'Must be below the price';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTokens.s4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available for sale'),
            subtitle: const Text('Turn off to stop orders without deleting the product'),
            value: _isAvailable,
            onChanged: _isSubmitting
                ? null
                : (v) => setState(() {
                      _isAvailable = v;
                      _dirty = true;
                    }),
          ),
          const SizedBox(height: AppTokens.s8),
          Wrap(
            spacing: AppTokens.s8,
            runSpacing: 0,
            children: [
              for (final u in _unitSuggestions)
                ActionChip(
                  label: Text(u, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _unitController.text = u;
                            _dirty = true;
                          }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTokens.rMd),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _inventorySection() {
    final scheme = Theme.of(context).colorScheme;
    final thresholdField = TextFormField(
      controller: _thresholdController,
      enabled: !_isSubmitting,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _decoration(
        'Low-stock alert at',
        icon: Icons.notifications_active_outlined,
        helper: 'Shows in Stock Alerts when available units drop below this',
      ),
      validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Enter a number' : null,
    );

    if (!_isEditing) {
      return _section(
        icon: Icons.warehouse_outlined,
        title: 'Inventory',
        subtitle: 'Opening stock is recorded in the inventory ledger',
        child: Column(
          children: [
            TextFormField(
              controller: _stockController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _decoration('Opening stock (units)', icon: Icons.inventory_outlined),
              validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Enter the opening stock (0 or more)' : null,
            ),
            const SizedBox(height: AppTokens.s16),
            thresholdField,
          ],
        ),
      );
    }

    final existing = widget.existing!;
    return _section(
      icon: Icons.warehouse_outlined,
      title: 'Inventory',
      subtitle: 'Live counts — changes are logged in the ledger',
      child: StreamBuilder<List<ent.Product>>(
        stream: _productsStream,
        builder: (context, snapshot) {
          final live = (snapshot.data ?? const <ent.Product>[])
              .where((p) => p.id == existing.id)
              .firstOrNull;
          final p = live ?? existing;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _statPill('Physical', p.physicalStock, AppTokens.statusAssigned),
                  const SizedBox(width: AppTokens.s8),
                  _statPill('Reserved', p.reservedStock, AppTokens.accent),
                  const SizedBox(width: AppTokens.s8),
                  _statPill('Available', p.availableStock,
                      p.availableStock <= 0 ? scheme.error : AppTokens.statusDelivered),
                ],
              ),
              const SizedBox(height: AppTokens.s12),
              OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: scheme.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) => ProductLedgerSheet(product: p),
                        ),
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Adjust stock (restock / correction)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                ),
              ),
              const SizedBox(height: AppTokens.s16),
              thresholdField,
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_dirty || _isSubmitting,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) nav.pop();
      },
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLow,
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Product' : 'Add Product',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: scheme.surface,
          elevation: 0.5,
        ),
        body: StreamBuilder<AppConfig>(
          stream: Provider.of<ConfigProvider>(context, listen: false).streamAppConfig(),
          builder: (context, snapshot) {
            // Admin-configured categories (the same list customers browse by);
            // the hardcoded list is only a fallback for a fresh project. A
            // legacy product's own category is always kept selectable.
            final configured = snapshot.data?.categories ?? const <String>[];
            final categories = [...(configured.isNotEmpty ? configured : _fallbackCategories)];
            if (_category.isNotEmpty && !categories.contains(_category)) categories.insert(0, _category);

            return Form(
              key: _formKey,
              // setState on the first change so PopScope (canPop) rebuilds.
              onChanged: () {
                if (!_dirty) setState(() => _dirty = true);
              },
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s16, AppTokens.s16, 120),
                children: [
                  _photoSection(),
                  _detailsSection(categories),
                  _pricingSection(),
                  _inventorySection(),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(AppTokens.s16, AppTokens.s12, AppTokens.s16, AppTokens.s12),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                      )
                    : Icon(_isEditing ? Icons.check_rounded : Icons.add_rounded),
                label: Text(
                  _isSubmitting
                      ? 'Saving…'
                      : (_isEditing ? 'Save changes' : 'Create product'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
