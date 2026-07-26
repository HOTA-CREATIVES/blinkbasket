import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_tokens.dart';

/// Compact - qty + stepper used on product cards and in the cart.
class QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool canIncrement;

  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.canIncrement = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppTokens.rMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              onDecrement();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.s4),
            child: Text(
              '$quantity',
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            onTap: canIncrement
                ? () {
                    HapticFeedback.selectionClick();
                    onIncrement();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.rMd),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s8),
        child: Icon(
          icon,
          size: 20,
          color: onTap == null
              ? scheme.onPrimary.withValues(alpha: 0.4)
              : scheme.onPrimary,
        ),
      ),
    );
  }
}
