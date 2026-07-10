import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_dto.dart';

class FirebaseProductRepository implements ProductRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<List<Product>> streamProducts() {
    return _db.collection('products').snapshots().map((snapshot) => snapshot.docs
        .map((doc) => ProductDto.fromMap(doc.data(), doc.id))
        .toList());
  }

  @override
  Future<void> addProduct(Product product) async {
    final dto = ProductDto.fromEntity(product);
    await _db.collection('products').add(dto.toMap());
  }

  @override
  Future<void> updateProduct(Product product) async {
    final dto = ProductDto.fromEntity(product);
    await _db.collection('products').doc(product.id).update(dto.toMap());
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _db.collection('products').doc(id).delete();
  }
}
