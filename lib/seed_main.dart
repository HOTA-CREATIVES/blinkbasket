import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hypermart/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SeedApp());
}

class SeedApp extends StatefulWidget {
  const SeedApp({super.key});

  @override
  State<SeedApp> createState() => _SeedAppState();
}

class _SeedAppState extends State<SeedApp> {
  String _status = "Initializing Seeding...";
  bool _isSeeding = true;

  @override
  void initState() {
    super.initState();
    _seedDatabase();
  }

  Future<void> _seedDatabase() async {
    setState(() {
      _isSeeding = true;
      _status = "Seeding 10 products...";
    });

    try {
      final List<Map<String, dynamic>> products = [
        {
          "name": "Amul Taaza Milk",
          "description": "Fresh toned milk rich in calcium and protein.",
          "category": "Dairy & Eggs",
          "price": 32.0,
          "discountedPrice": 30.0,
          "unit": "500 ml",
          "imageUrl": "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&auto=format&fit=crop&q=60",
          "imageUrls": ["https://images.unsplash.com/photo-1550583724-b2692b85b150?w=500&auto=format&fit=crop&q=60"],
          "stock": 95,
          "physicalStock": 100,
          "reservedStock": 5,
          "availableStock": 95,
          "lowStockThreshold": 10,
          "isAvailable": true,
          "isFeatured": true,
          "requiresPrescription": false,
          "tags": ["milk", "dairy", "fresh", "amul"],
          "brand": "Amul",
          "rating": 4.7,
          "reviewCount": 254,
        },
        {
          "name": "Farm Fresh Eggs",
          "description": "Pack of 6 premium farm fresh eggs.",
          "category": "Dairy & Eggs",
          "price": 72.0,
          "discountedPrice": 68.0,
          "unit": "6 pcs",
          "imageUrl": "https://images.unsplash.com/photo-1516467508483-a7212febe31a?w=500&auto=format&fit=crop&q=60",
          "imageUrls": ["https://images.unsplash.com/photo-1516467508483-a7212febe31a?w=500&auto=format&fit=crop&q=60"],
          "stock": 76,
          "physicalStock": 80,
          "reservedStock": 4,
          "availableStock": 76,
          "lowStockThreshold": 10,
          "isAvailable": true,
          "isFeatured": false,
          "requiresPrescription": false,
          "tags": ["eggs", "protein", "farm"],
          "brand": "Fresh Farms",
          "rating": 4.6,
          "reviewCount": 121,
        },
        {
          "name": "Fresh Bananas",
          "description": "Naturally ripened fresh bananas.",
          "category": "Fruits & Vegetables",
          "price": 48.0,
          "discountedPrice": 42.0,
          "unit": "1 kg",
          "imageUrl": "https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=500&auto=format&fit=crop&q=60",
          "imageUrls": ["https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=500&auto=format&fit=crop&q=60"],
          "stock": 140,
          "physicalStock": 150,
          "reservedStock": 10,
          "availableStock": 140,
          "lowStockThreshold": 20,
          "isAvailable": true,
          "isFeatured": true,
          "requiresPrescription": false,
          "tags": ["banana", "fruit", "fresh"],
          "brand": "Local Farm",
          "rating": 4.5,
          "reviewCount": 182,
        },
        {
          "name": "Red Apples",
          "description": "Premium juicy red apples.",
          "category": "Fruits & Vegetables",
          "price": 189.0,
          "discountedPrice": 169.0,
          "unit": "1 kg",
          "imageUrl": "https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500&auto=format&fit=crop&q=60",
          "imageUrls": ["https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=500&auto=format&fit=crop&q=60"],
          "stock": 84,
          "physicalStock": 90,
          "reservedStock": 6,
          "availableStock": 84,
          "lowStockThreshold": 15,
          "isAvailable": true,
          "isFeatured": true,
          "requiresPrescription": false,
          "tags": ["apple", "fruit", "fresh"],
          "brand": "Washington",
          "rating": 4.8,
          "reviewCount": 315,
        },
        {
          "name": "Fortune Sunflower Oil",
          "description": "Refined sunflower cooking oil.",
          "category": "Staples & Grains",
          "price": 179.0,
          "discountedPrice": 169.0,
          "unit": "1 L",
          "imageUrl": "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=500&auto=format&fit=crop&q=60",
          "imageUrls": ["https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=500&auto=format&fit=crop&q=60"],
          "stock": 67,
          "physicalStock": 70,
          "reservedStock": 3,
          "availableStock": 67,
          "lowStockThreshold": 10,
          "isAvailable": true,
          "isFeatured": false,
          "requiresPrescription": false,
          "tags": ["oil", "cooking", "sunflower"],
          "brand": "Fortune",
          "rating": 4.7,
          "reviewCount": 201,
        },
        {
          "name": "Aashirvaad Atta",
          "description": "Whole wheat flour for soft rotis.",
          "category": "Staples & Grains",
          "price": 295.0,
          "discountedPrice": 279.0,
          "unit": "5 kg",
          "imageUrl": "https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500&auto=format&fit=crop&q=60",
          "imageUrls": ["https://images.unsplash.com/photo-1586201375761-83865001e31c?w=500&auto=format&fit=crop&q=60"],
          "stock": 58,
          "physicalStock": 60,
          "reservedStock": 2,
          "availableStock": 58,
          "lowStockThreshold": 10,
          "isAvailable": true,
          "isFeatured": true,
          "requiresPrescription": false,
          "tags": ["atta", "wheat", "flour"],
          "brand": "Aashirvaad",
          "rating": 4.8,
          "reviewCount": 489,
        },
        {
          "name": "Lay's Classic Chips",
          "description": "Lightly salted potato chips.",
          "category": "Snacks & Drinks",
          "price": 20.0,
          "discountedPrice": 18.0,
          "unit": "52 g",
          "imageUrl": "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=500&auto=format&fit=crop&q=60",
          "imageUrls": ["https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=500&auto=format&fit=crop&q=60"],
          "stock": 235,
          "physicalStock": 250,
          "reservedStock": 15,
          "availableStock": 235,
          "lowStockThreshold": 30,
          "isAvailable": true,
          "isFeatured": false,
          "requiresPrescription": false,
          "tags": ["chips", "snacks", "lays"],
          "brand": "Lay's",
          "rating": 4.6,
          "reviewCount": 612,
        },
        {
          "name": "Coca-Cola",
          "description": "Refreshing carbonated soft drink.",
          "category": "Snacks & Drinks",
          "price": 40.0,
          "discountedPrice": 38.0,
          "unit": "750 ml",
          "imageUrl": "https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=500&auto=format&fit=crop&q=60",
          "imageUrls": ["https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=500&auto=format&fit=crop&q=60"],
          "stock": 173,
          "physicalStock": 180,
          "reservedStock": 7,
          "availableStock": 173,
          "lowStockThreshold": 20,
          "isAvailable": true,
          "isFeatured": false,
          "requiresPrescription": false,
          "tags": ["drink", "cola", "cold"],
          "brand": "Coca-Cola",
          "rating": 4.7,
          "reviewCount": 702,
        },
        {
          "name": "Colgate Strong Teeth Toothpaste",
          "description": "Daily protection toothpaste.",
          "category": "Personal Care",
          "price": 95.0,
          "discountedPrice": 89.0,
          "unit": "200 g",
          "imageUrl": "https://images.unsplash.com/photo-1559591937-b12597b7ebde?w=500&auto=format&fit=crop&q=60",
          "imageUrls": ["https://images.unsplash.com/photo-1559591937-b12597b7ebde?w=500&auto=format&fit=crop&q=60"],
          "stock": 115,
          "physicalStock": 120,
          "reservedStock": 5,
          "availableStock": 115,
          "lowStockThreshold": 15,
          "isAvailable": true,
          "isFeatured": false,
          "requiresPrescription": false,
          "tags": ["toothpaste", "oral care"],
          "brand": "Colgate",
          "rating": 4.8,
          "reviewCount": 431,
        },
        {
          "name": "Dove Bath Soap",
          "description": "Moisturizing beauty bathing bar.",
          "category": "Personal Care",
          "price": 59.0,
          "discountedPrice": 55.0,
          "unit": "100 g",
          "imageUrl": "https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=500&auto=format&fit=crop&q=60",
          "imageUrls": ["https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=500&auto=format&fit=crop&q=60"],
          "stock": 136,
          "physicalStock": 140,
          "reservedStock": 4,
          "availableStock": 136,
          "lowStockThreshold": 15,
          "isAvailable": true,
          "isFeatured": true,
          "requiresPrescription": false,
          "tags": ["soap", "bath", "personal care"],
          "brand": "Dove",
          "rating": 4.9,
          "reviewCount": 512,
        }
      ];

      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('products');

      for (var p in products) {
        final docRef = collection.doc();
        batch.set(docRef, {
          ...p,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      setState(() {
        _isSeeding = false;
        _status = "SUCCESS: 10 products seeded to Firestore!";
      });
    } catch (e) {
      setState(() {
        _isSeeding = false;
        _status = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('HyperMart Catalog Seeder')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _status.contains('SUCCESS') ? Icons.check_circle : Icons.cloud_upload,
                  size: 80,
                  color: _status.contains('SUCCESS') ? Colors.green : Colors.blue,
                ),
                const SizedBox(height: 24),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                if (_isSeeding) const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
