const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Try loading CLI credentials if available
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
    }
  }
} catch (e) {
  // Ignore configstore loading error; will fallback to default credentials
}

// Initialize Firebase Admin SDK
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
  console.error('CRITICAL ERROR:', err);
  process.exit(1);
});

const db = admin.firestore();
const auth = admin.auth();

async function seedAdminData() {
  // Admin details
  const adminEmail = process.env.ADMIN_EMAIL || 'admin@hypermart.com';
  const adminPassword = process.env.ADMIN_PASSWORD;
  const adminName = process.env.ADMIN_NAME || 'HyperMart Admin';
  const adminPhone = process.env.ADMIN_PHONE || '9999999999';

  if (!adminPassword || adminPassword.length < 8) {
    console.error('ERROR: Set ADMIN_PASSWORD (>= 8 chars) in the environment before running this script.');
    console.error('This script provisions/updates a real admin account against the live Firebase project.');
    process.exit(1);
  }
  const village = 'Bhimavaram';
  const mandal = 'Bhimavaram';
  const district = 'West Godavari';

  console.log('----------------------------------------------------');
  console.log('🚀 Starting HyperMart Admin Seeding Process...');
  console.log(`Email: ${adminEmail}`);
  console.log('----------------------------------------------------');

  let userRecord;
  try {
    // 1. Check or Create Firebase Auth User
    try {
      userRecord = await auth.getUserByEmail(adminEmail);
      console.log(`[AUTH] Existing Firebase Auth user found with UID: ${userRecord.uid}`);
      
      // Update password and display name to ensure consistency
      await auth.updateUser(userRecord.uid, {
        password: adminPassword,
        displayName: adminName,
      });
      console.log(`[AUTH] Admin credentials updated successfully.`);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.log(`[AUTH] Admin user not found. Creating new Firebase Auth user...`);
        userRecord = await auth.createUser({
          email: adminEmail,
          password: adminPassword,
          displayName: adminName,
        });
        console.log(`[AUTH] Created Firebase Auth user with UID: ${userRecord.uid}`);
      } else {
        throw error;
      }
    }

    const uid = userRecord.uid;

    // 2. Set Custom Auth Claim: admin = true
    console.log(`[AUTH CLAIMS] Setting custom claim 'admin: true' for UID: ${uid}...`);
    await auth.setCustomUserClaims(uid, { admin: true });

    const now = admin.firestore.FieldValue.serverTimestamp();

    // 3. Seed /users/{uid} document with full fields
    console.log(`[FIRESTORE] Seeding /users/${uid} document...`);
    const userDocData = {
      uid: uid,
      name: adminName,
      email: adminEmail,
      phone: adminPhone,
      role: 'admin',
      isActive: true,
      onboardingCompleted: true,
      onboardingStep: 3,
      village: village,
      mandal: mandal,
      district: district,
      deliveryAvailable: true,
      deliveryZoneId: 'ZONE_BHIMAVARAM',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      notificationsEnabled: true,
      totalOrders: 0,
      totalSpent: 0.0,
      firstOrderCompleted: false,
      favoriteProductIds: [],
      fcmTokens: [],
      createdAt: now,
      updatedAt: now,
      addresses: [
        {
          id: 'admin_addr_01',
          name: adminName,
          addressLine1: 'Main Store Headquarters, Station Road',
          addressLine2: 'Near Bus Stand',
          pinCode: '534201',
          pincode: '534201',
          village: village,
          mandal: mandal,
          district: district,
          landmark: 'Central Tower',
          latitude: 16.5449,
          longitude: 81.5212,
          isDefault: true
        }
      ]
    };
    await db.collection('users').doc(uid).set(userDocData, { merge: true });

    // 4. Seed /admins/{uid} whitelist document
    console.log(`[FIRESTORE] Whitelisting UID in /admins/${uid}...`);
    const adminDocData = {
      uid: uid,
      email: adminEmail,
      name: adminName,
      role: 'admin',
      isSuperAdmin: true,
      createdAt: now,
      updatedAt: now
    };
    await db.collection('admins').doc(uid).set(adminDocData, { merge: true });

    console.log('----------------------------------------------------');
    console.log('✅ SUCCESS: Admin credentials and full profile seeded successfully!');
    console.log('----------------------------------------------------');
    console.log(`Email    : ${adminEmail}`);
    console.log(`UID      : ${uid}`);
    console.log(`Role     : admin`);
    console.log('----------------------------------------------------');

  } catch (error) {
    console.error('----------------------------------------------------');
    console.error('❌ ERROR: Seeding admin credentials failed!');
    console.error(error);
    console.error('----------------------------------------------------');
    process.exit(1);
  }
}

seedAdminData();
