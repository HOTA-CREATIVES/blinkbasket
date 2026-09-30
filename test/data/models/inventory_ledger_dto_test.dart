import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/data/models/inventory_ledger_dto.dart';
import 'package:hypermart/domain/entities/inventory_ledger.dart';

void main() {
  group('InventoryLedgerDto.fromMap', () {
    test('parses all fields with actorId', () {
      final ts = Timestamp.fromDate(DateTime(2025, 8, 1, 12, 0));
      final map = <String, dynamic>{
        'productId': 'prod1',
        'actorId': 'admin1',
        'actorType': 'admin',
        'orderId': 'ord1',
        'changeType': 'restock',
        'physicalDelta': 10,
        'reservedDelta': 0,
        'notes': 'Restocked from supplier',
        'timestamp': ts,
      };

      final ledger = InventoryLedgerDto.fromMap(map, 'log1');

      expect(ledger.id, 'log1');
      expect(ledger.productId, 'prod1');
      expect(ledger.actorId, 'admin1');
      expect(ledger.actorType, 'admin');
      expect(ledger.orderId, 'ord1');
      expect(ledger.changeType, 'restock');
      expect(ledger.physicalDelta, 10);
      expect(ledger.reservedDelta, 0);
      expect(ledger.notes, 'Restocked from supplier');
      expect(ledger.timestamp, ts.toDate());
    });

    test('backward-compat: reads adminId as actorId fallback', () {
      final map = <String, dynamic>{
        'productId': 'prod1',
        'adminId': 'legacy_admin',
        'changeType': 'sale',
        'physicalDelta': -1,
        'reservedDelta': 0,
        'notes': 'Sale',
        'timestamp': Timestamp.fromDate(DateTime(2025, 8, 1)),
      };

      final ledger = InventoryLedgerDto.fromMap(map, 'log2');

      expect(ledger.actorId, 'legacy_admin');
    });

    test('actorId takes precedence over adminId', () {
      final map = <String, dynamic>{
        'productId': 'prod1',
        'actorId': 'new_admin',
        'adminId': 'old_admin',
        'changeType': 'sale',
        'physicalDelta': -1,
        'reservedDelta': 0,
        'notes': 'Sale',
        'timestamp': Timestamp.fromDate(DateTime(2025, 8, 1)),
      };

      final ledger = InventoryLedgerDto.fromMap(map, 'log3');

      expect(ledger.actorId, 'new_admin');
    });

    test('applies defaults for missing optional fields', () {
      final map = <String, dynamic>{
        'productId': 'prod1',
      };

      final ledger = InventoryLedgerDto.fromMap(map, 'log4');

      expect(ledger.actorId, '');
      expect(ledger.actorType, InventoryLedger.kActorAdmin);
      expect(ledger.orderId, isNull);
      expect(ledger.changeType, InventoryLedger.kCorrection);
      expect(ledger.physicalDelta, 0);
      expect(ledger.reservedDelta, 0);
      expect(ledger.notes, '');
      expect(ledger.timestamp, isNotNull);
    });

    test('handles null timestamp gracefully', () {
      final map = <String, dynamic>{
        'productId': 'prod1',
        'changeType': 'restock',
        'physicalDelta': 5,
        'reservedDelta': 0,
        'timestamp': null,
      };

      final ledger = InventoryLedgerDto.fromMap(map, 'log5');

      expect(ledger.timestamp, isNotNull);
    });

    test('reads numeric fields from num types', () {
      final map = <String, dynamic>{
        'productId': 'prod1',
        'changeType': 'restock',
        'physicalDelta': 10.0,
        'reservedDelta': 2.0,
        'timestamp': Timestamp.fromDate(DateTime(2025, 8, 1)),
      };

      final ledger = InventoryLedgerDto.fromMap(map, 'log6');

      expect(ledger.physicalDelta, 10);
      expect(ledger.reservedDelta, 2);
    });
  });

  group('InventoryLedger changeType constants', () {
    test('kRestock is restock', () {
      expect(InventoryLedger.kRestock, 'restock');
    });

    test('kSale is sale', () {
      expect(InventoryLedger.kSale, 'sale');
    });

    test('kReturn is return', () {
      expect(InventoryLedger.kReturn, 'return');
    });

    test('kReserve is reserve', () {
      expect(InventoryLedger.kReserve, 'reserve');
    });

    test('kCancellation is cancellation', () {
      expect(InventoryLedger.kCancellation, 'cancellation');
    });

    test('kSpoilage is spoilage', () {
      expect(InventoryLedger.kSpoilage, 'spoilage');
    });

    test('kCorrection is correction', () {
      expect(InventoryLedger.kCorrection, 'correction');
    });
  });

  group('InventoryLedger actorType constants', () {
    test('kActorAdmin is admin', () {
      expect(InventoryLedger.kActorAdmin, 'admin');
    });

    test('kActorSystem is system', () {
      expect(InventoryLedger.kActorSystem, 'system');
    });

    test('kActorCustomer is customer', () {
      expect(InventoryLedger.kActorCustomer, 'customer');
    });

    test('kActorRider is rider', () {
      expect(InventoryLedger.kActorRider, 'rider');
    });
  });

  group('InventoryLedger backward-compat', () {
    test('adminId getter returns actorId', () {
      final ledger = InventoryLedger(
        id: 'l1',
        productId: 'p1',
        actorId: 'admin42',
        changeType: 'restock',
        physicalDelta: 10,
        reservedDelta: 0,
        notes: 'test',
        timestamp: DateTime.now(),
      );

      expect(ledger.adminId, 'admin42');
    });
  });

  group('InventoryLedgerDto.toMap', () {
    test('serializes all fields correctly', () {
      final ts = DateTime(2025, 8, 1, 12, 0);
      final ledger = InventoryLedgerDto(
        id: 'l1',
        productId: 'p1',
        actorId: 'admin1',
        actorType: 'admin',
        orderId: 'o1',
        changeType: 'restock',
        physicalDelta: 10,
        reservedDelta: 2,
        notes: 'Restocked',
        timestamp: ts,
      );

      final map = ledger.toMap();

      expect(map['productId'], 'p1');
      expect(map['actorId'], 'admin1');
      expect(map['actorType'], 'admin');
      expect(map['orderId'], 'o1');
      expect(map['changeType'], 'restock');
      expect(map['physicalDelta'], 10);
      expect(map['reservedDelta'], 2);
      expect(map['notes'], 'Restocked');
      expect(map['timestamp'], isA<Timestamp>());
    });

    test('omits orderId when null', () {
      final ledger = InventoryLedgerDto(
        id: 'l1',
        productId: 'p1',
        actorId: 'admin1',
        changeType: 'restock',
        physicalDelta: 5,
        reservedDelta: 0,
        notes: 'test',
        timestamp: DateTime.now(),
      );

      final map = ledger.toMap();

      expect(map.containsKey('orderId'), false);
    });
  });
}
