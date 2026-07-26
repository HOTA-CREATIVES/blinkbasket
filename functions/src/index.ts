import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";
import { createHash } from "crypto";

initializeApp();
const db = getFirestore();

// Cloudinary secret lives in Secret Manager, never in source or the client
// binary. Set with: firebase functions:secrets:set CLOUDINARY_API_SECRET
const cloudinaryApiSecret = defineSecret("CLOUDINARY_API_SECRET");
const CLOUDINARY_CLOUD_NAME = "diiyy6bar";
const CLOUDINARY_API_KEY = "446958312948211";
const CLOUDINARY_UPLOAD_FOLDER = "products";

// Mumbai region — closest to the Bhimavaram service area.
const REGION = "asia-south1";

const MAX_ITEMS_PER_ORDER = 50;
const MAX_QTY_PER_ITEM = 99;
const MAX_OTP_ATTEMPTS = 5;

// Blinkit-style rider auto-broadcast: tier-1 (village-matched on-duty riders)
// escalates to tier-2 (all on-duty riders) after this many seconds with no
// acceptance, and tier-2 itself is then re-broadcast ("retried forever") on
// this same cadence by the escalateStaleOrders scheduled function — there is
// no admin manual-assign fallback, so this must never give up.
const BROADCAST_RETRY_SECONDS = 90;
const ESCALATOR_BATCH_LIMIT = 200;

interface OrderItemInput {
  productId: string;
  quantity: number;
}

// Mirrors lib/core/data/villages.dart. Cloud Functions can't import from the
// Flutter package, so this is a deliberate second copy of the single Dart
// source of truth — update both together if the service area changes.
const VILLAGES: { name: string; latitude: number; longitude: number }[] = [
  { name: "Bhimavaram", latitude: 16.5449, longitude: 81.5212 },
  { name: "Veeravasaram", latitude: 16.5050, longitude: 81.6062 },
  { name: "Rayakuduru", latitude: 16.5861, longitude: 81.5034 },
  { name: "Srungavruksham", latitude: 16.5015, longitude: 81.5492 },
  { name: "Mentada", latitude: 16.6341, longitude: 81.6500 },
];

// Generous buffer around the nearest village centroid — tune as the real
// service-area boundary becomes better known. Centroids-only data means this
// is an approximation, not a precise polygon.
const SERVICE_RADIUS_METERS = 12_000;

function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function distanceToNearestVillageMeters(lat: number, lng: number): number {
  let min = Infinity;
  for (const v of VILLAGES) {
    const d = haversineMeters(lat, lng, v.latitude, v.longitude);
    if (d < min) min = d;
  }
  return min;
}

async function getFcmTokens(collection: "users" | "deliveryBoys", uid: string): Promise<string[]> {
  const snap = await db.collection(collection).doc(uid).get();
  if (!snap.exists) return [];
  const tokens = snap.data()?.fcmTokens;
  return Array.isArray(tokens) ? tokens.filter((t): t is string => typeof t === "string") : [];
}

const DEAD_TOKEN_ERROR_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

/** Maps every fcmToken in a set of rider/user docs back to its owning doc,
 * so a dead token can be removed from the right place after a send. */
function tokenOwnersFromDocs(
  docs: FirebaseFirestore.QueryDocumentSnapshot[]
): Map<string, FirebaseFirestore.DocumentReference> {
  const owners = new Map<string, FirebaseFirestore.DocumentReference>();
  for (const doc of docs) {
    const tokens = doc.data().fcmTokens;
    if (!Array.isArray(tokens)) continue;
    for (const token of tokens) {
      if (typeof token === "string") owners.set(token, doc.ref);
    }
  }
  return owners;
}

/** Removes tokens FCM reports as permanently dead (app uninstalled / stale
 * registration) from their owning doc's fcmTokens array, so that array
 * doesn't grow unbounded with tokens that can never succeed again. */
