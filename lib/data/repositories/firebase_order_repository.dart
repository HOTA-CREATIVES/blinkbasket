import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../../core/models/user_model.dart';
import '../models/order_dto.dart';

class FirebaseOrderRepository implements OrderRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<List<Order>> streamCustomerOrders(String customerId) {
    return _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderDto.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<Order>> streamDeliveryBoyOrders(String deliveryBoyId) {
    return _db
        .collection('orders')
        .where('deliveryBoyId', isEqualTo: deliveryBoyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderDto.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<Order>> streamAllOrders() {
    return _db
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderDto.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<UserModel>> streamDeliveryBoys() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'delivery')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Future<bool> placeOrder(Order order) async {
    try {
      final orderRef = _db.collection('orders').doc();
      final dto = OrderDto.fromEntity(order);
      final batch = _db.batch();

      batch.set(orderRef, dto.toMap());

      for (var item in order.items) {
        final productRef = _db.collection('products').doc(item.productId);
        batch.update(productRef, {
          'stock': FieldValue.increment(-item.quantity),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error placing order: $e');
      return false;
    }
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _db.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> assignDeliveryBoy(String orderId, String riderId, String riderName) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'assigned',
      'deliveryBoyId': riderId,
      'deliveryBoyName': riderName,
      'updatedAt': Timestamp.now(),
    });
  }
}
