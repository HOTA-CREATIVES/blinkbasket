import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/inventory_ledger.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_dto.dart';
import '../models/inventory_ledger_dto.dart';
import '../../core/utils/app_exception.dart';

class FirebaseProductRepository implements ProductRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<List<Product>> streamProducts() {
    return _db.collection('products').snapshots().map((snapshot) => snapshot.docs
        .map((doc) => ProductDto.fromMap(doc.data(), doc.id))
        .toList());
  }

  @override
  Future<Product?> getProductById(String id) async {
    final doc = await _db.collection('products').doc(id).get();
    if (!doc.exists) return null;
    return ProductDto.fromMap(doc.data() ?? {}, doc.id);
  }

  @override
  Future<void> addProduct(Product product) async {
    try {
      final dto = ProductDto.fromEntity(product);
      final productRef = _db.collection('products').doc();
      final ledgerRef = _db.collection('inventoryLogs').doc();

      final batch = _db.batch();
      batch.set(productRef, dto.toMap());
      if (product.physicalStock > 0) {
        batch.set(ledgerRef, {
          'productId': productRef.id,
          'adminId': 'system',
          'changeType': 'restock',
          'physicalDelta': product.physicalStock,
          'reservedDelta': 0,
          'notes': 'Initial stock on product creation',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      throw AppException.from(e, action: 'add product');
    }
  }

  @override
  Future<void> updateProduct(Product product) async {
    try {
      final dto = ProductDto.fromEntity(product);
      // Use toUpdateMapWithoutStock() to prevent stock field overwrites
      // without a corresponding inventory ledger entry. All stock changes
      // must go through [adjustStock] which writes an inventoryLogs entry.
      await _db.collection('products').doc(product.id).update(dto.toUpdateMapWithoutStock());
    } catch (e) {
      throw AppException.from(e, action: 'update product');
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    try {
      final doc = await _db.collection('products').doc(id).get();
      if (doc.exists) {
        final reserved = (doc.data()?['reservedStock'] as num?)?.toInt() ?? 0;
        if (reserved > 0) {
          throw AppException(
            "Cannot delete product with active reserved stock ($reserved units in pending orders). "
            "Please wait for orders to complete or cancel them first.",
          );
        }
      }
      await _db.collection('products').doc(id).delete();
    } catch (e) {
      throw AppException.from(e, action: 'delete product');
    }
  }

  @override
  Stream<List<InventoryLedger>> streamInventoryLogs(String productId, {int limit = 200}) {
    return _db
        .collection('inventoryLogs')
        .where('productId', isEqualTo: productId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InventoryLedgerDto.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<InventoryLedger>> streamAllInventoryLogs({int limit = 50}) {
    return _db
        .collection('inventoryLogs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InventoryLedgerDto.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Future<void> adjustStock({
    required String productId,
    required int physicalDelta,
    required int reservedDelta,
    required String changeType,
    required String notes,
    required String adminId,
    String actorType = 'admin',
  }) async {
    try {
      final productRef = _db.collection('products').doc(productId);
      final ledgerRef = _db.collection('inventoryLogs').doc();

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) {
          throw Exception("Product not found: $productId");
        }

        final data = snapshot.data() ?? {};
        final stockVal = data['stock'] ?? 0;
        final physicalStock = data['physicalStock'] ?? stockVal;
        final reservedStock = data['reservedStock'] ?? 0;

        // Clamp to zero — mirrors the floor guard in the Cloud Functions
        // stock-adjustment paths (verifyDeliveryOtp, onOrderWritten), so a
        // bad correction can't push a product doc into negative stock.
        final newPhysical = (physicalStock + physicalDelta).clamp(0, 1 << 31);
        final newReserved = (reservedStock + reservedDelta).clamp(0, 1 << 31);
        final newAvailable = newPhysical - newReserved;

        transaction.update(productRef, {
          'physicalStock': newPhysical,
          'reservedStock': newReserved,
          'availableStock': newAvailable,
          'stock': newAvailable,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(ledgerRef, {
          'productId': productId,
          'actorId': adminId,
          'actorType': actorType,
          'changeType': changeType,
          'physicalDelta': physicalDelta,
          'reservedDelta': reservedDelta,
          'notes': notes,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw AppException.from(e, action: 'adjust stock');
    }
  }
}
