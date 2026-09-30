import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/models/user_model.dart';

void main() {
  group('UserModel.fromMap', () {
    test('parses all fields', () {
      final ts = Timestamp.fromDate(DateTime(2025, 8, 1, 12, 0));
      final map = <String, dynamic>{
        'uid': 'u1',
        'name': 'Alice',
        'email': 'alice@test.com',
        'phone': '9999999999',
        'role': 'customer',
        'isActive': true,
        'onboardingCompleted': true,
        'onboardingStep': 3,
        'village': 'Springfield',
        'mandal': 'Mandal1',
        'district': 'District1',
        'deliveryAvailable': false,
        'deliveryZoneId': 'zone1',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'notificationsEnabled': false,
        'totalOrders': 15,
        'totalSpent': 2500.0,
        'firstOrderCompleted': true,
        'favoriteProductIds': ['p1', 'p2'],
        'fcmTokens': ['token1', 'token2'],
        'createdAt': ts,
        'updatedAt': ts,
        'addresses': [
          {
            'id': 'a1',
            'name': 'Home',
            'addressLine1': '123 Main St',
            'pinCode': '500001',
            'village': 'Springfield',
            'mandal': 'Mandal1',
          }
        ],
        'vehicleDetails': 'Honda Activa',
        'vehicleNo': 'KA-01-1234',
        'licenseNo': 'DL-1234',
        'onDuty': true,
      };

      final user = UserModel.fromMap(map, 'doc1');

      expect(user.uid, 'u1');
      expect(user.docId, 'doc1');
      expect(user.name, 'Alice');
      expect(user.email, 'alice@test.com');
      expect(user.phone, '9999999999');
      expect(user.role, 'customer');
      expect(user.isActive, true);
      expect(user.onboardingCompleted, true);
      expect(user.onboardingStep, 3);
      expect(user.village, 'Springfield');
      expect(user.mandal, 'Mandal1');
      expect(user.district, 'District1');
      expect(user.deliveryAvailable, false);
      expect(user.deliveryZoneId, 'zone1');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
      expect(user.notificationsEnabled, false);
      expect(user.totalOrders, 15);
      expect(user.totalSpent, 2500.0);
      expect(user.firstOrderCompleted, true);
      expect(user.favoriteProductIds, ['p1', 'p2']);
      expect(user.fcmTokens, ['token1', 'token2']);
      expect(user.createdAt, ts.toDate());
      expect(user.updatedAt, ts.toDate());
      expect(user.addresses.length, 1);
      expect(user.addresses[0].id, 'a1');
      expect(user.addresses[0].name, 'Home');
      expect(user.vehicleDetails, 'Honda Activa');
      expect(user.vehicleNo, 'KA-01-1234');
      expect(user.licenseNo, 'DL-1234');
      expect(user.onDuty, true);
    });

    test('applies defaults for missing optional fields', () {
      final map = <String, dynamic>{
        'uid': 'u1',
        'name': 'Bob',
        'email': 'bob@test.com',
        'phone': '111',
        'role': 'customer',
        'village': 'Village1',
      };

      final user = UserModel.fromMap(map, 'doc2');

      expect(user.docId, 'doc2');
      expect(user.isActive, true);
      expect(user.onboardingCompleted, false);
      expect(user.onboardingStep, 1);
      expect(user.mandal, isNull);
      expect(user.district, isNull);
      expect(user.deliveryAvailable, true);
      expect(user.deliveryZoneId, isNull);
      expect(user.avatarUrl, isNull);
      expect(user.notificationsEnabled, true);
      expect(user.totalOrders, 0);
      expect(user.totalSpent, 0.0);
      expect(user.firstOrderCompleted, false);
      expect(user.favoriteProductIds, isEmpty);
      expect(user.fcmTokens, isEmpty);
      expect(user.addresses, isEmpty);
      expect(user.vehicleDetails, isNull);
      expect(user.vehicleNo, isNull);
      expect(user.licenseNo, isNull);
      expect(user.onDuty, false);
    });

    test('uses documentId as uid fallback when uid absent', () {
      final map = <String, dynamic>{
        'name': 'Test',
        'email': 'test@test.com',
        'phone': '1',
        'role': 'customer',
        'village': 'V',
      };

      final user = UserModel.fromMap(map, 'fallback_uid');

      expect(user.uid, 'fallback_uid');
    });

    test('parses multiple addresses', () {
      final map = <String, dynamic>{
        'uid': 'u1',
        'name': 'Test',
        'email': 't@t.com',
        'phone': '1',
        'role': 'customer',
        'village': 'V',
        'addresses': [
          {
            'id': 'a1',
            'name': 'Home',
            'addressLine1': 'Line1',
            'pinCode': '111',
            'village': 'V1',
            'mandal': 'M1',
            'isDefault': true,
          },
          {
            'id': 'a2',
            'name': 'Office',
            'addressLine1': 'Line2',
            'pinCode': '222',
            'village': 'V2',
            'mandal': 'M2',
          },
        ],
      };

      final user = UserModel.fromMap(map, 'doc1');

      expect(user.addresses.length, 2);
      expect(user.addresses[0].isDefault, true);
      expect(user.addresses[1].isDefault, false);
    });

    test('handles null timestamps gracefully', () {
      final map = <String, dynamic>{
        'uid': 'u1',
        'name': 'Test',
        'email': 't@t.com',
        'phone': '1',
        'role': 'customer',
        'village': 'V',
        'createdAt': null,
        'updatedAt': null,
      };

      final user = UserModel.fromMap(map, 'doc1');

      expect(user.createdAt, isNotNull);
      expect(user.updatedAt, isNotNull);
    });
  });

  group('UserModel.copyWith', () {
    test('copies with changed name', () {
      final user = UserModel(
        uid: 'u1',
        name: 'Old',
        email: 'e@e.com',
        phone: '1',
        role: 'customer',
        village: 'V',
        createdAt: DateTime(2025, 8, 1),
      );

      final updated = user.copyWith(name: 'New');

      expect(updated.name, 'New');
      expect(updated.uid, 'u1');
      expect(updated.email, 'e@e.com');
    });

    test('copies with changed role', () {
      final user = UserModel(
        uid: 'u1',
        name: 'Test',
        email: 'e@e.com',
        phone: '1',
        role: 'customer',
        village: 'V',
        createdAt: DateTime(2025, 8, 1),
      );

      final updated = user.copyWith(role: 'admin');

      expect(updated.role, 'admin');
    });

    test('copies with changed addresses', () {
      final user = UserModel(
        uid: 'u1',
        name: 'Test',
        email: 'e@e.com',
        phone: '1',
        role: 'customer',
        village: 'V',
        createdAt: DateTime(2025, 8, 1),
      );

      final newAddresses = [
        AddressModel(
          id: 'a1',
          name: 'Home',
          addressLine1: '123 Main',
          pinCode: '111',
          village: 'V1',
          mandal: 'M1',
        ),
      ];

      final updated = user.copyWith(addresses: newAddresses);

      expect(updated.addresses.length, 1);
      expect(updated.addresses[0].name, 'Home');
    });

    test('preserves all other fields', () {
      final user = UserModel(
        uid: 'u1',
        name: 'Test',
        email: 'e@e.com',
        phone: '1',
        role: 'customer',
        village: 'V',
        createdAt: DateTime(2025, 8, 1),
        totalOrders: 5,
        totalSpent: 500.0,
      );

      final updated = user.copyWith(name: 'Updated');

      expect(updated.uid, 'u1');
      expect(updated.email, 'e@e.com');
      expect(updated.phone, '1');
      expect(updated.role, 'customer');
      expect(updated.village, 'V');
      expect(updated.totalOrders, 5);
      expect(updated.totalSpent, 500.0);
    });
  });

  group('AddressModel.fromMap', () {
    test('parses all fields', () {
      final map = <String, dynamic>{
        'id': 'a1',
        'name': 'Home',
        'addressLine1': '123 Main St',
        'addressLine2': 'Apt 4B',
        'pinCode': '500001',
        'village': 'Springfield',
        'mandal': 'Mandal1',
        'district': 'District1',
        'landmark': 'Near park',
        'latitude': 12.97,
        'longitude': 77.59,
        'isDefault': true,
      };

      final addr = AddressModel.fromMap(map);

      expect(addr.id, 'a1');
      expect(addr.name, 'Home');
      expect(addr.addressLine1, '123 Main St');
      expect(addr.addressLine2, 'Apt 4B');
      expect(addr.pinCode, '500001');
      expect(addr.village, 'Springfield');
      expect(addr.mandal, 'Mandal1');
      expect(addr.district, 'District1');
      expect(addr.landmark, 'Near park');
      expect(addr.latitude, 12.97);
      expect(addr.longitude, 77.59);
      expect(addr.isDefault, true);
    });

    test('applies defaults for missing optional fields', () {
      final addr = AddressModel.fromMap(<String, dynamic>{});

      expect(addr.id, '');
      expect(addr.name, '');
      expect(addr.addressLine1, '');
      expect(addr.addressLine2, isNull);
      expect(addr.pinCode, '');
      expect(addr.village, '');
      expect(addr.mandal, '');
      expect(addr.district, isNull);
      expect(addr.landmark, isNull);
      expect(addr.latitude, isNull);
      expect(addr.longitude, isNull);
      expect(addr.isDefault, false);
    });

    test('reads pincode as fallback for pinCode', () {
      final map = <String, dynamic>{
        'pincode': '500002',
      };

      final addr = AddressModel.fromMap(map);

      expect(addr.pinCode, '500002');
    });
  });

  group('AddressModel equality', () {
    test('equal when same id', () {
      final a1 = AddressModel(
        id: 'a1',
        name: 'Home',
        addressLine1: '123 Main',
        pinCode: '111',
        village: 'V',
        mandal: 'M',
      );
      final a2 = AddressModel(
        id: 'a1',
        name: 'Different',
        addressLine1: '456 Other',
        pinCode: '222',
        village: 'V2',
        mandal: 'M2',
      );

      expect(a1, equals(a2));
    });

    test('equal when empty id and same name+addressLine1', () {
      final a1 = AddressModel(
        id: '',
        name: 'Home',
        addressLine1: '123 Main',
        pinCode: '111',
        village: 'V',
        mandal: 'M',
      );
      final a2 = AddressModel(
        id: '',
        name: 'Home',
        addressLine1: '123 Main',
        pinCode: '999',
        village: 'X',
        mandal: 'Y',
      );

      expect(a1, equals(a2));
    });

    test('not equal when different ids', () {
      final a1 = AddressModel(
        id: 'a1',
        name: 'Home',
        addressLine1: '123 Main',
        pinCode: '111',
        village: 'V',
        mandal: 'M',
      );
      final a2 = AddressModel(
        id: 'a2',
        name: 'Home',
        addressLine1: '123 Main',
        pinCode: '111',
        village: 'V',
        mandal: 'M',
      );

      expect(a1, isNot(equals(a2)));
    });
  });
}
