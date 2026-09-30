/// One rupee format for the whole app: whole amounts without decimals
/// (`₹50`), everything else with two (`₹49.50`), so the same figure never
/// reads as `₹49.0` on one screen and `₹49.00` on another.
String formatRupees(double amount) => '₹${formatAmount(amount)}';

/// [formatRupees] without the currency symbol.
String formatAmount(double amount) => amount == amount.roundToDouble()
    ? amount.toStringAsFixed(0)
    : amount.toStringAsFixed(2);
