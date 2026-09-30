import http from 'http';

const PROJECT_ID = 'demo-hypermart';
const AUTH_HOST = '127.0.0.1';
const AUTH_PORT = 9099;
const FIRESTORE_HOST = '127.0.0.1';
const FIRESTORE_PORT = 8090;

export class FirebaseEmulatorHelper {
  private static httpRequest(options: http.RequestOptions, postData?: string): Promise<{ statusCode?: number; body: string }> {
    return new Promise((resolve, reject) => {
      const req = http.request(options, (res) => {
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => resolve({ statusCode: res.statusCode, body }));
      });
      req.on('error', (err) => reject(err));
      if (postData) {
        req.write(postData);
      }
      req.end();
    });
  }

  static async checkEmulatorsRunning(): Promise<boolean> {
    try {
      const res = await this.httpRequest({
        host: FIRESTORE_HOST,
        port: FIRESTORE_PORT,
        path: '/',
        method: 'GET',
      });
      return res.statusCode === 200;
    } catch {
      try {
        const authRes = await this.httpRequest({
          host: AUTH_HOST,
          port: AUTH_PORT,
          path: '/',
          method: 'GET',
        });
        return true;
      } catch {
        return false;
      }
    }
  }

  static async resetEmulatorData(): Promise<void> {
    // 1. Clear Auth Emulator
    try {
      await this.httpRequest({
        host: AUTH_HOST,
        port: AUTH_PORT,
        path: `/emulator/v1/projects/${PROJECT_ID}/accounts`,
        method: 'DELETE',
      });
    } catch (e) {
      console.warn('Failed to clear Auth emulator:', e);
    }

    // 2. Clear Firestore Emulator
    try {
      await this.httpRequest({
        host: FIRESTORE_HOST,
        port: FIRESTORE_PORT,
        path: `/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
        method: 'DELETE',
      });
    } catch (e) {
      console.warn('Failed to clear Firestore emulator:', e);
    }
  }

  static async createAuthUser(email: string, password: string): Promise<string> {
    try {
      const data = JSON.stringify({ email, password, returnSecureToken: true });
      const res = await this.httpRequest(
        {
          host: AUTH_HOST,
          port: AUTH_PORT,
          path: '/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(data),
          },
        },
        data
      );
      if (res.statusCode === 200) {
        const parsed = JSON.parse(res.body);
        return parsed.localId || '';
      }

      // If user exists, fetch exact localId via signInWithPassword
      const signInRes = await this.httpRequest(
        {
          host: AUTH_HOST,
          port: AUTH_PORT,
          path: '/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(data),
          },
        },
        data
      );
      if (signInRes.statusCode === 200) {
        const parsed = JSON.parse(signInRes.body);
        return parsed.localId || '';
      }
    } catch (e: any) {
      console.warn(`Auth emulator create user error: ${e?.message || e}`);
    }
    return '';
  }

  static async setAdminCustomClaim(uid: string): Promise<void> {
    try {
      const data = JSON.stringify({ customAttributes: JSON.stringify({ admin: true }) });
      await this.httpRequest(
        {
          host: AUTH_HOST,
          port: AUTH_PORT,
          path: `/emulator/v1/projects/${PROJECT_ID}/accounts/${uid}`,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(data),
          },
        },
        data
      );
    } catch (e) {
      console.error(`Failed to set admin custom claim for ${uid}:`, e);
    }
  }

  static async setFirestoreDocument(collection: string, docId: string, data: Record<string, any>): Promise<void> {
    const fields: Record<string, any> = {};
    for (const [key, value] of Object.entries(data)) {
      if (typeof value === 'string') {
        fields[key] = { stringValue: value };
      } else if (typeof value === 'number') {
        fields[key] = Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
      } else if (typeof value === 'boolean') {
        fields[key] = { booleanValue: value };
      } else if (value instanceof Date) {
        fields[key] = { timestampValue: value.toISOString() };
      } else if (Array.isArray(value)) {
        fields[key] = {
          arrayValue: {
            values: value.map((v) => ({ stringValue: String(v) })),
          },
        };
      } else if (typeof value === 'object' && value !== null) {
        fields[key] = { mapValue: { fields: this._mapToFirestoreFields(value) } };
      }
    }

    const payload = JSON.stringify({ fields });
    try {
      await this.httpRequest(
        {
          host: FIRESTORE_HOST,
          port: FIRESTORE_PORT,
          path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}`,
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer owner',
            'Content-Length': Buffer.byteLength(payload),
          },
        },
        payload
      );
    } catch (e) {
      console.error(`Failed to set document ${collection}/${docId}:`, e);
    }
  }

  private static _mapToFirestoreFields(obj: Record<string, any>): Record<string, any> {
    const fields: Record<string, any> = {};
    for (const [k, v] of Object.entries(obj)) {
      if (typeof v === 'string') fields[k] = { stringValue: v };
      else if (typeof v === 'number') fields[k] = { doubleValue: v };
      else if (typeof v === 'boolean') fields[k] = { booleanValue: v };
    }
    return fields;
  }

  static async seedFullTestEnvironment(): Promise<void> {
    await this.resetEmulatorData();

    // 1. Seed Config
    await this.setFirestoreDocument('config', 'app', {
      storeOpen: true,
      minOrderAmount: 0,
      serviceableVillages: ['Bhimavaram', 'Palakollu', 'Tadepalligudem'],
    });

    // 2. Seed Customer
    const customerUid = await this.createAuthUser('customer@jcmart.com', 'Password123!');
    await this.setFirestoreDocument('users', customerUid, {
      uid: customerUid,
      docId: customerUid,
      name: 'Test Customer',
      email: 'customer@jcmart.com',
      phone: '9988776655',
      village: 'Bhimavaram',
      addressDetails: 'Flat 401, Main Road',
      role: 'customer',
      isActive: true,
      onboardingCompleted: true,
      onboardingStep: 3,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    // 3. Seed Deactivated Customer
    const deactCustomerUid = await this.createAuthUser('deactivated@jcmart.com', 'Password123!');
    await this.setFirestoreDocument('users', deactCustomerUid, {
      uid: deactCustomerUid,
      docId: deactCustomerUid,
      name: 'Blocked User',
      email: 'deactivated@jcmart.com',
      phone: '9000000000',
      role: 'customer',
      isActive: false,
      onboardingCompleted: true,
    });

    // 4. Seed Delivery Rider
    const riderUid = await this.createAuthUser('rider@jcmart.com', 'Password123!');
    await this.setFirestoreDocument('deliveryBoys', riderUid, {
      uid: riderUid,
      docId: riderUid,
      name: 'Speedy Rider',
      email: 'rider@jcmart.com',
      phone: '9876543210',
      village: 'Bhimavaram',
      role: 'delivery',
      isActive: true,
      onDuty: true,
      currentLatitude: 16.5449,
      currentLongitude: 81.5212,
      createdAt: new Date(),
    });

    // 5. Seed Admin
    const adminUid = await this.createAuthUser('admin@jcmart.com', 'Password123!');
    await this.setAdminCustomClaim(adminUid);
    await this.setFirestoreDocument('admins', adminUid, {
      uid: adminUid,
      docId: adminUid,
      name: 'Store Manager',
      email: 'admin@jcmart.com',
      phone: '9111122222',
      role: 'admin',
      isActive: true,
      createdAt: new Date(),
    });

    // 6. Seed Products
    await this.setFirestoreDocument('products', 'prod_apple_01', {
      id: 'prod_apple_01',
      name: 'Fresh Red Apples',
      description: 'Crisp and organic apples from local orchards.',
      price: 120.0,
      unit: '1 kg',
      category: 'Fruits & Vegetables',
      stock: 50,
      physicalStock: 50,
      reservedStock: 0,
      availableStock: 50,
      lowStockThreshold: 10,
      requiresPrescription: false,
      imageUrl: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6',
      isActive: true,
    });

    await this.setFirestoreDocument('products', 'prod_banana_02', {
      id: 'prod_banana_02',
      name: 'Organic Bananas',
      description: 'Fresh Cavendish organic bananas.',
      price: 50.0,
      unit: '1 doz',
      category: 'Fruits & Vegetables',
      stock: 30,
      physicalStock: 30,
      reservedStock: 0,
      availableStock: 30,
      lowStockThreshold: 5,
      requiresPrescription: false,
      imageUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e',
      isActive: true,
    });

    await this.setFirestoreDocument('products', 'prod_milk_03', {
      id: 'prod_milk_03',
      name: 'Pure Cow Milk',
      description: 'Pasteurized full-cream farm fresh cow milk.',
      price: 60.0,
      unit: '1 L',
      category: 'Dairy & Eggs',
      stock: 20,
      physicalStock: 20,
      reservedStock: 0,
      availableStock: 20,
      lowStockThreshold: 5,
      requiresPrescription: false,
      imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150',
      isActive: true,
    });

    await this.setFirestoreDocument('products', 'prod_outofstock_04', {
      id: 'prod_outofstock_04',
      name: 'Rare Organic Honey',
      description: 'Pure wild forest honey.',
      price: 450.0,
      unit: '500 g',
      category: 'Pantry',
      stock: 0,
      physicalStock: 0,
      reservedStock: 0,
      availableStock: 0,
      lowStockThreshold: 5,
      requiresPrescription: false,
      imageUrl: 'https://images.unsplash.com/photo-1587049352847-4a222e784d38',
      isActive: true,
    });
  }
}
