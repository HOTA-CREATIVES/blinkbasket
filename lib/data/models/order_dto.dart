import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../../domain/entities/order.dart';

class OrderItemDto extends OrderItem {
  OrderItemDto({
    required super.productId,
    required super.name,
    required super.price,
    required super.quantity,
  });

  factory OrderItemDto.fromMap(Map<String, dynamic> map) {
    return OrderItemDto(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  factory OrderItemDto.fromEntity(OrderItem entity) {
    return OrderItemDto(
      productId: entity.productId,
      name: entity.name,
      price: entity.price,
      quantity: entity.quantity,
    );
  }
}

class OrderDto extends Order {
  OrderDto({
    required super.id,
    required super.customerId,
    required super.customerName,
    required super.customerPhone,
    required super.deliveryAddress,
    required super.village,
    required super.items,
    required super.totalAmount,
    required super.paymentMethod,
    required super.status,
    super.deliveryBoyId,
    super.deliveryBoyName,
    required super.createdAt,
    required super.updatedAt,
  });

  factory OrderDto.fromMap(Map<String, dynamic> map, String documentId) {
    return OrderDto(
      id: documentId,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      deliveryAddress: map['deliveryAddress'] ?? '',
      village: map['village'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => OrderItemDto.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? 'COD',
      status: map['status'] ?? 'pending',
      deliveryBoyId: map['deliveryBoyId'],
      deliveryBoyName: map['deliveryBoyName'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'village': village,
      'items': items.map((item) => OrderItemDto.fromEntity(item).toMap()).toList(),
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'status': status,
      'deliveryBoyId': deliveryBoyId,
      'deliveryBoyName': deliveryBoyName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory OrderDto.fromEntity(Order order) {
    return OrderDto(
      id: order.id,
      customerId: order.customerId,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      deliveryAddress: order.deliveryAddress,
      village: order.village,
      items: order.items,
      totalAmount: order.totalAmount,
      paymentMethod: order.paymentMethod,
      status: order.status,
      deliveryBoyId: order.deliveryBoyId,
      deliveryBoyName: order.deliveryBoyName,
      createdAt: order.createdAt,
      updatedAt: order.updatedAt,
    );
  }
}