async function pruneDeadTokens(
  tokens: string[],
  responses: { success: boolean; error?: { code: string } }[],
  tokenOwners: Map<string, FirebaseFirestore.DocumentReference>
): Promise<void> {
  const deadByDoc = new Map<string, string[]>();
  responses.forEach((res, i) => {
    if (res.success || !res.error || !DEAD_TOKEN_ERROR_CODES.has(res.error.code)) return;
    const docRef = tokenOwners.get(tokens[i]);
    if (!docRef) return;
    const existing = deadByDoc.get(docRef.path) ?? [];
    existing.push(tokens[i]);
    deadByDoc.set(docRef.path, existing);
  });

  await Promise.all(
    Array.from(deadByDoc.entries()).map(([path, deadTokens]) =>
      db.doc(path)
        .update({ fcmTokens: FieldValue.arrayRemove(...deadTokens) })
        .catch((e) => console.error(`Failed to prune dead tokens from ${path}:`, e))
    )
  );
}

/**
 * Best-effort push send — a messaging failure must never break the
 * Firestore trigger logic (stats aggregation, stock release, etc.) that
 * calls this. When `tokenOwners` is supplied, also prunes any token FCM
 * reports as permanently dead from its owning doc.
 */
async function sendPushToTokens(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string> = {},
  tokenOwners?: Map<string, FirebaseFirestore.DocumentReference>
): Promise<void> {
  if (tokens.length === 0) return;
  try {
    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data,
    });
    if (tokenOwners) {
      await pruneDeadTokens(tokens, response.responses, tokenOwners);
    }
  } catch (e) {
    console.error("sendPushToTokens failed:", e);
  }
}

/**
 * Broadcasts a freshly-placed order to on-duty riders — the Blinkit-style
 * replacement for manual admin assignment. Tier 1 is on-duty, active riders
 * whitelisted for the order's village (the same "nearest" proxy the old
 * manual-assign sheet used, since there's no live rider GPS); if that pool
 * is empty, falls through to tier 2 (every on-duty, active rider) right
 * away rather than waiting out a timeout with nobody to notify.
 *
 * Visibility of the order itself is NOT tier-gated (see firestore.rules —
 * any on-duty rider can already read/accept a pending, unassigned order);
 * only the urgency of who gets pushed first is. `notifyTier`/`notifiedAt`
 * are written so escalateStaleOrders can widen tier 1 → 2, and keep
 * re-broadcasting tier 2 forever, if nobody accepts in time.
 */
async function broadcastNewOrder(orderId: string, order: FirebaseFirestore.DocumentData): Promise<void> {
  const village = String(order.village ?? "");

  let tier = 1;
  let candidates = await db.collection("deliveryBoys")
    .where("isActive", "==", true)
    .where("onDuty", "==", true)
    .where("village", "==", village)
    .get();

  if (candidates.empty) {
    tier = 2;
    candidates = await db.collection("deliveryBoys")
      .where("isActive", "==", true)
      .where("onDuty", "==", true)
      .get();
  }

  const tokenOwners = tokenOwnersFromDocs(candidates.docs);
  const tokens = Array.from(tokenOwners.keys());

  await sendPushToTokens(
    tokens,
    "New delivery nearby",
    `New order from ${order.customerName ?? "a customer"} in ${village}. Tap to accept.`,
    { orderId, type: "new_order_offer" },
    tokenOwners
  );

  await db.collection("orders").doc(orderId).set(
    { notifyTier: tier, notifiedAt: Timestamp.now() },
    { merge: true }
  );
}

/**
 * Places a COD order for the authenticated customer.
 *
 * The client sends only product IDs, quantities, and a street address.
 * Prices, delivery fee, totals, and customer identity are resolved
 * server-side; stock is checked and decremented inside a transaction.
 * The 4-digit delivery OTP is written to orders/{id}/private/delivery,
 * which security rules expose to the ordering customer only.
 */
