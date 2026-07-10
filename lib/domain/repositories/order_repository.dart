import '../entities/order.dart';
import '../../core/models/user_model.dart';

abstract class OrderRepository {
  Stream<List<Order>> streamCustomerOrders(String customerId);
  Stream<List<Order>> streamDeliveryBoyOrders(String deliveryBoyId);
  Stream<List<Order>> streamAllOrders();
  Stream<List<UserModel>> streamDeliveryBoys();
  Future<bool> placeOrder(Order order);
  Future<void> updateOrderStatus(String orderId, String status);
  Future<void> assignDeliveryBoy(String orderId, String riderId, String riderName);
}
