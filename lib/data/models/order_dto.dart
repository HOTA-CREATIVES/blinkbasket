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
    super.deliveryInstructions,
    required super.village,
    super.latitude,
    super.longitude,
    required super.items,
    super.subtotal,
    super.deliveryFee,
    required super.totalAmount,
    required super.paymentMethod,
    required super.status,
    super.deliveryBoyId,
    super.deliveryBoyName,
    super.deliveryBoyPhone,
    required super.createdAt,
    required super.updatedAt,
    super.rating,
    super.ratingComment,
    super.notifyTier,
    super.cancelReason,
    super.cancelledBy,
    super.riderPayout,
    super.codCollectedAmount,
    super.paymentStatus,
    super.deliveredAt,
  });

  factory OrderDto.fromMap(Map<String, dynamic> map, String documentId) {
    return OrderDto(
      id: documentId,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      deliveryAddress: map['deliveryAddress'] ?? '',
      deliveryInstructions: map['deliveryInstructions'] as String?,
      village: map['village'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => OrderItemDto.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (map['subtotal'] ?? 0.0).toDouble(),
      deliveryFee: (map['deliveryFee'] ?? 0.0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      paymentMethod: map['paymentMethod'] ?? 'COD',
      status: map['status'] ?? 'pending',
      deliveryBoyId: map['deliveryBoyId'],
      deliveryBoyName: map['deliveryBoyName'],
      deliveryBoyPhone: map['deliveryBoyPhone'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rating: map['rating'] as int?,
      ratingComment: map['ratingComment'] as String?,
      notifyTier: (map['notifyTier'] as num?)?.toInt(),
      cancelReason: map['cancelReason'] as String?,
      cancelledBy: map['cancelledBy'] as String?,
      riderPayout: (map['riderPayout'] as num?)?.toDouble(),
      codCollectedAmount: (map['codCollectedAmount'] as num?)?.toDouble(),
      paymentStatus: (map['paymentStatus'] as String?) ?? 'pending',
      deliveredAt: (map['deliveredAt'] as Timestamp?)?.toDate(),
    );
  }
}
