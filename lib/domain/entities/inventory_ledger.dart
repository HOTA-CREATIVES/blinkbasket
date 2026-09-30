class InventoryLedger {
  /// Canonical changeType vocabulary. Every write to /inventoryLogs must use
  /// one of these values. The Cloud Functions and admin UI both reference
  /// this list.
  static const kRestock = 'restock';
  static const kSale = 'sale';
  static const kReturn = 'return';
  static const kReserve = 'reserve';
  static const kCancellation = 'cancellation';
  static const kSpoilage = 'spoilage';
  static const kCorrection = 'correction';

  /// Canonical actorType vocabulary.
  static const kActorAdmin = 'admin';
  static const kActorSystem = 'system';
  static const kActorCustomer = 'customer';
  static const kActorRider = 'rider';

  final String id;
  final String productId;
  final String actorId;
  final String actorType;
  final String? orderId;
  final String changeType;
  final int physicalDelta;
  final int reservedDelta;
  final String notes;
  final DateTime timestamp;

  /// Backward-compat getter for code that still references [adminId].
  String get adminId => actorId;

  InventoryLedger({
    required this.id,
    required this.productId,
    required this.actorId,
    this.actorType = kActorAdmin,
    this.orderId,
    required this.changeType,
    required this.physicalDelta,
    required this.reservedDelta,
    required this.notes,
    required this.timestamp,
  });
}
