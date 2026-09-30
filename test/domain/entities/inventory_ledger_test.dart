import 'package:flutter_test/flutter_test.dart';
import 'package:hypermart/domain/entities/inventory_ledger.dart';

void main() {
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

  group('InventoryLedger backward-compat adminId getter', () {
    test('adminId returns actorId', () {
      final ledger = InventoryLedger(
        id: 'l1',
        productId: 'p1',
        actorId: 'admin42',
        changeType: InventoryLedger.kRestock,
        physicalDelta: 10,
        reservedDelta: 0,
        notes: 'Restocked',
        timestamp: DateTime(2025, 8, 1),
      );

      expect(ledger.adminId, 'admin42');
    });

    test('adminId matches actorId for system actor', () {
      final ledger = InventoryLedger(
        id: 'l2',
        productId: 'p2',
        actorId: 'system',
        actorType: InventoryLedger.kActorSystem,
        changeType: InventoryLedger.kSale,
        physicalDelta: -1,
        reservedDelta: 0,
        notes: 'Auto sale',
        timestamp: DateTime(2025, 8, 1),
      );

      expect(ledger.adminId, ledger.actorId);
    });
  });

  group('InventoryLedger construction', () {
    test('defaults actorType to kActorAdmin', () {
      final ledger = InventoryLedger(
        id: 'l1',
        productId: 'p1',
        actorId: 'admin1',
        changeType: InventoryLedger.kRestock,
        physicalDelta: 5,
        reservedDelta: 0,
        notes: 'test',
        timestamp: DateTime.now(),
      );

      expect(ledger.actorType, InventoryLedger.kActorAdmin);
    });

    test('all required fields are assigned', () {
      final ts = DateTime(2025, 8, 1);
      final ledger = InventoryLedger(
        id: 'l1',
        productId: 'p1',
        actorId: 'admin1',
        actorType: InventoryLedger.kActorCustomer,
        orderId: 'o1',
        changeType: InventoryLedger.kSale,
        physicalDelta: -2,
        reservedDelta: 1,
        notes: 'Sale order',
        timestamp: ts,
      );

      expect(ledger.id, 'l1');
      expect(ledger.productId, 'p1');
      expect(ledger.actorId, 'admin1');
      expect(ledger.actorType, InventoryLedger.kActorCustomer);
      expect(ledger.orderId, 'o1');
      expect(ledger.changeType, InventoryLedger.kSale);
      expect(ledger.physicalDelta, -2);
      expect(ledger.reservedDelta, 1);
      expect(ledger.notes, 'Sale order');
      expect(ledger.timestamp, ts);
    });

    test('orderId defaults to null', () {
      final ledger = InventoryLedger(
        id: 'l1',
        productId: 'p1',
        actorId: 'admin1',
        changeType: InventoryLedger.kRestock,
        physicalDelta: 5,
        reservedDelta: 0,
        notes: 'test',
        timestamp: DateTime.now(),
      );

      expect(ledger.orderId, isNull);
    });
  });
}
