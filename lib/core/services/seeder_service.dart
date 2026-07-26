import 'package:cloud_firestore/cloud_firestore.dart';

class SeederService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> seedTestData() async {
    final batch = _db.batch();

    // 1. Seed Delivery Zones
    final zoneRef = _db.collection('deliveryZones').doc('zone_west_godavari_1');
    batch.set(zoneRef, {
      'zoneId': 'zone_west_godavari_1',
      'villageIds': ['undi', 'bhimavaram', 'palakollu', 'veeravasaram'],
      'deliveryFee': 20.0,
      'minimumOrder': 0.0,
      'freeDeliveryAbove': 199.0,
      'estimatedTime': '30 mins',
      'activeRiders': [],
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Seed Villages
    final List<Map<String, dynamic>> villages = [
      {
        'villageId': 'undi',
        'villageName': 'Undi',
        'mandal': 'Undi',
        'district': 'West Godavari',
        'isActive': true,
        'deliveryAvailable': true,
        'deliveryFee': 15.0,
        'estimatedTime': '20 mins',
        'minimumOrder': 0.0,
        'riderIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'villageId': 'bhimavaram',
        'villageName': 'Bhimavaram',
        'mandal': 'Bhimavaram',
        'district': 'West Godavari',
        'isActive': true,
        'deliveryAvailable': true,
        'deliveryFee': 20.0,
        'estimatedTime': '25 mins',
        'minimumOrder': 0.0,
        'riderIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'villageId': 'palakollu',
        'villageName': 'Palakollu',
        'mandal': 'Palakollu',
        'district': 'West Godavari',
        'isActive': true,
        'deliveryAvailable': true,
        'deliveryFee': 25.0,
        'estimatedTime': '35 mins',
        'minimumOrder': 0.0,
        'riderIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'villageId': 'veeravasaram',
        'villageName': 'Veeravasaram',
        'mandal': 'Veeravasaram',
        'district': 'West Godavari',
        'isActive': true,
        'deliveryAvailable': true,
        'deliveryFee': 20.0,
        'estimatedTime': '30 mins',
        'minimumOrder': 0.0,
        'riderIds': [],
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (var v in villages) {
      final docRef = _db.collection('villages').doc(v['villageId'] as String);
      batch.set(docRef, v);
    }

    // 3. Seed Products
    final List<Map<String, dynamic>> products = [
      {
        'name': 'Fresh Red Apples',
        'description': 'Crisp and sweet organic red apples sourced from local orchards.',
        'price': 140.0,
        'discountedPrice': 120.0,
        'unit': '1 kg',
        'category': 'Fruits & Vegetables',
        'stock': 50,
        'imageUrl': 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=500&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=500&q=80'],
        'isActive': true,
        'isAvailable': true,
        'isFeatured': true,
        'tags': ['fresh', 'fruit', 'organic', 'apples'],
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Organic Bananas',
        'description': 'Rich in potassium, fresh Cavendish organic bananas.',
        'price': 60.0,
        'discountedPrice': 50.0,
        'unit': '1 doz',
        'category': 'Fruits & Vegetables',
        'stock': 80,
        'imageUrl': 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=500&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=500&q=80'],
        'isActive': true,
        'isAvailable': true,
        'isFeatured': true,
        'tags': ['fresh', 'fruit', 'banana'],
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Pure Cow Milk',
        'description': 'Pasteurized full-cream farm fresh cow milk.',
        'price': 65.0,
        'discountedPrice': 60.0,
        'unit': '1 L',
        'category': 'Dairy & Eggs',
        'stock': 40,
        'imageUrl': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=500&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=500&q=80'],
        'isActive': true,
        'isAvailable': true,
        'isFeatured': false,
        'tags': ['dairy', 'milk'],
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Farm Fresh Eggs',
        'description': 'High protein brown eggs from free-range chickens.',
        'price': 90.0,
        'discountedPrice': 80.0,
        'unit': '12 pcs',
        'category': 'Dairy & Eggs',
        'stock': 30,
        'imageUrl': 'https://images.unsplash.com/photo-1506976785307-8732e854ad03?auto=format&fit=crop&w=500&q=80',
        'imageUrls': ['https://images.unsplash.com/photo-1506976785307-8732e854ad03?auto=format&fit=crop&w=500&q=80'],
        'isActive': true,
        'isAvailable': true,
        'isFeatured': false,
        'tags': ['dairy', 'eggs', 'protein'],
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (var prod in products) {
      final docRef = _db.collection('products').doc();
      final stockVal = prod['stock'] ?? 0;
      final category = prod['category'] as String? ?? '';
      final name = prod['name'] as String? ?? '';

      batch.set(docRef, {
        'id': docRef.id,
        ...prod,
        'physicalStock': stockVal,
        'reservedStock': 0,
        'availableStock': stockVal,
        'lowStockThreshold': (category == 'Medicines') ? 20 : 10,
        'requiresPrescription': (name == 'Paracetamol 650mg') ? true : false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 4. Seed Whitelisted Admin
    final adminRef = _db.collection('admins').doc('admin_default_dev');
    batch.set(adminRef, {
      'name': 'Global Store Admin',
      'email': 'admin@jcmart.com',
      'phone': '9999999999',
      'village': 'Admin HQ',
      'role': 'admin',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 5. Seed Delivery Partners
    final List<Map<String, dynamic>> deliveryPartners = [
      {
        'uid': '',
        'name': 'Ramesh Kumar',
        'email': 'rider1@jcmart.com',
        'phone': '9876543210',
        'currentVillage': 'Bhimavaram',
        'vehicleDetails': 'Hero Splendor',
        'vehicleNo': 'AP37 AB 1234',
        'licenseNo': 'DL123456',
        'onDuty': true,
        'currentOrders': [],
        'completedOrders': 0,
        'earnings': 0.0,
        'deliveryZones': ['zone_west_godavari_1'],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': '',
        'name': 'Suresh Singh',
        'email': 'rider2@jcmart.com',
        'phone': '9876543211',
        'currentVillage': 'Veeravasaram',
        'vehicleDetails': 'Honda Activa',
        'vehicleNo': 'AP37 CD 5678',
        'licenseNo': 'DL654321',
        'onDuty': true,
        'currentOrders': [],
        'completedOrders': 0,
        'earnings': 0.0,
        'deliveryZones': ['zone_west_godavari_1'],
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }
    ];

    for (var partner in deliveryPartners) {
      final docRef = _db.collection('deliveryPartners').doc();
      batch.set(docRef, partner);
    }

    // 6. Seed Config
    final configRef = _db.collection('config').doc('app');
    batch.set(configRef, {
      'storeOpen': true,
      'deliveryFee': 20.0,
      'freeDeliveryAbove': 199.0,
      'etaLabel': 'Delivers in ~25 min',
      'riderPayoutPerDelivery': 30.0,
      'maintenanceMode': false,
      'minimumOrderAmount': 0.0,
      'maxOrdersPerSlot': 20,
      'categories': ['Fruits & Vegetables', 'Dairy & Eggs', 'Bakery', 'Medicines', 'Snacks', 'Beverages', 'Household'],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 7. Seed Analytics Singleton
    final analyticsRef = _db.collection('analytics').doc('summary');
    batch.set(analyticsRef, {
      'totalUsers': 0,
      'totalOrders': 0,
      'totalRevenue': 0.0,
      'totalProducts': products.length,
      'totalVillages': villages.length,
      'totalRiders': deliveryPartners.length,
      'completedOrders': 0,
      'cancelledOrders': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Commit Seeding Batch
    await batch.commit();
  }
}
