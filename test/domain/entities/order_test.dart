import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/domain/entities/order.dart';

void main() {
  group('Order', () {
    test('constructs with all required fields', () {
      final now = DateTime.now();
      final order = Order(
        id: 'o1',
        customerId: 'c1',
        customerName: 'Alice',
        customerPhone: '9999999999',
        deliveryAddress: '123 Main St',
        village: 'Springfield',
        items: [
          OrderItem(productId: 'p1', name: 'Milk', price: 30, quantity: 2),
        ],
        totalAmount: 60,
        paymentMethod: 'COD',
        status: 'placed',
        createdAt: now,
        updatedAt: now,
      );

      expect(order.id, 'o1');
      expect(order.customerId, 'c1');
      expect(order.customerName, 'Alice');
      expect(order.customerPhone, '9999999999');
      expect(order.deliveryAddress, '123 Main St');
      expect(order.village, 'Springfield');
      expect(order.items.length, 1);
      expect(order.items[0].productId, 'p1');
      expect(order.totalAmount, 60);
      expect(order.paymentMethod, 'COD');
      expect(order.status, 'placed');
      expect(order.createdAt, now);
      expect(order.updatedAt, now);
    });

    test('defaults subtotal to 0.0', () {
      final order = Order(
        id: 'o1',
        customerId: 'c1',
        customerName: 'A',
        customerPhone: '1',
        deliveryAddress: 'addr',
        village: 'v',
        items: [],
        totalAmount: 0,
        paymentMethod: 'COD',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(order.subtotal, 0.0);
    });

    test('defaults deliveryFee to 0.0', () {
      final order = Order(
        id: 'o1',
        customerId: 'c1',
        customerName: 'A',
        customerPhone: '1',
        deliveryAddress: 'addr',
        village: 'v',
        items: [],
        totalAmount: 0,
        paymentMethod: 'COD',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(order.deliveryFee, 0.0);
    });

    test('defaults paymentStatus to pending', () {
      final order = Order(
        id: 'o1',
        customerId: 'c1',
        customerName: 'A',
        customerPhone: '1',
        deliveryAddress: 'addr',
        village: 'v',
        items: [],
        totalAmount: 0,
        paymentMethod: 'COD',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(order.paymentStatus, 'pending');
    });

    test('backward-compat getter deliveryBoyId maps to deliveryPartnerId', () {
      final order = Order(
        id: 'o1',
        customerId: 'c1',
        customerName: 'A',
        customerPhone: '1',
        deliveryAddress: 'addr',
        village: 'v',
        items: [],
        totalAmount: 0,
        paymentMethod: 'COD',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryPartnerId: 'dp1',
      );

      expect(order.deliveryPartnerId, 'dp1');
      expect(order.deliveryBoyId, 'dp1');
    });

    test('backward-compat getter deliveryBoyName maps to deliveryPartnerName', () {
      final order = Order(
        id: 'o1',
        customerId: 'c1',
        customerName: 'A',
        customerPhone: '1',
        deliveryAddress: 'addr',
        village: 'v',
        items: [],
        totalAmount: 0,
        paymentMethod: 'COD',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryPartnerName: 'Rider1',
      );

      expect(order.deliveryPartnerName, 'Rider1');
      expect(order.deliveryBoyName, 'Rider1');
    });

    test('backward-compat getter deliveryBoyPhone maps to deliveryPartnerPhone', () {
      final order = Order(
        id: 'o1',
        customerId: 'c1',
        customerName: 'A',
        customerPhone: '1',
        deliveryAddress: 'addr',
        village: 'v',
        items: [],
        totalAmount: 0,
        paymentMethod: 'COD',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryPartnerPhone: '1234567890',
      );

      expect(order.deliveryPartnerPhone, '1234567890');
      expect(order.deliveryBoyPhone, '1234567890');
    });

    test('passing deliveryBoyId sets deliveryPartnerId (backward compat constructor)', () {
      final order = Order(
        id: 'o1',
        customerId: 'c1',
        customerName: 'A',
        customerPhone: '1',
        deliveryAddress: 'addr',
        village: 'v',
        items: [],
        totalAmount: 0,
        paymentMethod: 'COD',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryBoyId: 'legacy_rider',
      );

      expect(order.deliveryPartnerId, 'legacy_rider');
    });

    test('deliveryPartnerId takes precedence over deliveryBoyId', () {
      final order = Order(
        id: 'o1',
        customerId: 'c1',
        customerName: 'A',
        customerPhone: '1',
        deliveryAddress: 'addr',
        village: 'v',
        items: [],
        totalAmount: 0,
        paymentMethod: 'COD',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        deliveryPartnerId: 'new_rider',
        deliveryBoyId: 'old_rider',
      );

      expect(order.deliveryPartnerId, 'new_rider');
    });

    test('nullable fields default to null', () {
      final order = Order(
        id: 'o1',
        customerId: 'c1',
        customerName: 'A',
        customerPhone: '1',
        deliveryAddress: 'addr',
        village: 'v',
        items: [],
        totalAmount: 0,
        paymentMethod: 'COD',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(order.addressId, isNull);
      expect(order.latitude, isNull);
      expect(order.longitude, isNull);
      expect(order.deliveryPartnerId, isNull);
      expect(order.deliveryPartnerName, isNull);
      expect(order.deliveryPartnerPhone, isNull);
      expect(order.estimatedDeliveryTime, isNull);
      expect(order.deliveredAt, isNull);
      expect(order.rating, isNull);
      expect(order.ratingComment, isNull);
      expect(order.notifyTier, isNull);
      expect(order.cancelReason, isNull);
      expect(order.cancelledBy, isNull);
    });
  });

  group('OrderItem', () {
    test('constructs with all fields', () {
      final item = OrderItem(
        productId: 'p1',
        name: 'Eggs',
        price: 45.5,
        quantity: 3,
      );

      expect(item.productId, 'p1');
      expect(item.name, 'Eggs');
      expect(item.price, 45.5);
      expect(item.quantity, 3);
    });
  });
}
