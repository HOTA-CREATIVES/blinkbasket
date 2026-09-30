import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/design/widgets/empty_state.dart';
import '../../../core/utils/route_generator.dart';

class AddressBookScreen extends StatelessWidget {
  const AddressBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUserModel;
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("No active user session.")),
      );
    }

    final addresses = user.addresses;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(
          "Address Book",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Tooltip(
            message: 'Add Address',
            child: IconButton(
              icon: Icon(Icons.add_circle_outline_rounded, color: scheme.primary),
              onPressed: () {
                Navigator.pushNamed(context, RouteGenerator.addAddress);
              },
            ),
          ),
        ],
      ),
      body: addresses.isEmpty
          ? EmptyState(
              icon: Icons.location_off_rounded,
              title: "No addresses saved",
              message: "Add an address for faster quick-commerce delivery.",
              actionLabel: "Add Address",
              onAction: () => Navigator.pushNamed(context, RouteGenerator.addAddress),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppTokens.s16),
              itemCount: addresses.length,
              separatorBuilder: (c, i) => const SizedBox(height: AppTokens.s12),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return Card(
                  elevation: 0,
                  color: scheme.surface,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTokens.primary.withValues(alpha: 0.08),
                      child: Icon(Icons.home_work_rounded, color: scheme.primary),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            address.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: AppTokens.s8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppTokens.rPill),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      "${address.addressLine1}, ${address.village}, ${address.mandal} - ${address.pinCode}",
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!address.isDefault)
                          Tooltip(
                            message: 'Set as default',
                            child: IconButton(
                              icon: Icon(Icons.star_border_rounded, color: scheme.primary),
                              onPressed: () => Provider.of<ProfileProvider>(context, listen: false)
                                  .setDefaultAddress(address.id),
                            ),
                          ),
                        Tooltip(
                          message: 'Edit',
                          child: IconButton(
                            icon: Icon(Icons.edit_outlined, color: scheme.primary),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                RouteGenerator.editAddress,
                                arguments: address,
                              );
                            },
                          ),
                        ),
                        Tooltip(
                          message: 'Delete',
                          child: IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                RouteGenerator.deleteAddress,
                                arguments: address,
                              );
                            },
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
