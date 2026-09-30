import 'package:flutter/material.dart';
import '../../utils/money.dart';
import '../app_tokens.dart';

/// One label / amount line of a bill (cart, checkout, order receipt).
///
/// The label takes the space that is left and wraps, so a long label or large
/// system text pushes the label onto a second line instead of running the amount
/// off the edge of the card.
class BillRow extends StatelessWidget {
  final String label;
  final String value;

  /// Bold, larger row for the total.
  final bool emphasised;

  /// Colour for the amount (defaults to the row's text colour).
  final Color? valueColor;

  const BillRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasised = false,
    this.valueColor,
  }) : _fee = null;

  /// The delivery-fee line: the fee, or — when delivery is free — the fee
  /// struck through beside "FREE".
  const BillRow.deliveryFee({
    super.key,
    required double fee,
    required bool isFree,
  })  : label = 'Delivery fee',
        value = '',
        emphasised = false,
        valueColor = null,
        _fee = (fee, isFree);

  final (double fee, bool isFree)? _fee;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      color: emphasised ? scheme.onSurface : scheme.onSurfaceVariant,
      fontWeight: emphasised ? FontWeight.w800 : FontWeight.w400,
      fontSize: emphasised ? 17 : null,
    );
    final valueStyle = TextStyle(
      fontWeight: emphasised ? FontWeight.w800 : FontWeight.w400,
      fontSize: emphasised ? 17 : null,
      color: valueColor ?? (emphasised ? scheme.primary : null),
    );

    final Widget amount;
    final fee = _fee;
    if (fee != null && fee.$2) {
      amount = Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '${formatRupees(fee.$1)} ',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          TextSpan(
            text: 'FREE',
            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
          ),
        ]),
        textAlign: TextAlign.end,
      );
    } else if (fee != null) {
      amount = Text(formatRupees(fee.$1), style: valueStyle);
    } else {
      amount = Text(value, style: valueStyle, textAlign: TextAlign.end);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: AppTokens.s12),
          // Never wider than the space that is left; a very long amount wraps.
          Flexible(child: amount),
        ],
      ),
    );
  }
}
