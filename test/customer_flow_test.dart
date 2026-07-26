import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/core/models/user_model.dart';
import 'package:hypermart/core/utils/customer_helper.dart';
import 'package:hypermart/data/models/order_dto.dart';

void main() {
  group('CustomerHelper Tests', () {
    test('formatPhone formats standard 10-digit number with +91', () {
      final formatted = CustomerHelper.formatPhone('9876543210', 'test@example.com');
      expect(formatted, equals('+91 9876543210'));
    });

    test('formatPhone returns email if phone is empty', () {
      final formatted = CustomerHelper.formatPhone('', 'test@example.com');
      expect(formatted, equals('test@example.com'));
    });

    test('formatPhone preserves already formatted +91 number', () {
      final formatted = CustomerHelper.formatPhone('+91 9876543210', 'test@example.com');
      expect(formatted, equals('+91 9876543210'));
    });

    test('formatPhone preserves other international codes starting with +', () {
      final formatted = CustomerHelper.formatPhone('+1234567890', 'test@example.com');
      expect(formatted, equals('+1234567890'));
    });

    test('formatPhone strips spaces and dashes before formatting', () {
      final formatted = CustomerHelper.formatPhone('9876-543-210', 'test@example.com');
      expect(formatted, equals('+91 9876543210'));
    });

    test('findClosestVillage matches exact coordinates of Bhimavaram', () {
      final village = CustomerHelper.findClosestVillage(16.5449, 81.5212);
      expect(village, equals('Bhimavaram'));
    });

    test('findClosestVillage matches Rayakuduru coords', () {
      final village = CustomerHelper.findClosestVillage(16.5861, 81.5034);
      expect(village, equals('Rayakuduru'));
    });
  });

  group('UserModel Serialization Tests', () {
    test('UserModel serializes and deserializes properly with addresses', () {
      final origin = UserModel(
        uid: 'user_123',
        name: 'John Doe',
        email: 'john@example.com',
        phone: '+91 9876543210',
        village: 'Bhimavaram',
        role: 'customer',
        isActive: true,
        createdAt: DateTime.now(),
        addresses: [
          AddressModel(
            id: 'addr_1',
            name: 'Home',
            addressLine1: '1-23, Main Street',
            addressLine2: 'Near Temple',
            pinCode: '534201',
            village: 'Bhimavaram',
            mandal: 'Bhimavaram',
            landmark: 'Ganesh Temple',
            latitude: 16.5449,
            longitude: 81.5212,
          ),
        ],
      );

      final map = origin.toMap();
      final decoded = UserModel.fromMap(map, 'user_123');

      expect(decoded.uid, equals(origin.uid));
      expect(decoded.name, equals(origin.name));
      expect(decoded.email, equals(origin.email));
      expect(decoded.phone, equals(origin.phone));
      expect(decoded.village, equals(origin.village));
      expect(decoded.role, equals(origin.role));
      expect(decoded.isActive, equals(origin.isActive));
      expect(decoded.addresses.length, equals(1));
      expect(decoded.addresses.first.id, equals('addr_1'));
      expect(decoded.addresses.first.name, equals('Home'));
      expect(decoded.addresses.first.latitude, equals(16.5449));
    });

    test('UserModel preserves onDuty and vehicle fields for a delivery partner', () {
      final origin = UserModel(
        uid: 'rider_123',
        name: 'Ramesh Kumar',
        email: 'ramesh@example.com',
        phone: '+91 9876543210',
        village: 'Bhimavaram',
        role: 'delivery',
        isActive: true,
        createdAt: DateTime.now(),
        onDuty: true,
        vehicleDetails: 'Hero Splendor',
        vehicleNo: 'AP37 AB 1234',
        licenseNo: 'DL123456',
      );

      final decoded = UserModel.fromMap(origin.toMap(), 'rider_123');
      expect(decoded.onDuty, isTrue);
      expect(decoded.vehicleDetails, equals('Hero Splendor'));
      expect(decoded.vehicleNo, equals('AP37 AB 1234'));
      expect(decoded.licenseNo, equals('DL123456'));

      // copyWith without touching onDuty must not silently reset it to the
      // default — this is the bug that made the rider "on duty" toggle a
      // no-op (UserModel.onDuty used to be a hardcoded `=> true` getter).
      final toggledOff = origin.copyWith(onDuty: false);
      expect(toggledOff.onDuty, isFalse);
      final untouched = origin.copyWith(name: 'Ramesh K.');
      expect(untouched.onDuty, isTrue);
    });
  });

  group('OrderDto Serialization Tests', () {
    test('OrderDto deserializes coordinates correctly from map', () {
      final map = {
        'customerId': 'cust_123',
        'customerName': 'Jane Doe',
        'customerPhone': '+91 9999999999',
        'deliveryAddress': '1-24 East St',
        'village': 'Rayakuduru',
        'latitude': 16.5861,
        'longitude': 81.5034,
        'items': [
          {
            'productId': 'prod_abc',
            'name': 'Milk',
            'price': 40.0,
            'quantity': 2,
          }
        ],
        'totalAmount': 110.0,
        'paymentMethod': 'COD',
        'status': 'pending',
      };

      final orderDto = OrderDto.fromMap(map, 'order_123');

      expect(orderDto.id, equals('order_123'));
      expect(orderDto.customerId, equals('cust_123'));
      expect(orderDto.latitude, equals(16.5861));
      expect(orderDto.longitude, equals(81.5034));
      expect(orderDto.items.length, equals(1));
      expect(orderDto.items.first.name, equals('Milk'));
    });
  });
}