export const placeOrder = onCall({ region: REGION, enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to place an order.");
  }

  const items = request.data?.items as OrderItemInput[] | undefined;
  const deliveryAddress = String(request.data?.deliveryAddress ?? "").trim();
  const latitude = request.data?.latitude !== undefined ? Number(request.data.latitude) : null;
  const longitude = request.data?.longitude !== undefined ? Number(request.data.longitude) : null;

  if (!Array.isArray(items) || items.length === 0) {
    throw new HttpsError("invalid-argument", "Your cart is empty.");
  }
  if (items.length > MAX_ITEMS_PER_ORDER) {
    throw new HttpsError("invalid-argument", "Too many distinct items in one order.");
  }
  if (!deliveryAddress || deliveryAddress.length > 500) {
    throw new HttpsError("invalid-argument", "A valid delivery address is required.");
  }
  if (latitude === null || longitude === null || Number.isNaN(latitude) || Number.isNaN(longitude)) {
    throw new HttpsError(
      "invalid-argument",
      "A delivery location (GPS coordinates) is required to place an order."
    );
  }
  if (distanceToNearestVillageMeters(latitude, longitude) > SERVICE_RADIUS_METERS) {
    throw new HttpsError(
      "failed-precondition",
      "This delivery address is outside our service area."
    );
  }
  const seen = new Set<string>();
  for (const item of items) {
    if (
      typeof item?.productId !== "string" ||
      item.productId.length === 0 ||
      !Number.isInteger(item?.quantity) ||
      item.quantity <= 0 ||
      item.quantity > MAX_QTY_PER_ITEM
    ) {
      throw new HttpsError("invalid-argument", "Invalid order item.");
    }
    if (seen.has(item.productId)) {
      throw new HttpsError("invalid-argument", "Duplicate product in order.");
    }
    seen.add(item.productId);
  }

  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) {
    throw new HttpsError("failed-precondition", "Complete your profile before ordering.");
  }
  const user = userSnap.data() as FirebaseFirestore.DocumentData;
  if (user.isActive === false) {
    throw new HttpsError("permission-denied", "Your account is deactivated. Contact support.");
  }

  const configSnap = await db.collection("config").doc("app").get();
  const config = configSnap.exists ? (configSnap.data() as FirebaseFirestore.DocumentData) : {};
  if (config.storeOpen === false) {
    throw new HttpsError("failed-precondition", "The store is currently closed. Please try later.");
  }
  const deliveryFeeConfig = Number(config.deliveryFee ?? 30);
  const freeDeliveryAbove = Number(config.freeDeliveryAbove ?? 300);

  const otp = String(Math.floor(1000 + Math.random() * 9000));
  const orderRef = db.collection("orders").doc();

  const totals = await db.runTransaction(async (tx) => {
    const productRefs = items.map((item) => db.collection("products").doc(item.productId));
    const productSnaps = await tx.getAll(...productRefs);

    let subtotal = 0;
    const orderItems = items.map((item, i) => {
      const snap = productSnaps[i];
      if (!snap.exists) {
        throw new HttpsError("not-found", "One of the products is no longer available.");
      }
      const product = snap.data() as FirebaseFirestore.DocumentData;
      const stockVal = Number(product.stock ?? 0);
      const physicalStock = Number(product.physicalStock ?? stockVal);
      const reservedStock = Number(product.reservedStock ?? 0);
      const availableStock = Number(product.availableStock ?? (physicalStock - reservedStock));

      if (availableStock < item.quantity) {
        throw new HttpsError(
          "failed-precondition",
          `"${product.name}" has only ${availableStock} units available for purchase.`
        );
      }
      const price = Number(product.price ?? 0);
      subtotal += price * item.quantity;

      const newReserved = reservedStock + item.quantity;
      const newAvailable = availableStock - item.quantity;

      tx.update(snap.ref, {
        reservedStock: newReserved,
        availableStock: newAvailable,
        stock: newAvailable, // Fallback field in sync with availableStock
        updatedAt: Timestamp.now()
      });

      // Write inventory ledger log for this reservation
      const ledgerRef = db.collection("inventoryLogs").doc();
      tx.set(ledgerRef, {
        productId: snap.id,
        adminId: uid,
        changeType: "reserve",
        physicalDelta: 0,
        reservedDelta: item.quantity,
        notes: "Stock reserved on order placement",
        timestamp: Timestamp.now()
      });

      return {
        productId: snap.id,
        name: String(product.name ?? ""),
        price,
        quantity: item.quantity,
      };
    });

    const deliveryFee = subtotal > freeDeliveryAbove ? 0 : deliveryFeeConfig;
    const totalAmount = subtotal + deliveryFee;
    const now = Timestamp.now();

    tx.set(orderRef, {
      customerId: uid,
      customerName: String(user.name ?? ""),
      customerPhone: String(user.phone ?? ""),
      deliveryAddress,
      village: String(user.village ?? ""),
      latitude,
      longitude,
      items: orderItems,
      subtotal,
      deliveryFee,
      totalAmount,
      paymentMethod: "COD",
      status: "pending",
      deliveryBoyId: null,
      deliveryBoyName: null,
      createdAt: now,
      updatedAt: now,
    });
    tx.set(orderRef.collection("private").doc("delivery"), {
      otp,
      attempts: 0,
      createdAt: now,
    });

    return { subtotal, deliveryFee, totalAmount };
  });

  return {
    orderId: orderRef.id,
    otp,
    subtotal: totals.subtotal,
    deliveryFee: totals.deliveryFee,
    totalAmount: totals.totalAmount,
  };
});

