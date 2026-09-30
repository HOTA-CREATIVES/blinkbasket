import '../../domain/entities/order.dart';
import '../../domain/entities/product.dart';
import '../providers/cart_provider.dart';

/// Result of a reorder attempt: how many line items were added to the
/// cart vs. skipped because the product no longer exists or is out of stock.
class ReorderOutcome {
  final int addedCount;
  final int skippedCount;

  const ReorderOutcome({required this.addedCount, required this.skippedCount});
}

class ReorderHelper {
  /// Re-adds a past order's items to the cart using their *current* price
  /// and stock (never the frozen snapshot on [OrderItem]). Quantities are
  /// capped at whatever is currently in stock; unavailable products are
  /// skipped rather than failing the whole reorder.
  static Future<ReorderOutcome> reorderOrderItems(
    List<OrderItem> items,
    Future<Product?> Function(String productId) getProduct,
    CartProvider cart,
  ) async {
    var added = 0;
    var skipped = 0;

    for (final item in items) {
      final product = await getProduct(item.productId);
      if (product == null || product.stock <= 0) {
        skipped++;
        continue;
      }
      final quantity =
          item.quantity < product.stock ? item.quantity : product.stock;
      cart.addItemQuantity(product, quantity);
      added++;
    }

    return ReorderOutcome(addedCount: added, skippedCount: skipped);
  }
}
