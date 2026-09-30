import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/utils/money.dart';

void main() {
  test('whole amounts have no decimals', () {
    expect(formatRupees(50), '₹50');
    expect(formatRupees(49.0), '₹49');
    expect(formatRupees(0), '₹0');
  });

  test('fractional amounts always show two decimals', () {
    expect(formatRupees(49.5), '₹49.50');
    expect(formatRupees(12.345), '₹12.35');
  });

  test('formatAmount omits the symbol', () {
    expect(formatAmount(300), '300');
    expect(formatAmount(1.5), '1.50');
  });
}
