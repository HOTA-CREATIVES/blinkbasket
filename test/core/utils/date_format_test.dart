import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/utils/date_format.dart';

void main() {
  test('formatDate is day, short month, year', () {
    expect(formatDate(DateTime(2026, 9, 30)), '30 Sep 2026');
    expect(formatDate(DateTime(2027, 1, 5)), '5 Jan 2027');
  });

  test('formatDateTime uses a 12-hour clock with padded minutes', () {
    expect(formatDateTime(DateTime(2026, 9, 30, 16, 5)), '30 Sep 2026, 4:05 PM');
    expect(formatDateTime(DateTime(2026, 9, 30, 0, 0)), '30 Sep 2026, 12:00 AM');
    expect(formatDateTime(DateTime(2026, 9, 30, 12, 30)), '30 Sep 2026, 12:30 PM');
    expect(formatDateTime(DateTime(2026, 9, 30, 9, 7)), '30 Sep 2026, 9:07 AM');
  });
}
