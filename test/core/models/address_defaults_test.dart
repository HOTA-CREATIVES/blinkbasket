import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/models/user_model.dart';

AddressModel addr(String id, {bool isDefault = false}) => AddressModel(
      id: id,
      name: 'Home $id',
      addressLine1: 'Street $id',
      pinCode: '534201',
      village: 'Bhimavaram',
      mandal: 'Bhimavaram',
      isDefault: isDefault,
    );

UserModel userWith(List<AddressModel> addresses) => UserModel(
      uid: 'u1',
      name: 'Test',
      email: 't@example.com',
      phone: '9876543210',
      role: 'customer',
      village: 'Bhimavaram',
      createdAt: DateTime(2026, 1, 1),
      addresses: addresses,
    );

void main() {
  group('AddressModel.normalizeDefaults', () {
    test('leaves an empty list empty', () {
      expect(AddressModel.normalizeDefaults(const []), isEmpty);
    });

    test('promotes the first address when none is flagged default', () {
      final out = AddressModel.normalizeDefaults([addr('a'), addr('b')]);
      expect(out.map((a) => a.isDefault), [true, false]);
    });

    test('keeps the flagged default and demotes the rest', () {
      final out = AddressModel.normalizeDefaults([addr('a'), addr('b', isDefault: true), addr('c')]);
      expect(out.map((a) => a.isDefault), [false, true, false]);
    });

    test('collapses several flagged defaults to the first flagged one', () {
      final out = AddressModel.normalizeDefaults(
          [addr('a'), addr('b', isDefault: true), addr('c', isDefault: true)]);
      expect(out.map((a) => a.isDefault), [false, true, false]);
    });

    test('deleting the default address promotes the next one', () {
      final before = [addr('a', isDefault: true), addr('b'), addr('c')];
      final after = AddressModel.normalizeDefaults(before.where((a) => a.id != 'a').toList());
      expect(after.map((a) => a.id), ['b', 'c']);
      expect(after.map((a) => a.isDefault), [true, false]);
    });

    test('withDefault preserves every other field, including coordinates', () {
      final original = AddressModel(
        id: 'x',
        name: 'Farm',
        addressLine1: 'Plot 4',
        addressLine2: 'Near tank',
        pinCode: '534208',
        village: 'Rayakuduru',
        mandal: 'Bhimavaram',
        district: 'West Godavari',
        landmark: 'Temple',
        latitude: 16.5861,
        longitude: 81.5034,
      );
      final copy = original.withDefault(true);
      expect(copy.isDefault, isTrue);
      expect(copy.toMap()..remove('isDefault'), original.toMap()..remove('isDefault'));
    });
  });

  group('UserModel.defaultAddress', () {
    test('is null with no addresses', () {
      expect(userWith(const []).defaultAddress, isNull);
    });

    test('returns the flagged default, not simply the first', () {
      final u = userWith([addr('a'), addr('b', isDefault: true)]);
      expect(u.defaultAddress?.id, 'b');
    });

    test('falls back to the first address when none is flagged', () {
      final u = userWith([addr('a'), addr('b')]);
      expect(u.defaultAddress?.id, 'a');
    });
  });
}
