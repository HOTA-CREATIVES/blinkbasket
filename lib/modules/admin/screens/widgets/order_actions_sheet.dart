import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/design/app_tokens.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/order_provider.dart';
import '../../../../domain/entities/order.dart';

/// Admin interventions for a single active order: cancel it, hand it back to
/// the rider pool, or clear a locked-out delivery OTP. Without these, an order
/// stuck with a dead rider or a maxed-out OTP had no way out from the app.
void showOrderActionsSheet(BuildContext context, Order order) {
  final orderProvider = Provider.of<OrderProvider>(context, listen: false);
  final adminId =
      Provider.of<AuthProvider>(context, listen: false).currentUserModel?.uid ?? '';
  final messenger = ScaffoldMessenger.of(context);

  Future<void> run(Future<String?> Function() action, String successMessage) async {
    final error = await action();
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? successMessage),
      backgroundColor: error == null ? AppTokens.statusDelivered : AppTokens.statusCancelled,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<bool> confirm(BuildContext ctx, String title, String body, String yes) async {
    final result = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Back')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true), child: Text(yes)),
        ],
      ),
    );
    return result == true;
  }

  final hasRider = (order.deliveryBoyId ?? '').isNotEmpty;

  showModalBottomSheet(
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Order #${order.id.substring(0, 6).toUpperCase()} • ${order.customerName}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('Status: ${order.status.replaceAll('_', ' ')}'),
            ),
            const Divider(height: 1),
            if (hasRider)
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Return to rider pool'),
                subtitle: const Text('Unassigns the rider and re-offers the order'),
                onTap: () async {
                  final nav = Navigator.of(sheetCtx);
                  if (!await confirm(
                    sheetCtx,
                    'Unassign rider?',
                    'The order goes back to pending and is re-offered to on-duty riders.',
                    'Unassign',
                  )) {
                    return;
                  }
                  nav.pop();
                  await run(() => orderProvider.adminUnassignOrder(order.id),
                      'Order returned to the rider pool.');
                },
              ),
            if (order.status == 'out_for_delivery')
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded),
                title: const Text('Reset OTP attempts'),
                subtitle: const Text('Unlocks delivery OTP entry for the rider'),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await run(() => orderProvider.resetOtpAttempts(order.id), 'OTP attempts reset.');
                },
              ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: AppTokens.statusCancelled),
              title: const Text(
                'Cancel order',
                style: TextStyle(color: AppTokens.statusCancelled, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Releases the reserved stock'),
              onTap: () async {
                final nav = Navigator.of(sheetCtx);
                if (!await confirm(
                  sheetCtx,
                  'Cancel this order?',
                  'The customer and rider are notified and the reserved stock is released. This cannot be undone.',
                  'Cancel order',
                )) {
                  return;
                }
                nav.pop();
                await run(
                    () => orderProvider.adminCancelOrder(order.id, adminId, 'Cancelled by admin'),
                    'Order cancelled.');
              },
            ),
          ],
        ),
      ),
    ),
  );
}
