import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/utils/phone.dart';

void main() {
  group('normalizeIndianMobile', () {
    test('canonicalises every accepted spelling to the 10 digits', () {
      for (final raw in [
        '9876543210',
        '+91 98765 43210',
        '+919876543210',
        '919876543210',
        '09876543210',
        '98765-43210',
        ' 9876543210 ',
      ]) {
        expect(normalizeIndianMobile(raw), '9876543210', reason: raw);
      }
    });

    test('rejects numbers a rider could not call', () {
      for (final raw in [
        null,
        '',
        '12345',
        '5876543210', // does not start with 6-9
        '98765abcde',
        '98765432101', // too long
        '+1 9876543210',
      ]) {
        expect(normalizeIndianMobile(raw), isNull, reason: '$raw');
      }
    });
  });

  group('validateIndianMobile', () {
    test('asks for a number when empty', () {
      expect(validateIndianMobile(''), isNotNull);
      expect(validateIndianMobile('   '), isNotNull);
      expect(validateIndianMobile(null), isNotNull);
    });

    test('accepts a valid number and rejects a short one', () {
      expect(validateIndianMobile('9876543210'), isNull);
      expect(validateIndianMobile('98765'), isNotNull);
    });
  });
}
