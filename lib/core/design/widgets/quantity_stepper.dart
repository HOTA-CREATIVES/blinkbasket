import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../app_tokens.dart';

/// Premium Quick-Commerce Quantity Stepper (- QTY +)
/// Styled like top-tier quick commerce apps (Blinkit / Zepto / Swiggy Instamart).
class QuantityStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool canIncrement;
  final double height;
  final String? productName;

  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.canIncrement = true,
    this.height = 36,
    this.productName,
  });

  @override
  Widget build(BuildContext context) {
    final itemLabel = productName != null ? ' of $productName' : '';
    return Semantics(
      container: true,
      label: 'Quantity stepper, current quantity $quantity$itemLabel',
      child: Container(
        height: height,
        constraints: const BoxConstraints(minWidth: 80),
        decoration: BoxDecoration(
          color: AppTokens.primary,
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          boxShadow: AppTokens.shadowSm(AppTokens.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StepperButton(
              icon: Icons.remove_rounded,
              semanticLabel: 'Decrease quantity$itemLabel',
              onTap: () {
                HapticFeedback.lightImpact();
                onDecrement();
                if (productName != null) {
                  try {
                    SemanticsService.sendAnnouncement(
                      View.of(context),
                      'Decreased quantity$itemLabel to ${quantity - 1}',
                      TextDirection.ltr,
                    );
                  } catch (_) {}
                }
              },
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Text(
                  '$quantity',
                  key: ValueKey<int>(quantity),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            _StepperButton(
              icon: Icons.add_rounded,
              semanticLabel: 'Increase quantity$itemLabel',
              onTap: canIncrement
                  ? () {
                      HapticFeedback.lightImpact();
                      onIncrement();
                      if (productName != null) {
                        try {
                          SemanticsService.sendAnnouncement(
                            View.of(context),
                            'Increased quantity$itemLabel to ${quantity + 1}',
                            TextDirection.ltr,
                          );
                        } catch (_) {}
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  const _StepperButton({required this.icon, required this.semanticLabel, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Icon(
              icon,
              size: 18,
              color: onTap == null ? Colors.white.withValues(alpha: 0.4) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