/**
 * Verifies the customer's delivery OTP and marks the order delivered.
 * Callable only by the rider the order is assigned to, only while the
 * order is out for delivery, with a capped number of attempts.
 */
export const verifyDeliveryOtp = onCall({ region: REGION, enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }

  const orderId = String(request.data?.orderId ?? "");
  const otp = String(request.data?.otp ?? "").trim();
  if (!orderId || !/^\d{4}$/.test(otp)) {
    throw new HttpsError("invalid-argument", "Order ID and a 4-digit OTP are required.");
  }

  const orderRef = db.collection("orders").doc(orderId);

  // A throw inside the transaction rolls back its writes, so the wrong-OTP
  // attempt counter is committed by returning normally and throwing after.
  const outcome = await db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }
    const order = orderSnap.data() as FirebaseFirestore.DocumentData;
    if (order.deliveryBoyId !== uid) {
      throw new HttpsError("permission-denied", "This order is not assigned to you.");
    }
    if (order.status !== "out_for_delivery") {
      throw new HttpsError("failed-precondition", "Order is not out for delivery.");
    }

    const privateRef = orderRef.collection("private").doc("delivery");
    const privateSnap = await tx.get(privateRef);
    if (!privateSnap.exists) {
      throw new HttpsError("internal", "Delivery verification data missing. Contact admin.");
    }
    const secret = privateSnap.data() as FirebaseFirestore.DocumentData;

    const attempts = Number(secret.attempts ?? 0);
    if (attempts >= MAX_OTP_ATTEMPTS) {
      return "too_many_attempts";
    }

    if (secret.otp !== otp) {
      tx.update(privateRef, { attempts: FieldValue.increment(1) });
      return "wrong_otp";
    }

    // Release stock reservation and decrement physical stock
    const itemsList = (order.items || []) as { productId: string; quantity: number }[];
    if (itemsList.length > 0) {
      const productRefs = itemsList.map(item => db.collection("products").doc(item.productId));
      const productSnaps = await tx.getAll(...productRefs);

      for (let i = 0; i < itemsList.length; i++) {
        const item = itemsList[i];
        const prodSnap = productSnaps[i];
        if (prodSnap.exists) {
          const prod = prodSnap.data() as FirebaseFirestore.DocumentData;
          const stockVal = Number(prod.stock ?? 0);
          const phys = Number(prod.physicalStock ?? stockVal);
          const res = Number(prod.reservedStock ?? 0);
          
          const newPhys = Math.max(0, phys - item.quantity);
          const newRes = Math.max(0, res - item.quantity);
          const newAvail = newPhys - newRes;

          tx.update(prodSnap.ref, {
            physicalStock: newPhys,
            reservedStock: newRes,
            availableStock: newAvail,
            stock: newAvail, // Keep fallback stock in sync
            updatedAt: Timestamp.now()
          });

          // Write inventory ledger log for this sale
          const ledgerRef = db.collection("inventoryLogs").doc();
          tx.set(ledgerRef, {
            productId: item.productId,
            adminId: uid, // Rider UID who verified
            orderId: orderId,
            changeType: "sale",
            physicalDelta: -item.quantity,
            reservedDelta: -item.quantity,
            notes: `Delivered order #${orderId}`,
            timestamp: Timestamp.now()
          });
        }
      }
    }

    tx.update(orderRef, { status: "delivered", updatedAt: Timestamp.now() });
    return "delivered";
  });

  if (outcome === "too_many_attempts") {
    throw new HttpsError(
      "resource-exhausted",
      "Too many incorrect attempts. Ask the admin to confirm this delivery."
    );
  }
  if (outcome === "wrong_otp") {
    throw new HttpsError("permission-denied", "Incorrect delivery OTP.");
  }

  return { success: true };
});

