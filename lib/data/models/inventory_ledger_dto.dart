import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/inventory_ledger.dart';

class InventoryLedgerDto extends InventoryLedger {
  InventoryLedgerDto({
    required super.id,
    required super.productId,
    required super.actorId,
    super.actorType,
    super.orderId,
    required super.changeType,
    required super.physicalDelta,
    required super.reservedDelta,
    required super.notes,
    required super.timestamp,
  });

  factory InventoryLedgerDto.fromMap(Map<String, dynamic> map, String documentId) {
    return InventoryLedgerDto(
      id: documentId,
      productId: map['productId'] ?? '',
      actorId: map['actorId'] ?? map['adminId'] ?? '',
      actorType: map['actorType'] ?? InventoryLedger.kActorAdmin,
      orderId: map['orderId'],
      changeType: map['changeType'] ?? InventoryLedger.kCorrection,
      physicalDelta: (map['physicalDelta'] as num?)?.toInt() ?? 0,
      reservedDelta: (map['reservedDelta'] as num?)?.toInt() ?? 0,
      notes: map['notes'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'actorId': actorId,
      'actorType': actorType,
      if (orderId != null) 'orderId': orderId,
      'changeType': changeType,
      'physicalDelta': physicalDelta,
      'reservedDelta': reservedDelta,
      'notes': notes,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
