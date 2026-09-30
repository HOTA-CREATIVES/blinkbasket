/**
 * Seed script for the Firebase Local Emulator Suite.
 *
 *   1. Start the emulators:  npm run emulators
 *   2. Seed the data:        npm run seed
 *   3. Run the app:          flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
 *
 * Everything is written through the Admin SDK (which bypasses security rules),
 * but the shape of every document is kept byte-compatible with what the Flutter
 * DTOs and the Cloud Functions expect — otherwise the app boots against an
 * emulator and silently renders empty screens.
 *
 * The script is idempotent: every document uses a deterministic ID and is
 * written with `set`, and Auth users are updated in place when they already
 * exist (so re-running also repairs drifted passwords and custom claims).
 */

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8090';
process.env.FIREBASE_AUTH_EMULATOR_HOST =
  process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';

const admin = require('firebase-admin');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'hypermart-ee8ef';
const PASSWORD = 'Password123!';

const existingApps = typeof admin.getApps === 'function' ? admin.getApps() : admin.apps;
if (!existingApps || existingApps.length === 0) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const app = admin.getApps()[0];
const db = getFirestore(app);
const auth = getAuth(app);

// ── Service area ────────────────────────────────────────────────────────────
// Mirrors lib/core/data/villages.dart and the VILLAGES array in
// functions/src/index.ts. Keep all three in sync.
const VILLAGES = [
  { name: 'Bhimavaram', lat: 16.5449, lng: 81.5212, pincode: '534201', mandal: 'Bhimavaram' },
  { name: 'Veeravasaram', lat: 16.5050, lng: 81.6062, pincode: '534245', mandal: 'Veeravasaram' },
  { name: 'Rayakuduru', lat: 16.5861, lng: 81.5034, pincode: '534208', mandal: 'Bhimavaram' },
  { name: 'Srungavruksham', lat: 16.5015, lng: 81.5492, pincode: '534204', mandal: 'Bhimavaram' },
  { name: 'Mentada', lat: 16.6341, lng: 81.6500, pincode: '534250', mandal: 'Veeravasaram' },
];
const DISTRICT = 'West Godavari';
const ZONE_ID = 'zone_west_godavari_1';

const now = Date.now();
const minutesAgo = (m) => Timestamp.fromMillis(now - m * 60 * 1000);
const hoursAgo = (h) => Timestamp.fromMillis(now - h * 60 * 60 * 1000);
const daysAgo = (d) => Timestamp.fromMillis(now - d * 24 * 60 * 60 * 1000);

const ok = (m) => console.log(`  \u2713 ${m}`);

/** Creates the Auth user, or resets password/claims on the existing one. */
async function upsertAuthUser({ email, password, displayName, phoneNumber, claims }) {
  let user;
  try {
    user = await auth.getUserByEmail(email);
    await auth.updateUser(user.uid, {
      password,
      displayName,
      phoneNumber,
      emailVerified: true,
      disabled: false,
    });
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    user = await auth.createUser({ email, password, displayName, phoneNumber, emailVerified: true });
  }
  // setCustomUserClaims REPLACES the whole claim set, so each persona gets
  // exactly its own claim and never inherits another role's.
  await auth.setCustomUserClaims(user.uid, claims);
  ok(`Auth user ${email} (claims: ${JSON.stringify(claims)})`);
  return user.uid;
}

