import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/design/app_tokens.dart';

class DeleteAddressScreen extends StatefulWidget {
  final AddressModel address;
  const DeleteAddressScreen({super.key, required this.address});

  @override
  State<DeleteAddressScreen> createState() => _DeleteAddressScreenState();
}

class _DeleteAddressScreenState extends State<DeleteAddressScreen> {
  bool _isDeleting = false;

  Future<void> _handleDelete(ProfileProvider profileProvider) async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    final success = await profileProvider.deleteAddress(widget.address.id);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Address deleted successfully."),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final address = widget.address;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text("Delete Address", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Warning Icon & Header
              Icon(Icons.warning_amber_rounded, size: 72, color: scheme.error),
              const SizedBox(height: AppTokens.s16),
              Text(
                "Delete Delivery Address?",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.s12),
              Text(
                "Are you sure you want to delete this saved address? This action cannot be undone.",
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTokens.s32),

              // Address Display Card
              Card(
                color: scheme.surface,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.s16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: scheme.error.withValues(alpha: 0.08),
                        child: Icon(Icons.home_work_rounded, color: scheme.error),
                      ),
                      const SizedBox(width: AppTokens.s16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              address.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: AppTokens.s4),
                            Text(
                              "${address.addressLine1}, ${address.village}, ${address.mandal} - ${address.pinCode}",
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                            if (address.landmark != null && address.landmark!.isNotEmpty) ...[
                              const SizedBox(height: AppTokens.s4),
                              Text(
                                "Landmark: ${address.landmark!}",
                                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Actions Buttons
              ElevatedButton(
                onPressed: _isDeleting ? null : () => _handleDelete(profileProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: AppTokens.s16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                ),
                child: _isDeleting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: scheme.onError),
                      )
                    : const Text("Delete Address", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const SizedBox(height: AppTokens.s12),
              OutlinedButton(
                onPressed: _isDeleting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppTokens.s16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rMd)),
                ),
                child: const Text("Keep Address", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
