abstract class CartRepository {
  /// Raw cart map as stored on the user doc (`{productId: {product, quantity}}`),
  /// or null if the user has no cart field yet.
  Future<Map<String, dynamic>?> getCart(String userId);

  /// Persists the cart map onto the user doc (merge write).
  Future<void> saveCart(String userId, Map<String, dynamic> cartMap);
}
