import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/data/models/order_dto.dart';

void main() {
  group('OrderDto riderPayout', () {
    Map<String, dynamic> base() => {
          'customerId': 'c1',
          'customerName': 'A',
          'customerPhone': '1',
          'deliveryAddress': 'addr',
          'village': 'Bhimavaram',
          'totalAmount': 100,
          'status': 'delivered',
          'paymentMethod': 'COD',
        };

    test('reads the payout frozen on a delivered order (int or double)', () {
      expect(OrderDto.fromMap({...base(), 'riderPayout': 42}, 'o1').riderPayout, 42.0);
      expect(OrderDto.fromMap({...base(), 'riderPayout': 42.5}, 'o1').riderPayout, 42.5);
    });

    test('is null for orders that predate the field (earnings falls back to the current rate)', () {
      expect(OrderDto.fromMap(base(), 'o1').riderPayout, isNull);
    });
  });

  group('OrderDto.fromMap', () {
    test('parses all fields present', () {
      final ts = Timestamp.fromDate(DateTime(2025, 6, 15, 10, 30));
      final map = <String, dynamic>{
        'customerId': 'c1',
        'customerName': 'Bob',
        'customerPhone': '8888888888',
        'deliveryAddress': '456 Oak Ave',
        'village': 'Shelbyville',
        'latitude': 12.97,
        'longitude': 77.59,
        'items': [
          {'productId': 'p1', 'name': 'Bread', 'price': 25.0, 'quantity': 2},
          {'productId': 'p2', 'name': 'Butter', 'price': 50.0, 'quantity': 1},
        ],
        'subtotal': 100.0,
        'deliveryFee': 30.0,
        'totalAmount': 130.0,
        'paymentMethod': 'COD',
        'status': 'placed',
        'deliveryBoyId': 'r1',
        'deliveryBoyName': 'Rider1',
        'deliveryBoyPhone': '7777777777',
        'createdAt': ts,
        'updatedAt': ts,
        'rating': 5,
        'ratingComment': 'Great!',
        'notifyTier': 2,
        'cancelReason': null,
        'cancelledBy': null,
      };

      final order = OrderDto.fromMap(map, 'doc1');

      expect(order.id, 'doc1');
      expect(order.customerId, 'c1');
      expect(order.customerName, 'Bob');
      expect(order.customerPhone, '8888888888');
      expect(order.deliveryAddress, '456 Oak Ave');
      expect(order.village, 'Shelbyville');
      expect(order.latitude, 12.97);
      expect(order.longitude, 77.59);
      expect(order.items.length, 2);
      expect(order.items[0].productId, 'p1');
      expect(order.items[0].name, 'Bread');
      expect(order.items[0].price, 25.0);
      expect(order.items[0].quantity, 2);
      expect(order.subtotal, 100.0);
      expect(order.deliveryFee, 30.0);
      expect(order.totalAmount, 130.0);
      expect(order.paymentMethod, 'COD');
      expect(order.status, 'placed');
      expect(order.deliveryPartnerId, 'r1');
      expect(order.deliveryPartnerName, 'Rider1');
      expect(order.deliveryPartnerPhone, '7777777777');
      expect(order.createdAt, ts.toDate());
      expect(order.updatedAt, ts.toDate());
      expect(order.rating, 5);
      expect(order.ratingComment, 'Great!');
      expect(order.notifyTier, 2);
    });

    test('applies defaults for missing optional fields', () {
      final map = <String, dynamic>{
        'customerId': 'c1',
        'customerName': 'Bob',
        'customerPhone': '8888888888',
        'deliveryAddress': '456 Oak Ave',
        'village': 'Shelbyville',
        'totalAmount': 0.0,
        'paymentMethod': 'COD',
        'status': 'pending',
      };

      final order = OrderDto.fromMap(map, 'doc2');

      expect(order.items, isEmpty);
      expect(order.subtotal, 0.0);
      expect(order.deliveryFee, 0.0);
      expect(order.totalAmount, 0.0);
      expect(order.latitude, isNull);
      expect(order.longitude, isNull);
      expect(order.deliveryPartnerId, isNull);
      expect(order.rating, isNull);
      expect(order.ratingComment, isNull);
      expect(order.notifyTier, isNull);
      expect(order.cancelReason, isNull);
      expect(order.cancelledBy, isNull);
    });

    test('handles null Timestamp fields gracefully', () {
      final map = <String, dynamic>{
        'customerId': 'c1',
        'customerName': 'Bob',
        'customerPhone': '8888888888',
        'deliveryAddress': '456 Oak Ave',
        'village': 'Shelbyville',
        'totalAmount': 50.0,
        'paymentMethod': 'COD',
        'status': 'placed',
        'createdAt': null,
        'updatedAt': null,
      };

      final order = OrderDto.fromMap(map, 'doc3');

      // Should not throw — falls back to DateTime.now()
      expect(order.createdAt, isNotNull);
      expect(order.updatedAt, isNotNull);
    });

    test('reads deliveryPartnerId from deliveryBoyId key', () {
      final map = <String, dynamic>{
        'customerId': 'c1',
        'customerName': 'Bob',
        'customerPhone': '8888888888',
        'deliveryAddress': '456 Oak Ave',
        'village': 'Shelbyville',
        'totalAmount': 50.0,
        'paymentMethod': 'COD',
        'status': 'placed',
        'deliveryBoyId': 'legacy_rider',
      };

      final order = OrderDto.fromMap(map, 'doc4');

      expect(order.deliveryPartnerId, 'legacy_rider');
    });
  });

  group('OrderItemDto.fromMap', () {
    test('parses all fields', () {
      final map = <String, dynamic>{
        'productId': 'p1',
        'name': 'Milk',
        'price': 30.0,
        'quantity': 2,
      };

      final item = OrderItemDto.fromMap(map);

      expect(item.productId, 'p1');
      expect(item.name, 'Milk');
      expect(item.price, 30.0);
      expect(item.quantity, 2);
    });

    test('applies defaults for missing fields', () {
      final item = OrderItemDto.fromMap(<String, dynamic>{});

      expect(item.productId, '');
      expect(item.name, '');
      expect(item.price, 0.0);
      expect(item.quantity, 0);
    });

    test('toMap produces correct output', () {
      final item = OrderItemDto(
        productId: 'p2',
        name: 'Eggs',
        price: 45.5,
        quantity: 3,
      );

      final map = item.toMap();

      expect(map['productId'], 'p2');
      expect(map['name'], 'Eggs');
      expect(map['price'], 45.5);
      expect(map['quantity'], 3);
    });
  });

  group('OrderDto round-trip', () {
    test('fromMap → toMap preserves data (non-Timestamp fields)', () {
      final now = DateTime(2025, 7, 1, 12, 0);
      final ts = Timestamp.fromDate(now);
      final original = <String, dynamic>{
        'customerId': 'c1',
        'customerName': 'Bob',
        'customerPhone': '8888888888',
        'deliveryAddress': '456 Oak Ave',
        'village': 'Shelbyville',
        'latitude': 12.97,
        'longitude': 77.59,
        'items': [
          {'productId': 'p1', 'name': 'Bread', 'price': 25.0, 'quantity': 2},
        ],
        'subtotal': 50.0,
        'deliveryFee': 30.0,
        'totalAmount': 80.0,
        'paymentMethod': 'COD',
        'status': 'placed',
        'deliveryBoyId': 'r1',
        'deliveryBoyName': 'Rider1',
        'deliveryBoyPhone': '7777777777',
        'createdAt': ts,
        'updatedAt': ts,
        'rating': 5,
        'ratingComment': 'Great!',
        'notifyTier': 1,
      };

      final order = OrderDto.fromMap(original, 'doc1');
      expect(order.customerId, 'c1');
      expect(order.totalAmount, 80.0);
      expect(order.items.length, 1);
      expect(order.items[0].name, 'Bread');
    });
  });

  group('OrderDto.fromMap', () {
    test('handles integer price as double', () {
      final map = <String, dynamic>{
        'customerId': 'c1',
        'customerName': 'Test',
        'customerPhone': '1',
        'deliveryAddress': 'addr',
        'village': 'v',
        'items': [
          {'productId': 'p1', 'name': 'Item', 'price': 10, 'quantity': 1},
        ],
        'totalAmount': 10,
        'paymentMethod': 'COD',
        'status': 'pending',
      };

      final order = OrderDto.fromMap(map, 'd1');

      expect(order.items[0].price, 10.0);
      expect(order.totalAmount, 10.0);
    });
  });

  group('OrderDto COD completion fields', () {
    Map<String, dynamic> base() => {
          'customerId': 'c1',
          'status': 'delivered',
          'totalAmount': 130,
        };

    test('parses what the rider confirmed collecting and when it was delivered', () {
      final order = OrderDto.fromMap({
        ...base(),
        'paymentStatus': 'paid',
        'codCollectedAmount': 130,
        'deliveredAt': Timestamp.fromDate(DateTime(2026, 9, 30, 16, 5)),
      }, 'o1');

      expect(order.paymentStatus, 'paid');
      expect(order.codCollectedAmount, 130.0);
      expect(order.deliveredAt, DateTime(2026, 9, 30, 16, 5));
    });

    test('defaults cleanly for an order that has not been delivered', () {
      final order = OrderDto.fromMap(base(), 'o1');
      expect(order.paymentStatus, 'pending');
      expect(order.codCollectedAmount, isNull);
      expect(order.deliveredAt, isNull);
    });
  });
}