async function seed() {
  console.log('\u{1F331} Seeding Firebase Emulator Suite (project: ' + PROJECT_ID + ')\n');

  // ── 1. Personas ──────────────────────────────────────────────────────────
  const adminUid = await upsertAuthUser({
    email: 'admin@jcmart.com',
    password: PASSWORD,
    displayName: 'Global Store Admin',
    phoneNumber: '+919999999999',
    claims: { admin: true },
  });

  const riderUid = await upsertAuthUser({
    email: 'rider@jcmart.com',
    password: PASSWORD,
    displayName: 'Speedy Rider',
    phoneNumber: '+919876543210',
    claims: { delivery: true },
  });

  const rider2Uid = await upsertAuthUser({
    email: 'rider2@jcmart.com',
    password: PASSWORD,
    displayName: 'Anitha Delivery',
    phoneNumber: '+918800112233',
    claims: { delivery: true },
  });

  const customerUid = await upsertAuthUser({
    email: 'customer@jcmart.com',
    password: PASSWORD,
    displayName: 'Test Customer',
    phoneNumber: '+919988776655',
    claims: {},
  });

  const customer2Uid = await upsertAuthUser({
    email: 'customer2@jcmart.com',
    password: PASSWORD,
    displayName: 'Rahul Verma',
    phoneNumber: '+919876501234',
    claims: {},
  });

  // ── 2. Config ────────────────────────────────────────────────────────────
  // categories here are the single source of truth for the customer home
  // screen's category rail and the search filter chips — every seeded product
  // must use one of these strings or it becomes unreachable in the UI.
  const CATEGORIES = [
    'Fruits & Vegetables',
    'Dairy & Eggs',
    'Bakery',
    'Staples & Grains',
    'Snacks & Beverages',
    'Personal Care',
    'Household',
  ];

  await db.collection('config').doc('app').set(
    {
      storeOpen: true,
      maintenanceMode: false,
      deliveryFee: 20.0,
      freeDeliveryAbove: 199.0,
      minimumOrderAmount: 0.0,
      maxOrdersPerSlot: 20,
      etaLabel: 'Delivers in ~25 min',
      riderPayoutPerDelivery: 30.0,
      supportPhone: '+91 90000 00000',
      supportWhatsapp: '+91 90000 00000',
      categories: CATEGORIES,
      // ServiceZone DTO: { name, lat, lng, radiusKm }. These names double as
      // the "village" label shown to the customer and matched against a rider's
      // village when broadcasting a new order.
      serviceZones: VILLAGES.map((v) => ({
        name: v.name,
        lat: v.lat,
        lng: v.lng,
        radiusKm: 8.0,
      })),
      updatedAt: Timestamp.now(),
    },
    { merge: true },
  );
  ok('config/app (store open, fees, categories, 5 service zones)');

  // ── 3. Persona documents ─────────────────────────────────────────────────
  await db
    .collection('admins')
    .doc(adminUid)
    .set(
      {
        uid: adminUid,
        name: 'Global Store Admin',
        email: 'admin@jcmart.com',
        phone: '9999999999',
        village: VILLAGES[0].name,
        mandal: VILLAGES[0].mandal,
        district: DISTRICT,
        role: 'admin',
        isActive: true,
        createdAt: daysAgo(30),
        updatedAt: Timestamp.now(),
      },
      { merge: true },
    );
  ok('admins/' + adminUid);

  const riderDocs = [
    {
      uid: riderUid,
      name: 'Speedy Rider',
      email: 'rider@jcmart.com',
      phone: '9876543210',
      village: 'Bhimavaram',
      lat: 16.5449,
      lng: 81.5212,
      vehicle: { details: 'Hero Splendor', no: 'AP 21 AB 1234', license: 'AP-DL-2019-778812' },
      onDuty: true,
    },
    {
      uid: rider2Uid,
      name: 'Anitha Delivery',
      email: 'rider2@jcmart.com',
      phone: '8800112233',
      village: 'Veeravasaram',
      lat: 16.5050,
      lng: 81.6062,
      vehicle: { details: 'TVS Jupiter', no: 'AP 21 CD 5678', license: 'AP-DL-2021-441209' },
      onDuty: false,
    },
  ];

  for (const r of riderDocs) {
    await db.collection('deliveryBoys').doc(r.uid).set(
      {
        uid: r.uid,
        docId: r.uid,
        name: r.name,
        email: r.email,
        phone: r.phone,
        village: r.village,
        mandal: VILLAGES.find((v) => v.name === r.village)?.mandal ?? DISTRICT,
        district: DISTRICT,
        deliveryZoneId: ZONE_ID,
        role: 'delivery',
        isActive: true,
        onDuty: r.onDuty,
        onboardingCompleted: true,
        onboardingStep: 3,
        vehicleDetails: r.vehicle.details,
        vehicleNo: r.vehicle.no,
        licenseNo: r.vehicle.license,
        currentLatitude: r.lat,
        currentLongitude: r.lng,
        currentLocationUpdatedAt: Timestamp.now(),
        fcmTokens: [],
        isDeleted: false,
        totalDeliveries: 42,
        rating: 4.8,
        createdAt: daysAgo(60),
        updatedAt: Timestamp.now(),
      },
      { merge: true },
    );
  }
  ok('deliveryBoys — 2 riders (1 on duty, 1 off duty)');

  const customerDocs = [
    {
      uid: customerUid,
      name: 'Test Customer',
      email: 'customer@jcmart.com',
      phone: '9988776655',
      village: 'Bhimavaram',
      address: 'Flat 401, Sai Residency, Main Road',
      landmark: 'Opposite SBI ATM',
      lat: 16.5455,
      lng: 81.5218,
    },
    {
      uid: customer2Uid,
      name: 'Rahul Verma',
      email: 'customer2@jcmart.com',
      phone: '9876501234',
      village: 'Undi',
      address: 'House 12-4, Market Road',
      landmark: 'Near RTC Bus Stand',
      lat: 16.5030,
      lng: 81.1090,
    },
  ];

  for (const c of customerDocs) {
    const known = VILLAGES.find((v) => v.name === c.village);
    await db.collection('users').doc(c.uid).set(
      {
        uid: c.uid,
        docId: c.uid,
        name: c.name,
        email: c.email,
        phone: c.phone,
        role: 'customer',
        isActive: true,
        onboardingCompleted: true,
        onboardingStep: 3,
        village: c.village,
        mandal: known?.mandal ?? c.village,
        district: DISTRICT,
        deliveryAvailable: true,
        deliveryZoneId: ZONE_ID,
        notificationsEnabled: true,
        totalOrders: 0,
        totalSpent: 0.0,
        firstOrderCompleted: false,
        favoriteProductIds: ['prod_apples_red', 'prod_milk_toned'],
        fcmTokens: [],
        addresses: [
          {
            id: 'addr_home_' + c.uid,
            name: 'Home',
            addressLine1: c.address,
            pinCode: known?.pincode ?? '534201',
            pincode: known?.pincode ?? '534201',
            village: c.village,
            mandal: known?.mandal ?? c.village,
            district: DISTRICT,
            landmark: c.landmark,
            latitude: c.lat,
            longitude: c.lng,
            isDefault: true,
          },
        ],
        createdAt: daysAgo(20),
        updatedAt: Timestamp.now(),
      },
      { merge: true },
    );
  }
  ok('users — 2 customers (onboarding complete, home address set)');

  // ── 4. Banners ───────────────────────────────────────────────────────────
  const banners = [
    { id: 'banner_fresh_10', category: 'Fruits & Vegetables', sortOrder: 0, imageUrl: 'https://images.unsplash.com/photo-1619566636858-adf3ef46400b?auto=format&fit=crop&w=900&q=70' },
    { id: 'banner_atta_20', category: 'Staples & Grains', sortOrder: 1, imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=900&q=70' },
    { id: 'banner_dairy', category: 'Dairy & Eggs', sortOrder: 2, imageUrl: 'https://images.unsplash.com/photo-1626201375761-83865001e31c?auto=format&fit=crop&w=900&q=70' },
  ];
  for (const b of banners) {
    await db.collection('banners').doc(b.id).set(
      { imageUrl: b.imageUrl, category: b.category, isActive: true, sortOrder: b.sortOrder, createdAt: daysAgo(5) },
      { merge: true },
    );
  }
  ok('banners — 3 promo slides');

  // ── 5. Products ──────────────────────────────────────────────────────────
  // Deterministic IDs so seeded orders can reference real products and so
  // re-seeding updates in place instead of duplicating the catalog.
  // stock triple must always satisfy: availableStock = physicalStock - reservedStock
  const products = [
    {
      id: 'prod_apples_red', name: 'Fresh Red Apples', category: 'Fruits & Vegetables',
      description: 'Crisp, sweet Himachal apples. Hand-picked and stored cold.',
      price: 140, discountedPrice: 120, unit: '1 kg', brand: 'Himachal Orchards',
      rating: 4.8, reviewCount: 315, physicalStock: 60, reservedStock: 0, lowStockThreshold: 10,
      isFeatured: true, tags: ['fresh', 'fruit', 'apple', 'organic'],
      image: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6',
    },
    {
      id: 'prod_bananas', name: 'Organic Bananas', category: 'Fruits & Vegetables',
      description: 'Naturally ripened Cavendish bananas, rich in potassium.',
      price: 60, discountedPrice: 50, unit: '1 doz', brand: 'Local Farm',
      rating: 4.5, reviewCount: 182, physicalStock: 90, reservedStock: 0, lowStockThreshold: 15,
      isFeatured: true, tags: ['fresh', 'fruit', 'banana'],
      image: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e',
    },
    {
      id: 'prod_milk_toned', name: 'Toned Milk', category: 'Dairy & Eggs',
      description: 'Pasteurised full-cream toned milk, delivered chilled.',
      price: 32, discountedPrice: 30, unit: '500 ml', brand: 'Amul Taaza',
      rating: 4.7, reviewCount: 254, physicalStock: 120, reservedStock: 0, lowStockThreshold: 20,
      isFeatured: true, tags: ['milk', 'dairy', 'fresh'],
      image: 'https://images.unsplash.com/photo-1550583724-b2692b85b150',
    },
    {
      id: 'prod_eggs_12', name: 'Farm Fresh Eggs', category: 'Dairy & Eggs',
      description: 'Pack of 12 free-range brown eggs, high in protein.',
      price: 90, discountedPrice: 80, unit: '12 pcs', brand: 'Fresh Farms',
      rating: 4.6, reviewCount: 121, physicalStock: 40, reservedStock: 0, lowStockThreshold: 10,
      isFeatured: false, tags: ['eggs', 'protein', 'farm'],
      image: 'https://images.unsplash.com/photo-1506976785307-8732e854ad03',
    },
    {
      id: 'prod_bread_brown', name: 'Whole Wheat Brown Bread', category: 'Bakery',
      description: 'Soft whole-wheat loaf baked fresh every morning.',
      price: 55, discountedPrice: 49, unit: '400 g', brand: 'Bake Story',
      rating: 4.4, reviewCount: 96, physicalStock: 35, reservedStock: 0, lowStockThreshold: 8,
      isFeatured: false, tags: ['bread', 'bakery', 'wheat'],
      image: 'https://images.unsplash.com/photo-1509440159596-0249088772ff',
    },
    {
      id: 'prod_atta_5kg', name: 'Whole Wheat Atta', category: 'Staples & Grains',
      description: 'Chakki-fresh atta for soft rotis. 5 kg pack.',
      price: 295, discountedPrice: 279, unit: '5 kg', brand: 'Aashirvaad',
      rating: 4.8, reviewCount: 489, physicalStock: 70, reservedStock: 0, lowStockThreshold: 15,
      isFeatured: true, tags: ['atta', 'wheat', 'flour', 'staples'],
      image: 'https://images.unsplash.com/photo-1586201375761-83865001e31c',
    },
    {
      id: 'prod_oil_sunflower', name: 'Sunflower Oil', category: 'Staples & Grains',
      description: 'Refined sunflower cooking oil, 1 L bottle.',
      price: 179, discountedPrice: 169, unit: '1 L', brand: 'Fortune',
      rating: 4.7, reviewCount: 201, physicalStock: 80, reservedStock: 0, lowStockThreshold: 15,
      isFeatured: false, tags: ['oil', 'cooking', 'staples'],
      image: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5',
    },
    {
      id: 'prod_chips_classic', name: 'Classic Salted Chips', category: 'Snacks & Beverages',
      description: 'Lightly salted potato chips in a 52 g pack.',
      price: 20, discountedPrice: 18, unit: '52 g', brand: "Lay's",
      rating: 4.6, reviewCount: 612, physicalStock: 250, reservedStock: 0, lowStockThreshold: 30,
      isFeatured: false, tags: ['chips', 'snacks'],
      image: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b',
    },
    {
      id: 'prod_cola_750', name: 'Soft Drink 750 ml', category: 'Snacks & Beverages',
      description: 'Chilled carbonated soft drink.',
      price: 40, discountedPrice: 38, unit: '750 ml', brand: 'Coca-Cola',
      rating: 4.7, reviewCount: 702, physicalStock: 180, reservedStock: 0, lowStockThreshold: 20,
      isFeatured: false, tags: ['drink', 'beverage', 'cold'],
      image: 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97',
    },
    {
      id: 'prod_toothpaste', name: 'Strong Teeth Toothpaste', category: 'Personal Care',
      description: 'Daily cavity protection toothpaste, 200 g.',
      price: 95, discountedPrice: 89, unit: '200 g', brand: 'Colgate',
      rating: 4.8, reviewCount: 431, physicalStock: 120, reservedStock: 0, lowStockThreshold: 15,
      isFeatured: false, tags: ['toothpaste', 'oral care'],
      image: 'https://images.unsplash.com/photo-1559591937-b12597b7ebde',
    },
    {
      id: 'prod_soap_dove', name: 'Moisturising Bath Soap', category: 'Personal Care',
      description: 'Moisturising beauty bathing bar, 100 g.',
      price: 59, discountedPrice: 55, unit: '100 g', brand: 'Dove',
      rating: 4.9, reviewCount: 512, physicalStock: 140, reservedStock: 0, lowStockThreshold: 20,
      isFeatured: true, tags: ['soap', 'bath', 'personal care'],
      image: 'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04',
    },
    {
      id: 'prod_detergent', name: 'Detergent Washing Powder', category: 'Household',
      description: 'High-foam machine-wash detergent, 2 kg.',
      price: 260, discountedPrice: 239, unit: '2 kg', brand: 'Surf Excel',
      rating: 4.6, reviewCount: 275, physicalStock: 60, reservedStock: 0, lowStockThreshold: 10,
      isFeatured: false, tags: ['detergent', 'cleaning', 'household'],
      image: 'https://images.unsplash.com/photo-1583947215259-38e31be8751f',
    },
    {
      // Intentionally low stock so the admin's low-stock badge has something
      // to show, and so a customer can reproduce the "only N left" error.
      id: 'prod_sugar_1kg', name: 'Fine Grain Sugar', category: 'Staples & Grains',
      description: 'Refined fine-grain sugar, 1 kg pack.',
      price: 48, discountedPrice: 45, unit: '1 kg', brand: 'Sugar Factory',
      rating: 4.3, reviewCount: 88, physicalStock: 6, reservedStock: 0, lowStockThreshold: 10,
      isFeatured: false, tags: ['sugar', 'staples'],
      image: 'https://images.unsplash.com/photo-1581441363689-1f3c3c414635',
    },
    {
      // Out of stock: availableStock 0, hidden behind isAvailable:false on the
      // product card and rejected by placeOrder's stock check.
      id: 'prod_toy_out', name: 'Building Blocks Set', category: 'Household',
      description: '250-piece creative building blocks for kids.',
      price: 499, discountedPrice: null, unit: '1 set', brand: 'PlayZon',
      rating: 4.2, reviewCount: 64, physicalStock: 0, reservedStock: 0, lowStockThreshold: 5,
      isFeatured: false, isAvailable: false, tags: ['toys', 'kids'],
      image: 'https://images.unsplash.com/photo-1587654780291-39c9404d746b',
    },
  ];

  const catalog = {};
  const productBatch = db.batch();
  for (const p of products) {
    const available = p.physicalStock - p.reservedStock;
    catalog[p.id] = { ...p, available };
    productBatch.set(db.collection('products').doc(p.id), {
      id: p.id,
      name: p.name,
      description: p.description,
      price: p.price,
      discountedPrice: p.discountedPrice ?? null,
      unit: p.unit,
      category: p.category,
      brand: p.brand,
      rating: p.rating,
      reviewCount: p.reviewCount,
      imageUrl: p.image + '?auto=format&fit=crop&w=600&q=70',
      imageUrls: [p.image + '?auto=format&fit=crop&w=600&q=70', p.image + '?auto=format&fit=crop&w=900&q=70'],
      // The stock triple. availableStock is what the UI shows and what
      // placeOrder checks; stock mirrors availableStock for legacy readers.
      stock: available,
      physicalStock: p.physicalStock,
      reservedStock: p.reservedStock,
      availableStock: available,
      lowStockThreshold: p.lowStockThreshold,
      isAvailable: p.isAvailable !== false,
      isFeatured: !!p.isFeatured,
      requiresPrescription: false,
      tags: p.tags,
      createdAt: daysAgo(14),
      updatedAt: Timestamp.now(),
    });
  }
  await productBatch.commit();
  ok('products — ' + products.length + ' items across ' + CATEGORIES.length + ' categories');

  // ── 6. Orders across the full lifecycle ──────────────────────────────────
  // Order fields match exactly what placeOrder writes, so a seeded order is
  // indistinguishable from a real one for every reader (customer history,
  // rider task list, admin dashboard) and for the onOrderWritten trigger.
  const FREE_DELIVERY_ABOVE = 199.0;
  const DELIVERY_FEE = 20.0;

  function buildOrder({
    id, customerId, customerName, customerPhone, village, address, lat, lng,
    lines, status, createdAt, deliveryBoyId = null, deliveryBoyName = null,
    deliveryBoyPhone = null, rating = null, ratingComment = null,
    deliveredAt = null, instructions = null, otp = null, notifyTier = 0,
    cancelledBy = null, cancelReason = null, stockReleased = null,
  }) {
    const items = lines.map((l) => {
      const p = catalog[l.id];
      return { productId: p.id, name: p.name, price: p.price, quantity: l.qty };
    });
    const subtotal = items.reduce((s, i) => s + i.price * i.quantity, 0);
    const deliveryFee = subtotal > FREE_DELIVERY_ABOVE ? 0 : DELIVERY_FEE;
    return {
      doc: {
        customerId,
        customerName,
        customerPhone,
        deliveryAddress: address,
        deliveryInstructions: instructions ?? null,
        village,
        latitude: lat,
        longitude: lng,
        items,
        subtotal,
        deliveryFee,
        totalAmount: subtotal + deliveryFee,
        paymentMethod: 'COD',
        status,
        deliveryBoyId,
        deliveryBoyName,
        deliveryBoyPhone,
        notifyTier,
        ...(stockReleased !== null ? { stockReleased } : {}),
        ...(deliveredAt ? { deliveredAt } : {}),
        ...(rating ? { rating, ratingComment, ratedAt: deliveredAt ?? createdAt } : {}),
        ...(cancelReason ? { cancelReason, cancelledBy } : {}),
        createdAt,
        updatedAt: createdAt,
      },
      id,
      otp,
    };
  }

  const orders = [
    // Customer 1 — a completed COD order, already rated. Gives the order
    // history screen and the admin revenue tile real numbers.
    buildOrder({
      id: 'order_seed_delivered_1', customerId: customerUid,
      customerName: 'Test Customer', customerPhone: '9988776655',
      village: 'Bhimavaram', address: 'Flat 401, Sai Residency, Main Road, Bhimavaram',
      lat: 16.5455, lng: 81.5218,
      lines: [{ id: 'prod_apples_red', qty: 2 }, { id: 'prod_milk_toned', qty: 4 }],
      status: 'delivered', createdAt: daysAgo(6), deliveredAt: daysAgo(6),
      deliveryBoyId: riderUid, deliveryBoyName: 'Speedy Rider', deliveryBoyPhone: '9876543210',
      rating: 5, ratingComment: 'Very fresh apples, delivered ahead of time.',
    }),
    buildOrder({
      id: 'order_seed_delivered_2', customerId: customerUid,
      customerName: 'Test Customer', customerPhone: '9988776655',
      village: 'Bhimavaram', address: 'Flat 401, Sai Residency, Main Road, Bhimavaram',
      lat: 16.5455, lng: 81.5218,
      lines: [{ id: 'prod_atta_5kg', qty: 1 }],
      status: 'delivered', createdAt: daysAgo(3), deliveredAt: daysAgo(3),
      deliveryBoyId: rider2Uid, deliveryBoyName: 'Anitha Delivery', deliveryBoyPhone: '8800112233',
    }),
    // Customer 1 — in flight. This is the one to open on the tracking screen:
    // the OTP sub-document below lets the full rider-delivery handshake be
    // walked end to end without placing a live order.
    buildOrder({
      id: 'order_seed_out_for_delivery', customerId: customerUid,
      customerName: 'Test Customer', customerPhone: '9988776655',
      village: 'Bhimavaram', address: 'Flat 401, Sai Residency, Main Road, Bhimavaram',
      lat: 16.5455, lng: 81.5218,
      lines: [{ id: 'prod_bread_brown', qty: 2 }, { id: 'prod_cola_750', qty: 2 }],
      status: 'out_for_delivery', createdAt: minutesAgo(22),
      deliveryBoyId: riderUid, deliveryBoyName: 'Speedy Rider', deliveryBoyPhone: '9876543210',
      instructions: 'Please call on arrival, gate is locked after 9pm.',
      otp: '4321',
    }),
    // Customer 1 — cancelled, so the cancel/restock path has history.
    buildOrder({
      id: 'order_seed_cancelled_1', customerId: customerUid,
      customerName: 'Test Customer', customerPhone: '9988776655',
      village: 'Bhimavaram', address: 'Flat 401, Sai Residency, Main Road, Bhimavaram',
      lat: 16.5455, lng: 81.5218,
      lines: [{ id: 'prod_toy_out', qty: 1 }],
      status: 'cancelled', createdAt: daysAgo(2),
      cancelledBy: 'customer', cancelReason: 'Changed my mind about this purchase.',
      stockReleased: true,
    }),
    // Customer 2 — accepted and picked up by the seeded rider, so the rider's
    // "current task" screen has work waiting.
    buildOrder({
      id: 'order_seed_picked_up', customerId: customer2Uid,
      customerName: 'Rahul Verma', customerPhone: '9876501234',
      village: 'Undi', address: 'House 12-4, Market Road, Undi',
      lat: 16.5030, lng: 81.1090,
      lines: [{ id: 'prod_eggs_12', qty: 2 }, { id: 'prod_bananas', qty: 3 }],
      status: 'picked_up', createdAt: minutesAgo(35),
      deliveryBoyId: riderUid, deliveryBoyName: 'Speedy Rider', deliveryBoyPhone: '9876543210',
      otp: '7788',
    }),
    // Two unassigned pending orders — these populate the rider's incoming
    // offers feed, which is what makes the rider persona demoable on its own.
    // `deliveryBoyId: null` is what the feed query filters on.
    buildOrder({
      id: 'order_seed_pending_1', customerId: customer2Uid,
      customerName: 'Rahul Verma', customerPhone: '9876501234',
      village: 'Bhimavaram', address: 'H.No 4-7, Railway Station Road, Bhimavaram',
      lat: 16.5440, lng: 81.5200,
      lines: [{ id: 'prod_oil_sunflower', qty: 1 }, { id: 'prod_detergent', qty: 1 }],
      status: 'pending', createdAt: minutesAgo(3),
    }),
    buildOrder({
      id: 'order_seed_pending_2', customerId: customerUid,
      customerName: 'Test Customer', customerPhone: '9988776655',
      village: 'Srungavruksham', address: 'Plot 22, New Colony, Srungavruksham',
      lat: 16.5015, lng: 81.5492,
      lines: [{ id: 'prod_chips_classic', qty: 3 }, { id: 'prod_toothpaste', qty: 1 }, { id: 'prod_soap_dove', qty: 1 }],
      status: 'pending', createdAt: minutesAgo(1),
    }),
  ];

  // Sub-collection writes (delivery OTP) must not share a batch with the order
  // docs — Firestore requires all writes in a batch to be in the same document
  // tree depth, so this uses a second batch after the first has committed.
  const orderBatch = db.batch();
  for (const o of orders) {
    orderBatch.set(db.collection('orders').doc(o.id), o.doc);
  }
  await orderBatch.commit();
  ok('orders — ' + orders.length + ' across pending → assigned → picked_up → out_for_delivery → delivered → cancelled');

  const otpBatch = db.batch();
  for (const o of orders) {
    if (!o.otp) continue;
    otpBatch.set(db.collection('orders').doc(o.id).collection('private').doc('delivery'), {
      otp: o.otp,
      attempts: 0,
      createdAt: o.doc.createdAt,
    });
  }
  await otpBatch.commit();
  ok('orders/*/private/delivery — OTP for ' + orders.filter((o) => o.otp).length + ' in-flight order(s)');

  // ── 7. Inventory ledger ──────────────────────────────────────────────────
  const inventoryLogs = [
    { id: 'invlog_seed_1', productId: 'prod_apples_red', changeType: 'restock', physicalDelta: 60, reservedDelta: 0, notes: 'Opening stock — morning delivery from Himachal' },
    { id: 'invlog_seed_2', productId: 'prod_sugar_1kg', changeType: 'correction', physicalDelta: -14, reservedDelta: 0, notes: 'Damaged units written off after shelf audit' },
    { id: 'invlog_seed_3', productId: 'prod_toy_out', changeType: 'correction', physicalDelta: -20, reservedDelta: 0, notes: 'Seasonal item pulled from shelf, stock zeroed' },
  ];
  const logBatch = db.batch();
  for (const l of inventoryLogs) {
    logBatch.set(db.collection('inventoryLogs').doc(l.id), {
      productId: l.productId,
      adminId: adminUid,
      actorType: 'admin',
      changeType: l.changeType,
      physicalDelta: l.physicalDelta,
      reservedDelta: l.reservedDelta,
      notes: l.notes,
      timestamp: hoursAgo(12),
    });
  }
  await logBatch.commit();
  ok('inventoryLogs — ' + inventoryLogs.length + ' ledger entries');

  // ── 8. Support tickets ───────────────────────────────────────────────────
  const ticketBatch = db.batch();
  ticketBatch.set(db.collection('supportTickets').doc('ticket_seed_1'), {
    customerId: customerUid,
    customerName: 'Test Customer',
    subject: 'Damaged apples in my last order',
    category: 'order_issue',
    status: 'open',
    priority: 'medium',
    createdAt: daysAgo(1),
    updatedAt: hoursAgo(5),
  });
  ticketBatch.set(db.collection('supportTickets').doc('ticket_seed_1').collection('messages').doc('msg_seed_1'), {
    senderId: customerUid,
    senderRole: 'customer',
    text: 'Two of the apples in order #A1B2C3 were bruised. Requesting a replacement or refund on delivery.',
    createdAt: daysAgo(1),
  });
  await ticketBatch.commit();
  ok('supportTickets — 1 ticket with 1 message');

  // ── 9. Dashboard stats (written LAST) ────────────────────────────────────
  // onOrderWritten already incremented activeOrdersCount per seeded order;
  // overwriting here makes the admin dashboard agree with the seeded data
  // instead of drifting every time the seed is re-run.
  const active = orders.filter((o) => o.doc.status !== 'delivered' && o.doc.status !== 'cancelled');
  const revenue = orders
    .filter((o) => o.doc.status === 'delivered')
    .reduce((s, o) => s + o.doc.totalAmount, 0);
  const onDutyRiders = riderDocs.filter((r) => r.onDuty).length;

  await db.collection('config').doc('dashboard_stats').set(
    {
      activeOrdersCount: active.length,
      activeRidersCount: onDutyRiders,
      completedRevenue: revenue,
      productCount: products.length,
      lastUpdated: Timestamp.now(),
    },
    { merge: true },
  );
  ok(`config/dashboard_stats — ${active.length} active, ${onDutyRiders} riders on duty, Rs.${revenue} revenue, ${products.length} products`);

  // ── 10. Done ─────────────────────────────────────────────────────────────
  const completed = orders.filter((o) => o.doc.status === 'delivered').length;
  const firstCustomer = customerDocs[0];
  const customerSpent = orders
    .filter((o) => o.doc.customerId === firstCustomer.uid && o.doc.status === 'delivered')
    .reduce((s, o) => s + o.doc.totalAmount, 0);

  await db.collection('users').doc(firstCustomer.uid).set(
    { totalOrders: completed, totalSpent: customerSpent, firstOrderCompleted: completed > 0 },
    { merge: true },
  );

  console.log('\n\u{1F389} Seeding complete. Log in with any of these (password: ' + PASSWORD + '):');
  console.log('   Customer  customer@jcmart.com   (Bhimavaram, 2 delivered + 1 in flight + 1 pending)');
  console.log('   Customer  customer2@jcmart.com  (Undi, 1 picked up + 1 pending)');
  console.log('   Rider     rider@jcmart.com     (on duty, 2 active tasks, 1 unclaimed offer)');
  console.log('   Rider     rider2@jcmart.com    (off duty)');
  console.log('   Admin     admin@jcmart.com     (dashboard, catalog, riders, support)\n');
  console.log('   In-flight delivery OTPs: order_seed_out_for_delivery = 4321, order_seed_picked_up = 7788');
  console.log('   Emulator UI: http://localhost:4000\n');
}

seed()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('\n\u274C Seeding failed:', err);
    process.exit(1);
  });
