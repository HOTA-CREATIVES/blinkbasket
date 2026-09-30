import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/cart_repository.dart';

class FirebaseCartRepository implements CartRepository {
  final FirebaseFirestore _firestore;

  FirebaseCartRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>?> getCart(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final cart = doc.data()?['cart'];
    return cart == null ? null : Map<String, dynamic>.from(cart);
  }

  @override
  Future<void> saveCart(String userId, Map<String, dynamic> cartMap) async {
    await _firestore.collection('users').doc(userId).set(
      {'cart': cartMap, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}