/**
 * Blinkit-style order claim: any on-duty, active rider can accept a pending,
 * unassigned order — first to successfully commit the transaction wins.
 * Replaces the old admin manual-assign flow entirely; there is no other way
 * for `deliveryBoyId` to be set on an order.
 *
 * The transaction's read-then-conditional-write is what makes this safe
 * under concurrent accepts: Firestore serializes conflicting transactions,
 * so a losing caller's retry re-reads the now-updated doc, sees
 * `deliveryBoyId` already set, and returns "taken" deterministically — same
 * pattern as verifyDeliveryOtp's OTP-attempt handling above.
 *
 * No notification/stats logic here on purpose: this write is a
 * pending → assigned transition with a newly-set deliveryBoyId, which
 * onOrderWritten's notifyOnStatusChange (below) already handles for both
 * the customer and rider push, plus the dashboard stats delta.
 */
export const acceptOrder = onCall({ region: REGION, enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  if (request.auth?.token?.delivery !== true) {
    throw new HttpsError("permission-denied", "Only delivery partners can accept orders.");
  }

  const orderId = String(request.data?.orderId ?? "");
  if (!orderId) {
    throw new HttpsError("invalid-argument", "orderId is required.");
  }

  // Defense in depth — don't trust a possibly-stale custom claim for the
  // on-duty/active check, re-read the live rider doc (same pattern as the
  // active-admin checks elsewhere in this file).
  const riderSnap = await db.collection("deliveryBoys").doc(uid).get();
  const rider = riderSnap.exists ? riderSnap.data() as FirebaseFirestore.DocumentData : undefined;
  if (!rider || rider.isActive === false) {
    throw new HttpsError("permission-denied", "Your account is deactivated. Contact support.");
  }
  if (rider.onDuty !== true) {
    throw new HttpsError("failed-precondition", "Go on-duty before accepting orders.");
  }

  const orderRef = db.collection("orders").doc(orderId);
  const outcome = await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }
    const order = snap.data() as FirebaseFirestore.DocumentData;
    if (order.status !== "pending" || order.deliveryBoyId) {
      return "taken";
    }

    tx.update(orderRef, {
      status: "assigned",
      deliveryBoyId: uid,
      deliveryBoyName: String(rider.name ?? ""),
      deliveryBoyPhone: String(rider.phone ?? ""),
      updatedAt: Timestamp.now(),
    });
    return "accepted";
  });

  if (outcome === "taken") {
    throw new HttpsError("failed-precondition", "This order was already accepted by another rider.");
  }
  return { success: true };
});

/**
 * Automatically updates active order count and completed revenue.
 */
