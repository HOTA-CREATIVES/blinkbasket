const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

let hasCreds = false;
const tempTokenFile = path.join(__dirname, 'temp-token.json');
try {
  const configPath = path.join(process.env.USERPROFILE || process.env.HOMEPATH || '', '.config', 'configstore', 'firebase-tools.json');
  if (fs.existsSync(configPath)) {
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    if (config.tokens && config.tokens.refresh_token) {
      fs.writeFileSync(tempTokenFile, JSON.stringify({
        type: 'authorized_user',
        client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
        client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
        refresh_token: config.tokens.refresh_token
      }));
      process.env.GOOGLE_APPLICATION_CREDENTIALS = tempTokenFile;
      hasCreds = true;
    }
  }
} catch (e) {
  console.log('Failed to load user token from configstore:', e);
}

// Initialize Firestore using the active project ID
admin.initializeApp({
  projectId: 'hypermart-ee8ef'
});

function cleanup() {
  try {
    if (fs.existsSync(tempTokenFile)) {
      fs.unlinkSync(tempTokenFile);
    }
  } catch (e) {
    // Ignore cleanup errors
  }
}

process.on('exit', cleanup);
process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);
process.on('uncaughtException', (err) => {
  cleanup();
  console.error(err);
  process.exit(1);
});

const db = admin.firestore();

const products = {
  'fresh_red_apples_001': {
    'id': 'fresh_red_apples_001',
    'name': 'Fresh Red Apples',
    'description': 'Crisp and sweet organic red apples sourced from local orchards.',
    'price': 140.0,
    'unit': '1 kg',
    'category': 'Fruits & Vegetables',
    'stock': 50,
    'physicalStock': 50,
    'reservedStock': 0,
    'availableStock': 50,
    'lowStockThreshold': 10,
    'requiresPrescription': false,
    'imageUrl': 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=500&q=80',
    'isActive': true
  },
  'organic_bananas_002': {
    'id': 'organic_bananas_002',
    'name': 'Organic Bananas',
    'description': 'Rich in potassium, fresh Cavendish organic bananas.',
    'price': 60.0,
    'unit': '1 doz',
    'category': 'Fruits & Vegetables',
    'stock': 80,
    'physicalStock': 80,
    'reservedStock': 0,
    'availableStock': 80,
    'lowStockThreshold': 10,
    'requiresPrescription': false,
    'imageUrl': 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=500&q=80',
    'isActive': true
  },
  'pure_cow_milk_003': {
    'id': 'pure_cow_milk_003',
    'name': 'Pure Cow Milk',
    'description': 'Pasteurized full-cream farm fresh cow milk.',
    'price': 65.0,
    'unit': '1 L',
    'category': 'Dairy & Eggs',
    'stock': 40,
    'physicalStock': 40,
    'reservedStock': 0,
    'availableStock': 40,
    'lowStockThreshold': 10,
    'requiresPrescription': false,
    'imageUrl': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=500&q=80',
    'isActive': true
  },
  'farm_fresh_eggs_004': {
    'id': 'farm_fresh_eggs_004',
    'name': 'Farm Fresh Eggs',
    'description': 'High protein brown eggs from free-range chickens.',
    'price': 90.0,
    'unit': '12 pcs',
    'category': 'Dairy & Eggs',
    'stock': 30,
    'physicalStock': 30,
    'reservedStock': 0,
    'availableStock': 30,
    'lowStockThreshold': 10,
    'requiresPrescription': false,
    'imageUrl': 'https://images.unsplash.com/photo-1506976785307-8732e854ad03?auto=format&fit=crop&w=500&q=80',
    'isActive': true
  },
  'whole_wheat_bread_005': {
    'id': 'whole_wheat_bread_005',
    'name': 'Whole Wheat Bread',
    'description': 'Soft and healthy high-fiber whole wheat bread loaf.',
    'price': 45.0,
    'unit': '400 g',
    'category': 'Bakery',
    'stock': 20,
    'physicalStock': 20,
    'reservedStock': 0,
    'availableStock': 20,
    'lowStockThreshold': 10,
    'requiresPrescription': false,
    'imageUrl': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=500&q=80',
    'isActive': true
  },
  'paracetamol_650mg_006': {
    'id': 'paracetamol_650mg_006',
    'name': 'Paracetamol 650mg',
    'description': 'Pain relief and fever reducing tablets (consult doctor before use).',
    'price': 30.0,
    'unit': '10 tabs',
    'category': 'Medicines',
    'stock': 100,
    'physicalStock': 100,
    'reservedStock': 0,
    'availableStock': 100,
    'lowStockThreshold': 20,
    'requiresPrescription': true,
    'imageUrl': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?auto=format&fit=crop&w=500&q=80',
    'isActive': true
  },
  'potato_chips_007': {
    'id': 'potato_chips_007',
    'name': 'Potato Chips - Salted',
    'description': 'Crispy golden potato chips lightly seasoned with sea salt.',
    'price': 20.0,
    'unit': '50 g',
    'category': 'Snacks',
    'stock': 75,
    'physicalStock': 75,
    'reservedStock': 0,
    'availableStock': 75,
    'lowStockThreshold': 10,
    'requiresPrescription': false,
    'imageUrl': 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?auto=format&fit=crop&w=500&q=80',
    'isActive': true
  },
  'classic_coca_cola_008': {
    'id': 'classic_coca_cola_008',
    'name': 'Classic Coca Cola',
    'description': 'Refreshing cold carbonated soft drink.',
    'price': 40.0,
    'unit': '750 ml',
    'category': 'Beverages',
    'stock': 60,
    'physicalStock': 60,
    'reservedStock': 0,
    'availableStock': 60,
    'lowStockThreshold': 10,
    'requiresPrescription': false,
    'imageUrl': 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=500&q=80',
    'isActive': true
  },
  'dishwashing_liquid_009': {
    'id': 'dishwashing_liquid_009',
    'name': 'Dishwashing Liquid',
    'description': 'Tough on grease, gentle on hands cleaning gel.',
    'price': 55.0,
    'unit': '250 ml',
    'category': 'Household',
    'stock': 25,
    'physicalStock': 25,
    'reservedStock': 0,
    'availableStock': 25,
    'lowStockThreshold': 10,
    'requiresPrescription': false,
    'imageUrl': 'https://images.unsplash.com/photo-1607006342411-92f3d385871f?auto=format&fit=crop&w=500&q=80',
    'isActive': true
  }
};

async function seed() {
  console.log('Seeding products with inventory fields...');
  const batch = db.batch();
  
  for (const [id, data] of Object.entries(products)) {
    const docRef = db.collection('products').doc(id);
    batch.set(docRef, {
      ...data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
  }
  
  await batch.commit();
  console.log('Successfully seeded all products!');

  // Seed configurations
  console.log('Seeding global configuration...');
  const appConfigRef = db.collection('config').doc('app');
  await appConfigRef.set({
    storeOpen: true,
    deliveryFee: 30.0,
    freeDeliveryAbove: 300.0,
    whitelistedVillages: ["Bhimavaram", "Veeravasaram", "Rayakuduru", "Srungavruksham", "Mentada"]
  }, { merge: true });

  console.log('Seeding dashboard stats...');
  const statsRef = db.collection('config').doc('dashboard_stats');
  await statsRef.set({
    productCount: Object.keys(products).length,
    activeRidersCount: 0,
    activeOrdersCount: 0,
    completedRevenue: 0.0,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });
  console.log('Successfully seeded configurations!');
}

seed().catch(err => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
