import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/providers/banner_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../domain/entities/banner_item.dart';
import '../../../domain/entities/app_config.dart';
import '../../../core/utils/app_exception.dart';

class BannerManagementScreen extends StatefulWidget {
  const BannerManagementScreen({super.key});

  @override
  State<BannerManagementScreen> createState() => _BannerManagementScreenState();
}

class _BannerManagementScreenState extends State<BannerManagementScreen> {
  void _showAddEditBannerSheet(BuildContext context, {BannerItem? banner}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AddEditBannerSheet(banner: banner),
    );
  }

  void _confirmDeleteBanner(BuildContext context, String bannerId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Banner?'),
          content: const Text('Are you sure you want to permanently delete this promotional banner?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await Provider.of<BannerProvider>(context, listen: false).deleteBanner(bannerId);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Banner deleted successfully.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text('DELETE', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bannerProvider = Provider.of<BannerProvider>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promo Banners', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<BannerItem>>(
        stream: bannerProvider.streamAllBanners(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppTokens.primary));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.view_carousel_outlined, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No promotional banners created yet.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          final banners = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(AppTokens.s16),
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];

              return Card(
                margin: const EdgeInsets.only(bottom: AppTokens.s12),
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.s12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTokens.rMd),
                        child: CachedNetworkImage(
                          imageUrl: banner.imageUrl,
                          width: 100,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 100,
                            height: 60,
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 100,
                            height: 60,
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            child: Icon(Icons.broken_image, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              banner.category != null && banner.category!.isNotEmpty
                                  ? 'Target: ${banner.category}'
                                  : 'Target: General / Main Rail',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sort Order: ${banner.sortOrder}',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 4),
                                SizedBox(
                                  height: 24,
                                  child: Switch(
                                    value: banner.isActive,
                                    activeThumbColor: scheme.primary,
                                    onChanged: (val) async {
                                      final updated = BannerItem(
                                        id: banner.id,
                                        imageUrl: banner.imageUrl,
                                        category: banner.category,
                                        isActive: val,
                                        sortOrder: banner.sortOrder,
                                        createdAt: banner.createdAt,
                                      );
                                      await bannerProvider.updateBanner(updated);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: 'Move Up',
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    final updated = BannerItem(
                                      id: banner.id,
                                      imageUrl: banner.imageUrl,
                                      category: banner.category,
                                      isActive: banner.isActive,
                                      sortOrder: banner.sortOrder - 1,
                                      createdAt: banner.createdAt,
                                    );
                                    await bannerProvider.updateBanner(updated);
                                  },
                                ),
                              ),
                              Tooltip(
                                message: 'Move Down',
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    final updated = BannerItem(
                                      id: banner.id,
                                      imageUrl: banner.imageUrl,
                                      category: banner.category,
                                      isActive: banner.isActive,
                                      sortOrder: banner.sortOrder + 1,
                                      createdAt: banner.createdAt,
                                    );
                                    await bannerProvider.updateBanner(updated);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: 'Edit Banner',
                                child: IconButton(
                                  icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showAddEditBannerSheet(context, banner: banner),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Delete Banner',
                                child: IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error, size: 18),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _confirmDeleteBanner(context, banner.id),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditBannerSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddEditBannerSheet extends StatefulWidget {
  final BannerItem? banner;
  const _AddEditBannerSheet({this.banner});

  @override
  State<_AddEditBannerSheet> createState() => _AddEditBannerSheetState();
}

class _AddEditBannerSheetState extends State<_AddEditBannerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _sortOrderController = TextEditingController(text: '0');
  String? _selectedCategory;
  bool _isActive = true;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  final List<String> _defaultCategories = [
    'Fruits & Vegetables',
    'Dairy & Eggs',
    'Bakery',
    'Medicines',
    'Snacks',
    'Beverages',
    'Household',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.banner != null) {
      _sortOrderController.text = widget.banner!.sortOrder.toString();
      _selectedCategory = widget.banner!.category;
      _isActive = widget.banner!.isActive;
    }
  }

  @override
  void dispose() {
    _sortOrderController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
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
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      _showSnackBar(userMessageFor(e, fallback: "Couldn't open the photo library."));
    }
  }

  Future<void> _submitBanner() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.banner == null && _imageFile == null) {
      _showSnackBar('Please upload a banner photo.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final bannerProvider = Provider.of<BannerProvider>(context, listen: false);
    String? imageUrl = widget.banner?.imageUrl;

    try {
      if (_imageFile != null) {
        final cloudinary = CloudinaryService();
        imageUrl = await cloudinary.uploadImage(_imageFile!);
        if (imageUrl == null) {
          throw Exception('Image upload failed.');
        }
      }

      final sortOrder = int.parse(_sortOrderController.text.trim());

      final bannerItem = BannerItem(
        id: widget.banner?.id ?? '',
        imageUrl: imageUrl!,
        category: _selectedCategory,
        isActive: _isActive,
        sortOrder: sortOrder,
        createdAt: widget.banner?.createdAt ?? DateTime.now(),
      );

      bool success;
      if (widget.banner != null) {
        success = await bannerProvider.updateBanner(bannerItem);
      } else {
        success = await bannerProvider.addBanner(bannerItem);
      }

      if (success) {
        _showSnackBar(
          widget.banner != null ? 'Banner updated successfully!' : 'Banner added successfully!',
          isError: false,
        );
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        _showSnackBar(bannerProvider.errorMessage ?? 'Failed to save banner.');
      }
    } catch (e) {
      _showSnackBar(userMessageFor(e, fallback: "Couldn't save the banner. Please try again."));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<AppConfig>(
      stream: Provider.of<ConfigProvider>(context, listen: false).streamAppConfig(),
      builder: (context, configSnapshot) {
        List<String> categories = _defaultCategories;
        if (configSnapshot.hasData && configSnapshot.data!.categories.isNotEmpty) {
          categories = configSnapshot.data!.categories;
        }

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.banner != null ? 'Edit Promo Banner' : 'Add New Promo Banner',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _isSubmitting ? null : _pickImage,
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
                              )
                            : (widget.banner != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: CachedNetworkImage(
                                      imageUrl: widget.banner!.imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      const SizedBox(height: 8),
                                      Text('Tap to upload banner photo', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                                    ],
                                  )),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Target Category (Optional)',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      hint: const Text('None (General / Home Rail)'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None (General / Home Rail)'),
                        ),
                        ...categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        })
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (val) {
                              setState(() {
                                _selectedCategory = val;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sortOrderController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Sort Order',
                        prefixIcon: const Icon(Icons.sort_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter sort order';
                        if (int.tryParse(val.trim()) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Active', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Show this banner on the customer home screen'),
                      value: _isActive,
                      activeThumbColor: scheme.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: _isSubmitting
                          ? null
                          : (val) {
                              setState(() {
                                _isActive = val;
                              });
                            },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitBanner,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                const Text('Saving...'),
                              ],
                            )
                          : const Text('SAVE BANNER', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
