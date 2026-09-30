import 'package:flutter/material.dart';
import '../../providers/cart_provider.dart';
import '../app_tokens.dart';

/// Tells the customer what changed in their cart since they built it, and asks
/// whether to go on. Returns true for "Continue", false for "Review cart" (or
/// dismissing).
Future<bool> showCartChangesDialog(
  BuildContext context,
  List<CartChange> changes, {
  String continueLabel = 'Continue',
}) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Your cart was updated'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Some items changed while they were in your cart:'),
            const SizedBox(height: AppTokens.s12),
            for (final change in changes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      change.kind == CartChangeKind.priceChanged
                          ? Icons.sell_outlined
                          : Icons.inventory_2_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: AppTokens.s8),
                    Expanded(child: Text(change.message)),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Review cart'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(continueLabel),
        ),
      ],
    ),
  );
  return proceed ?? false;
}
