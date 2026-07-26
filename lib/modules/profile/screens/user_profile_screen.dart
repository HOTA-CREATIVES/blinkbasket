import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/order_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../domain/entities/app_config.dart';
import '../../../domain/entities/order.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/profile_shimmer.dart';
import '../../customer/screens/order_history_screen.dart';
import '../../customer/screens/order_tracking_screen.dart';
import 'address_book_screen.dart';
import 'wishlist_screen.dart';

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
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
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
          SnackBar(content: Text("Error selecting image: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAvatarPicker(UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Update Profile Photo",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
                      color: Colors.red.shade700,
                      onTap: () async {
                        Navigator.pop(context);
                        final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
                        await profileProvider.deleteAvatar();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
    Color color = Colors.green,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
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
      "I'm shopping on J C Mart — fast hyperlocal delivery with Cash on Delivery. Give it a try!",
      subject: "Try J C Mart",
    );
  }

  Future<void> _showAboutSheet() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    showAboutDialog(
      context: context,
      applicationName: "J C Mart",
      applicationVersion: "v${info.version} (${info.buildNumber})",
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset('assets/images/logo.png', width: 48, height: 48),
      ),
      children: const [
        SizedBox(height: 12),
        Text(
          "Hyperlocal quick-commerce with Cash-on-Delivery. Fresh groceries "
          "and daily essentials delivered to your doorstep.",
        ),
      ],
    );
  }

  Future<void> _confirmLogout(AuthProvider authProvider) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Log out?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("You'll need to sign in again to access your account."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
            child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;
    if (!widget.isEmbedded && mounted) Navigator.pop(context);
    await authProvider.logout();
  }

  Future<void> _callSupport(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openSupportWhatsapp(String number) async {
    final uri = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showHelpDialog() {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Customer Support Helpline", style: TextStyle(fontWeight: FontWeight.bold)),
          content: StreamBuilder<AppConfig>(
            stream: configProvider.streamAppConfig(),
            builder: (context, snapshot) {
              final config = snapshot.data;
              final whatsapp = config?.supportWhatsapp;
              final phone = config?.supportPhone;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green),
                    title: const Text("Chat Assistance", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(whatsapp != null ? "Tap to chat on WhatsApp" : "Not available yet"),
                    onTap: whatsapp == null ? null : () => _openSupportWhatsapp(whatsapp),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_outlined, color: Colors.green),
                    title: const Text("Direct Phone Hotline", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(phone ?? "Not available yet"),
                    onTap: phone == null ? null : () => _callSupport(phone),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: const SafeArea(child: ProfileShimmer()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Your Account",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        leading: widget.isEmbedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.green, size: 28),
            onPressed: () => _showEditProfileDialog(user),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActiveOrderBanner(customerId: user.uid),
            const SizedBox(height: 24),
            // Profile photo, name, and phone details in a clean center section
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade200, width: 3),
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
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name.isNotEmpty ? user.name : "J C Mart User",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.phone.isNotEmpty ? user.phone : "No Phone Linked",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  if (user.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                  if (user.village.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.green.shade600),
                        const SizedBox(width: 3),
                        Text(
                          user.village,
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    "Member since ${_formatMemberSince(user.createdAt)}",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Quick Action Grid (2 Columns: Orders, Help)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OrderHistoryScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.shopping_basket_outlined, color: Colors.green, size: 28),
                            SizedBox(height: 6),
                            Text("Your orders", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _showHelpDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.support_agent_rounded, color: Colors.blue, size: 28),
                            SizedBox(height: 6),
                            Text("Need help?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Grouped lists: Your Information
            _buildSectionHeader("Your Information"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildMenuTile(
                      icon: Icons.menu_book_outlined,
                      title: "Address book",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddressBookScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildMenuTile(
                      icon: Icons.favorite_border_rounded,
                      title: "Your wishlist",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const WishlistScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Notification preferences
            _buildSectionHeader("Notifications"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SwitchListTile(
                  secondary: Icon(Icons.notifications_active_outlined, color: Colors.green.shade700),
                  title: const Text(
                    "Order updates",
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  subtitle: const Text(
                    "Get push alerts as your order moves",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  activeColor: Colors.green,
                  value: user.notificationsEnabled,
                  onChanged: (enabled) {
                    Provider.of<ProfileProvider>(context, listen: false)
                        .setNotificationsEnabled(enabled);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 5. More: invite + about
            _buildSectionHeader("More"),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildMenuTile(
                      icon: Icons.card_giftcard_rounded,
                      title: "Invite friends",
                      onTap: _shareInvite,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildMenuTile(
                      icon: Icons.info_outline_rounded,
                      title: "About J C Mart",
                      onTap: _showAboutSheet,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 5. Log out action button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade600, Colors.red.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade200.withValues(alpha: 0.6),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _confirmLogout(authProvider),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            "Log Out",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
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

  String _formatMemberSince(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: Colors.green.shade50,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 48,
          color: Colors.green.shade300,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, bottom: 10.0, top: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.green.shade700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderTrackingScreen(orderId: latest.id),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            extra > 0
                                ? "$extra more order${extra > 1 ? 's' : ''} in progress"
                                : "Order in progress",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "#${latest.id.substring(0, latest.id.length < 6 ? latest.id.length : 6).toUpperCase()} · Tap to track",
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
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
