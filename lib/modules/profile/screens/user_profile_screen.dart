import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../domain/entities/order.dart';
import '../widgets/edit_profile_dialog.dart';
import '../../../core/utils/route_generator.dart';
import '../../../core/utils/app_exception.dart';

class UserProfileScreen extends StatefulWidget {
  final bool isEmbedded;
  const UserProfileScreen({super.key, this.isEmbedded = false});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text("Uploading profile photo..."),
              ],
            ),
            duration: Duration(seconds: 1),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 800));
        await profileProvider.updateAvatar(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessageFor(e, fallback: "Couldn't open the photo library.")), backgroundColor: AppTokens.statusCancelled),
        );
      }
    }
  }

  void _showAvatarPicker(UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTokens.rXl),
          topRight: Radius.circular(AppTokens.rXl),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(AppTokens.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Update Profile Photo",
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.s24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: "Camera",
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    label: "Gallery",
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                    _buildPickerOption(
                      icon: Icons.delete_outline_rounded,
                      label: "Remove",
                      color: AppTokens.statusCancelled,
                      onTap: () async {
                        Navigator.pop(context);
                        final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
                        await profileProvider.deleteAvatar();
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.s16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppTokens.primary,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.rLg),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: AppTokens.s16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.rLg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: AppTokens.s8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProfileDialog(user: user),
    );
  }

  Future<void> _shareInvite() async {
    await Share.share(
      "I'm shopping on J C Mart — fast hyperlocal delivery with Cash on Delivery! Download now & order fresh groceries.",
      subject: "Try J C Mart",
    );
  }


  Future<void> _confirmLogout(AuthProvider authProvider) async {
    final scheme = Theme.of(context).colorScheme;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rXl)),
        title: const Text("Log out?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("You will need to sign in again to access your account."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
            child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.statusCancelled,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    await authProvider.logout();
    if (mounted) {
      nav.pushNamedAndRemoveUntil(RouteGenerator.login, (route) => false);
    }
  }

  Future<void> _confirmDeleteAccount(AuthProvider authProvider) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rXl)),
        title: const Text("Delete Account?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text(
          "Are you sure you want to permanently delete your account? "
          "All personal details, saved addresses, and active preferences will be erased. "
          "This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
            child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text("Delete Account", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final success = await authProvider.deleteAccount();
    if (!mounted) return;
    if (success) {
      nav.pushNamedAndRemoveUntil(RouteGenerator.login, (route) => false);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? "Failed to delete account"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isRider = user.role == 'delivery';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isRider ? "Rider Profile" : "My Profile",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        leading: widget.isEmbedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppTokens.s16),

            // 1. Clean Profile Info Card
            _buildCleanProfileCard(user, isRider: isRider),

            const SizedBox(height: AppTokens.s16),

            // 2. Active Order Live Tracking Banner (customers only)
            if (!isRider) ...[
              _ActiveOrderBanner(customerId: user.uid),
              const SizedBox(height: AppTokens.s20),

              // 3. Section 1: Orders & Wishlist (customers only)
              _buildSectionHeader("MY ORDERS & SAVED"),
              _buildCardContainer([
                _buildMenuTile(
                  icon: Icons.shopping_basket_outlined,
                  title: "Your Orders",
                  subtitle: "View order history and track live deliveries",
                  onTap: () {
                    Navigator.pushNamed(context, RouteGenerator.orderHistory);
                  },
                ),
                const Divider(height: 1, indent: 56),
                _buildMenuTile(
                  icon: Icons.location_on_outlined,
                  title: "Address Book",
                  subtitle: user.addresses.isNotEmpty
                      ? "${user.addresses.length} saved delivery address${user.addresses.length > 1 ? 'es' : ''}"
                      : "Manage delivery addresses",
                  badgeText: user.addresses.isNotEmpty ? "${user.addresses.length}" : null,
                  onTap: () {
                    Navigator.pushNamed(context, RouteGenerator.addressBook);
                  },
                ),
                const Divider(height: 1, indent: 56),
                _buildMenuTile(
                  icon: Icons.favorite_border_rounded,
                  title: "Wishlist",
                  subtitle: user.favoriteProductIds.isNotEmpty
                      ? "${user.favoriteProductIds.length} saved item${user.favoriteProductIds.length > 1 ? 's' : ''}"
                      : "Your favorite saved items",
                  badgeText: user.favoriteProductIds.isNotEmpty ? "${user.favoriteProductIds.length}" : null,
                  onTap: () {
                    Navigator.pushNamed(context, RouteGenerator.wishlist);
                  },
                ),
              ]),
              const SizedBox(height: AppTokens.s20),
            ],

            // 4. Section 2: Preferences & Support
            _buildSectionHeader("HELP & PREFERENCES"),
            _buildCardContainer([
              _buildMenuTile(
                icon: Icons.support_agent_rounded,
                title: isRider ? "Partner Support & FAQs" : "Customer Support & FAQs",
                subtitle: "Live chat & support tickets",
                onTap: () {
                  Navigator.pushNamed(context, RouteGenerator.customerSupport);
                },
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(AppTokens.s8),
                  decoration: BoxDecoration(
                    color: AppTokens.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTokens.rMd),
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: AppTokens.primary, size: 20),
                ),
                title: const Text(
                  "Order Notifications",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  isRider ? "Alerts for new assigned orders & updates" : "Push alerts for delivery status updates",
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                activeThumbColor: AppTokens.primary,
                value: user.notificationsEnabled,
                onChanged: (enabled) {
                  Provider.of<ProfileProvider>(context, listen: false).setNotificationsEnabled(enabled);
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildMenuTile(
                icon: Icons.share_outlined,
                title: "Share J C Mart",
                subtitle: "Invite friends & family",
                onTap: _shareInvite,
              ),
              const Divider(height: 1, indent: 56),
              _buildMenuTile(
                icon: Icons.gavel_outlined,
                title: "Terms & Conditions",
                subtitle: "Service terms & guidelines",
                onTap: () {
                  Navigator.pushNamed(context, RouteGenerator.termsConditions);
                },
              ),
              const Divider(height: 1, indent: 56),
              _buildMenuTile(
                icon: Icons.privacy_tip_outlined,
                title: "Privacy Policy & App Info",
                subtitle: "Data protection & version details",
                onTap: () {
                  Navigator.pushNamed(context, RouteGenerator.privacyPolicy);
                },
              ),
            ]),

            const SizedBox(height: AppTokens.s24),

            // 5. Log Out & Account Deletion Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppTokens.statusCancelled,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rLg)),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        "Log Out",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () => _confirmLogout(authProvider),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: scheme.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rLg)),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded, size: 20),
                      label: const Text(
                        "Delete Account",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: () => _confirmDeleteAccount(authProvider),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom padding to ensure buttons clear bottom navbar cleanly
            const SizedBox(height: 120.0),
          ],
        ),
      ),
    );
  }

  // Smooth, Clean Profile Card
  Widget _buildCleanProfileCard(UserModel user, {bool isRider = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s20),
      child: Container(
        padding: const EdgeInsets.all(AppTokens.s20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppTokens.rXl),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: AppTokens.shadowSm(Colors.black),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.surfaceContainerLowest,
                        border: Border.all(color: AppTokens.primary.withValues(alpha: 0.2), width: 2),
                      ),
                      child: ClipOval(
                        child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                            ? (user.avatarUrl!.startsWith('http')
                                ? Image.network(
                                    user.avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => _buildPlaceholderAvatar(),
                                  )
                                : Image.file(
                                    File(user.avatarUrl!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => _buildPlaceholderAvatar(),
                                  ))
                            : _buildPlaceholderAvatar(),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _showAvatarPicker(user),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: AppTokens.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 12,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppTokens.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isNotEmpty ? user.name : (isRider ? "Delivery Partner" : "J C Mart Customer"),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.phone.isNotEmpty ? user.phone : (user.email.isNotEmpty ? user.email : "No Contact Linked"),
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                      if (user.village.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: AppTokens.primary),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                user.village,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTokens.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isRider)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTokens.primary, size: 20),
                    onPressed: () => _showEditProfileDialog(user),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.s16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            if (isRider)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTokens.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTokens.rMd),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.two_wheeler_rounded, color: AppTokens.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Verified Delivery Partner",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTokens.primary,
                      ),
                    ),
                  ],
                ),
              )
            else
              // Clean 2-Column Stats (Orders & Saved Addresses)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "${user.totalOrders}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTokens.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Total Orders",
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 28, width: 1, color: scheme.outlineVariant),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "${user.addresses.length}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTokens.primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Saved Addresses",
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: AppTokens.s24, bottom: AppTokens.s8),
      child: Text(
        title,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s20),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppTokens.rXl),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: AppTokens.shadowSm(Colors.black),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppTokens.s8),
        decoration: BoxDecoration(
          color: AppTokens.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTokens.rMd),
        ),
        child: Icon(icon, color: AppTokens.primary, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: scheme.onSurface)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeText != null)
            Container(
              margin: const EdgeInsets.only(right: AppTokens.s8),
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s8, vertical: AppTokens.s4),
              decoration: BoxDecoration(
                color: AppTokens.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTokens.rPill),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTokens.primary),
              ),
            ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: scheme.onSurfaceVariant),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: AppTokens.primary.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          size: 36,
          color: AppTokens.primary,
        ),
      ),
    );
  }
}

/// Live banner shown at the top of the profile when the customer has an
/// order in progress. Taps through to that order's tracking screen.
class _ActiveOrderBanner extends StatelessWidget {
  final String customerId;

  const _ActiveOrderBanner({required this.customerId});

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return StreamBuilder<List<Order>>(
      stream: orderProvider.streamCustomerOrders(customerId),
      builder: (context, snapshot) {
        final active = (snapshot.data ?? [])
            .where((o) => o.status != 'delivered' && o.status != 'cancelled')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (active.isEmpty) return const SizedBox.shrink();

        final latest = active.first;
        final extra = active.length - 1;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.rLg),
              onTap: () => Navigator.pushNamed(
                context,
                RouteGenerator.orderTracking,
                arguments: latest.id,
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF0D9488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.rLg),
                  boxShadow: AppTokens.shadowMd(AppTokens.primary),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppTokens.s8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: AppTokens.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                extra > 0
                                    ? "$extra more order${extra > 1 ? 's' : ''} in progress"
                                    : "Active Order in Progress",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: AppTokens.s8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTokens.brandChrome,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "#${latest.id.substring(0, latest.id.length < 6 ? latest.id.length : 6).toUpperCase()} · Tap to track status",
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
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
