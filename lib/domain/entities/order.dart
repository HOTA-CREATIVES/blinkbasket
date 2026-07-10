class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
  });
}

class Order {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String village;
  final List<OrderItem> items;
  final double totalAmount;
  final String paymentMethod;
  final String status;
  final String? deliveryBoyId;
  final String? deliveryBoyName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.village,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
    this.deliveryBoyId,
    this.deliveryBoyName,
    required this.createdAt,
    required this.updatedAt,
  });
}