export const onOrderWritten = onDocumentWritten({ region: REGION, document: "orders/{orderId}" }, async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  const statsRef = db.collection("config").doc("dashboard_stats");

  // 1. New Order Created (Initial status is 'pending')
  if (!beforeData && afterData) {
    await statsRef.set({
      activeOrdersCount: FieldValue.increment(1),
      lastUpdated: FieldValue.serverTimestamp(),
    }, { merge: true });
    await broadcastNewOrder(event.params.orderId, afterData);
    return;
  }

  // 2. Order Deleted (highly unlikely, but safe-guard)
  if (beforeData && !afterData) {
    const beforeStatus = beforeData.status;
    if (beforeStatus !== "delivered" && beforeStatus !== "cancelled") {
      await statsRef.set({
        activeOrdersCount: FieldValue.increment(-1),
        lastUpdated: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    return;
  }

  // 3. Order Updated
  if (beforeData && afterData) {
    const beforeStatus = beforeData.status;
    const afterStatus = afterData.status;

    if (beforeStatus !== afterStatus) {
      // If transition to cancelled: release reserved stock and log return
      if (afterStatus === "cancelled" && beforeStatus !== "cancelled") {
        const itemsList = (afterData.items || []) as { productId: string; quantity: number }[];
        if (itemsList.length > 0) {
          const productRefs = itemsList.map(item => db.collection("products").doc(item.productId));
          await db.runTransaction(async (tx) => {
            const productSnaps = await tx.getAll(...productRefs);
            for (let i = 0; i < itemsList.length; i++) {
              const item = itemsList[i];
              const prodSnap = productSnaps[i];
              if (prodSnap.exists) {
                const prod = prodSnap.data() as FirebaseFirestore.DocumentData;
                const stockVal = Number(prod.stock ?? 0);
                const phys = Number(prod.physicalStock ?? stockVal);
                const res = Number(prod.reservedStock ?? 0);

                const newRes = Math.max(0, res - item.quantity);
                const newAvail = phys - newRes;

                tx.update(prodSnap.ref, {
                  reservedStock: newRes,
                  availableStock: newAvail,
                  stock: newAvail,
                  updatedAt: Timestamp.now()
                });

                // Write inventory log for the return (cancellation)
                const ledgerRef = db.collection("inventoryLogs").doc();
                tx.set(ledgerRef, {
                  productId: item.productId,
                  adminId: afterData.customerId || "system",
                  orderId: event.params.orderId,
                  changeType: "return",
                  physicalDelta: 0,
                  reservedDelta: -item.quantity,
                  notes: `Order #${event.params.orderId} cancelled; reservation released.`,
                  timestamp: Timestamp.now()
                });
              }
            }
          });
        }
      }

      const wasActive = beforeStatus !== "delivered" && beforeStatus !== "cancelled";
      const isActive = afterStatus !== "delivered" && afterStatus !== "cancelled";

      let activeOrdersDelta = 0;
      let revenueDelta = 0;

      if (wasActive && !isActive) {
        activeOrdersDelta = -1;
      } else if (!wasActive && isActive) {
        activeOrdersDelta = 1;
      }

      if (afterStatus === "delivered" && beforeStatus !== "delivered") {
        revenueDelta = Number(afterData.totalAmount ?? 0);
      } else if (beforeStatus === "delivered" && afterStatus !== "delivered") {
        revenueDelta = -Number(beforeData.totalAmount ?? 0);
      }

      const updates: Record<string, any> = {
        lastUpdated: FieldValue.serverTimestamp(),
      };
      if (activeOrdersDelta !== 0) {
        updates.activeOrdersCount = FieldValue.increment(activeOrdersDelta);
      }
      if (revenueDelta !== 0) {
        updates.completedRevenue = FieldValue.increment(revenueDelta);
      }

      if (Object.keys(updates).length > 1) {
        await statsRef.set(updates, { merge: true });
      }

      await notifyOnStatusChange(event.params.orderId, beforeStatus, afterStatus, afterData);
    }
  }
});

const ORDER_STATUS_MESSAGES: Record<string, string> = {
  assigned: "Your order is confirmed and a rider has been assigned.",
  out_for_delivery: "Your order is on the way!",
  delivered: "Delivered — thanks for ordering with J C Mart!",
  cancelled: "Your order has been cancelled.",
};

/** Pushes a customer-facing status update, and a separate rider-facing
 * notification the moment a rider is first assigned to the order. */
async function notifyOnStatusChange(
  orderId: string,
  beforeStatus: string,
  afterStatus: string,
  afterData: FirebaseFirestore.DocumentData
): Promise<void> {
  const customerMessage = ORDER_STATUS_MESSAGES[afterStatus];
  if (customerMessage && afterData.customerId) {
    const tokens = await getFcmTokens("users", afterData.customerId);
    const customerRef = db.collection("users").doc(afterData.customerId);
    await sendPushToTokens(
      tokens,
      `Order #${orderId.substring(0, 6).toUpperCase()}`,
      customerMessage,
      { orderId, status: afterStatus },
      new Map(tokens.map((t) => [t, customerRef]))
    );
  }

  const riderNewlyAssigned = afterStatus === "assigned" && beforeStatus !== "assigned" && afterData.deliveryBoyId;
  if (riderNewlyAssigned) {
    const riderTokens = await getFcmTokens("deliveryBoys", afterData.deliveryBoyId);
    const riderRef = db.collection("deliveryBoys").doc(afterData.deliveryBoyId);
    await sendPushToTokens(
      riderTokens,
      "New delivery assigned",
      `Pick up order #${orderId.substring(0, 6).toUpperCase()} for ${afterData.customerName ?? "a customer"}.`,
      { orderId, status: afterStatus },
      new Map(riderTokens.map((t) => [t, riderRef]))
    );
  }
}

/**
 * Automatically updates active rider count when whitelisted.
 */
export const onRiderWritten = onDocumentWritten({ region: REGION, document: "deliveryBoys/{riderId}" }, async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  const statsRef = db.collection("config").doc("dashboard_stats");

  const beforeExists = !!beforeData && beforeData.isDeleted !== true;
  const afterExists = !!afterData && afterData.isDeleted !== true;

  let delta = 0;
  if (!beforeExists && afterExists) {
    delta = 1;
  } else if (beforeExists && !afterExists) {
    delta = -1;
  }

  if (delta !== 0) {
    await statsRef.set({
      activeRidersCount: FieldValue.increment(delta),
      lastUpdated: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  // Sync Auth Custom Claims — only touch Auth when the derived claim state
  // actually flips, not on every unrelated field write (fcmTokens, onDuty,
  // vehicleDetails, etc.) to this doc.
  const beforeShouldHaveClaim = beforeExists && beforeData?.isActive !== false;
  const afterShouldHaveClaim = afterExists && afterData?.isActive !== false;
  const riderId = event.params.riderId;
  if (riderId && riderId.length > 20 && beforeShouldHaveClaim !== afterShouldHaveClaim) {
    const auth = getAuth();
    try {
      if (afterShouldHaveClaim) {
        await auth.setCustomUserClaims(riderId, { role: "delivery", delivery: true });
      } else {
        await auth.setCustomUserClaims(riderId, { role: null, delivery: null });
      }
    } catch (e) {
      console.error(`Failed to set custom claims for rider ${riderId}:`, e);
    }
  }
});

/**
 * Automatically updates total catalog product count.
 */
export const onProductWritten = onDocumentWritten({ region: REGION, document: "products/{productId}" }, async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  const statsRef = db.collection("config").doc("dashboard_stats");

  const beforeExists = !!beforeData && beforeData.isActive !== false;
  const afterExists = !!afterData && afterData.isActive !== false;

  let delta = 0;
  if (!beforeExists && afterExists) {
    delta = 1;
  } else if (beforeExists && !afterExists) {
    delta = -1;
  }

  if (delta !== 0) {
    await statsRef.set({
      productCount: FieldValue.increment(delta),
      lastUpdated: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
});

/**
 * Automatically updates admin Custom Claims when active admin is created or deleted.
 */
export const onAdminWritten = onDocumentWritten({ region: REGION, document: "admins/{adminId}" }, async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  const beforeExists = !!beforeData && beforeData.isActive !== false;
  const afterExists = !!afterData && afterData.isActive !== false;

  // Only touch Auth when the derived claim state actually flips — a console
  // edit to name/email/phone shouldn't re-run a claims write.
  if (beforeExists === afterExists) return;

  const adminId = event.params.adminId;
  const auth = getAuth();

  try {
    if (afterExists) {
      await auth.setCustomUserClaims(adminId, { role: "admin", admin: true });
    } else {
      await auth.setCustomUserClaims(adminId, { role: null, admin: null });
    }
  } catch (e) {
    console.error(`Failed to set custom claims for admin ${adminId}:`, e);
  }
});

/**
 * Creates a rider auth user login and registers them in deliveryBoys collection.
 * Only callable by authenticated admins.
 */
export const createRiderLogin = onCall({ region: REGION, enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }

  // Verify that the caller is an active admin
  const adminSnap = await db.collection("admins").doc(uid).get();
  if (!adminSnap.exists || adminSnap.data()?.isActive === false) {
    throw new HttpsError("permission-denied", "Only active admins can register riders.");
  }

  const email = String(request.data?.email ?? "").trim().toLowerCase();
  const password = String(request.data?.password ?? "");
  const name = String(request.data?.name ?? "").trim();
  const phone = String(request.data?.phone ?? "").trim();
  const village = String(request.data?.village ?? "").trim();
  const vehicleNo = String(request.data?.vehicleNo ?? "").trim();
  const licenseNo = String(request.data?.licenseNo ?? "").trim();

  if (!email || !password || password.length < 6 || !name || !phone || !village) {
    throw new HttpsError("invalid-argument", "Missing or invalid required rider details.");
  }

  const auth = getAuth();
  let userRecord;
  try {
    userRecord = await auth.createUser({
      email,
      password,
      displayName: name,
    });
  } catch (error: any) {
    throw new HttpsError("already-exists", error.message || "Failed to create user auth record.");
  }

  const riderUid = userRecord.uid;

  // Create document in deliveryBoys with document ID = riderUid
  const now = Timestamp.now();
  await db.collection("deliveryBoys").doc(riderUid).set({
    uid: riderUid,
    name,
    email,
    phone,
    village,
    role: "delivery",
    isActive: true,
    onDuty: true,
    vehicleNo,
    licenseNo,
    createdAt: now,
    updatedAt: now,
  });

  // Set custom claims (redundant but safe)
  await auth.setCustomUserClaims(riderUid, { role: "delivery", delivery: true });

  return { success: true, uid: riderUid };
});

/**
 * Sends a one-off test push to a customer or rider's registered devices.
 * Admin-only. Exists purely so push delivery can be verified from the
 * Firebase console without walking a real order through its full lifecycle.
 */
export const sendTestPush = onCall({ region: REGION, enforceAppCheck: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }

  const adminSnap = await db.collection("admins").doc(uid).get();
  if (!adminSnap.exists || adminSnap.data()?.isActive === false) {
    throw new HttpsError("permission-denied", "Only active admins can send test pushes.");
  }

  const targetUid = String(request.data?.targetUid ?? "").trim();
  const collection = request.data?.collection === "deliveryBoys" ? "deliveryBoys" : "users";
  const title = String(request.data?.title ?? "Test notification").trim();
  const body = String(request.data?.body ?? "This is a test push from J C Mart admin.").trim();

  if (!targetUid) {
    throw new HttpsError("invalid-argument", "targetUid is required.");
  }

  const tokens = await getFcmTokens(collection, targetUid);
  if (tokens.length === 0) {
    throw new HttpsError("failed-precondition", "That user has no registered devices for push.");
  }

  await sendPushToTokens(tokens, title, body, { test: "true" });
  return { success: true, tokensNotified: tokens.length };
});

/**
 * Computes a signed Cloudinary upload signature server-side so the API
 * secret never ships inside the client binary. Admin-only — the only
 * current image uploads (product photos, banners) are admin actions.
 */
export const getCloudinarySignature = onCall(
  { region: REGION, secrets: [cloudinaryApiSecret], enforceAppCheck: true },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in first.");
    }

    const adminSnap = await db.collection("admins").doc(uid).get();
    if (!adminSnap.exists || adminSnap.data()?.isActive === false) {
      throw new HttpsError("permission-denied", "Only active admins can upload images.");
    }

    const timestamp = Math.floor(Date.now() / 1000);
    const folder = CLOUDINARY_UPLOAD_FOLDER;
    const stringToSign = `folder=${folder}&timestamp=${timestamp}${cloudinaryApiSecret.value()}`;
    const signature = createHash("sha1").update(stringToSign).digest("hex");

    return {
      timestamp,
      signature,
      apiKey: CLOUDINARY_API_KEY,
      cloudName: CLOUDINARY_CLOUD_NAME,
      folder,
    };
  }
);

/**
 * Blinkit-style broadcast escalation — runs every minute, looking for
 * pending/unassigned orders that haven't been (re)notified in over
 * BROADCAST_RETRY_SECONDS. Every stale order found is re-broadcast to the
 * full on-duty rider pool and bumped to notifyTier 2.
 *
 * This single query+loop covers both halves of the "no admin fallback"
 * requirement: it's what escalates a tier-1 (village-matched) order that
 * nobody took, AND what keeps re-pinging a tier-2 order forever until
 * someone finally accepts — there's no terminal "give up" state.
 */
export const escalateStaleOrders = onSchedule(
  { region: REGION, schedule: "every 1 minutes" },
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - BROADCAST_RETRY_SECONDS * 1000);
    const stale = await db.collection("orders")
      .where("status", "==", "pending")
      .where("deliveryBoyId", "==", null)
      .where("notifiedAt", "<=", cutoff)
      .limit(ESCALATOR_BATCH_LIMIT)
      .get();

    if (stale.empty) return;

    // Same on-duty pool applies to every stale order in this batch — query
    // it once rather than once per order.
    const candidates = await db.collection("deliveryBoys")
      .where("isActive", "==", true)
      .where("onDuty", "==", true)
      .get();
    const tokenOwners = tokenOwnersFromDocs(candidates.docs);
    const tokens = Array.from(tokenOwners.keys());

    for (const doc of stale.docs) {
      const order = doc.data();

      await sendPushToTokens(
        tokens,
        "Delivery still needed nearby",
        `Order from ${order.customerName ?? "a customer"} in ${order.village ?? ""} is still waiting for a rider.`,
        { orderId: doc.id, type: "new_order_offer" },
        tokenOwners
      );

      await doc.ref.set({ notifyTier: 2, notifiedAt: Timestamp.now() }, { merge: true });
    }
  }
);

