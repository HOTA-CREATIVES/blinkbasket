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
  final String? addressId;
  final String deliveryAddress;
  final String? deliveryInstructions;
  final String village;
  final double? latitude;
  final double? longitude;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus; // 'pending', 'paid', 'failed', 'refunded'
  final String status;
  final String? deliveryPartnerId;
  final String? deliveryPartnerName;
  final String? deliveryPartnerPhone;
  final String? estimatedDeliveryTime;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? rating;
  final String? ratingComment;
  final int? notifyTier;
  final String? cancelReason;
  final String? cancelledBy; // 'customer', 'admin', 'system'

  /// What the rider is paid for this delivery, frozen by the server at the
  /// moment of delivery (null until delivered, and on orders that predate it).
  final double? riderPayout;

  // Backward compatibility getters
  String? get deliveryBoyId => deliveryPartnerId;
  String? get deliveryBoyName => deliveryPartnerName;
  String? get deliveryBoyPhone => deliveryPartnerPhone;

  Order({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.addressId,
    required this.deliveryAddress,
    this.deliveryInstructions,
    required this.village,
    this.latitude,
    this.longitude,
    required this.items,
    this.subtotal = 0.0,
    this.deliveryFee = 0.0,
    required this.totalAmount,
    required this.paymentMethod,
    this.paymentStatus = 'pending',
    required this.status,
    String? deliveryPartnerId,
    String? deliveryPartnerName,
    String? deliveryPartnerPhone,
    String? deliveryBoyId,
    String? deliveryBoyName,
    String? deliveryBoyPhone,
    this.estimatedDeliveryTime,
    this.deliveredAt,
    required this.createdAt,
    required this.updatedAt,
    this.rating,
    this.ratingComment,
    this.notifyTier,
    this.cancelReason,
    this.cancelledBy,
    this.riderPayout,
  })  : deliveryPartnerId = deliveryPartnerId ?? deliveryBoyId,
        deliveryPartnerName = deliveryPartnerName ?? deliveryBoyName,
        deliveryPartnerPhone = deliveryPartnerPhone ?? deliveryBoyPhone;
}
