class InventoryLedger {
  final String id;
  final String productId;
  final String adminId;
  final String? orderId;
  final String changeType; // 'restock', 'sale', 'spoilage', 'adjustment', 'return'
  final int physicalDelta;
  final int reservedDelta;
  final String notes;
  final DateTime timestamp;

  InventoryLedger({
    required this.id,
    required this.productId,
    required this.adminId,
    this.orderId,
    required this.changeType,
    required this.physicalDelta,
    required this.reservedDelta,
    required this.notes,
    required this.timestamp,
  });
}
