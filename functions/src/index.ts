import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";
import { createHash, randomBytes, randomInt, timingSafeEqual } from "crypto";

initializeApp();
const db = getFirestore();

// Cloudinary secret lives in Secret Manager, never in source or the client
// binary. Set with: firebase functions:secrets:set CLOUDINARY_API_SECRET
const cloudinaryApiSecret = defineSecret("CLOUDINARY_API_SECRET");
const cloudinaryApiKey = defineSecret("CLOUDINARY_API_KEY");
const CLOUDINARY_CLOUD_NAME = "diiyy6bar";
const CLOUDINARY_UPLOAD_FOLDER = "products";

// Mumbai region — closest to the Bhimavaram service area.
const REGION = "asia-south1";

const MAX_ITEMS_PER_ORDER = 50;
const MAX_QTY_PER_ITEM = 99;
const MAX_OTP_ATTEMPTS = 5;
// After MAX_OTP_ATTEMPTS wrong tries the rider is locked out for a cooldown
// instead of forever, so a fat-fingered OTP can't strand an order (the admin
// has no reset UI). MAX_OTP_TOTAL_ATTEMPTS is the hard lifetime cap per order
// that still needs an admin resetOtpAttempts.
const OTP_LOCKOUT_MINUTES = 10;
const MAX_OTP_TOTAL_ATTEMPTS = 15;
const ACTIVE_ORDER_STATUSES = ["pending", "assigned", "picked_up", "out_for_delivery"];
// Statuses in which a rider is holding an order (pending has no rider yet).
const RIDER_HELD_STATUSES = ["assigned", "picked_up", "out_for_delivery"];
// One rider can't hoard the pool: at most this many held orders at a time
// (config.maxActiveOrdersPerRider overrides, clamped to 1..20).
const DEFAULT_MAX_ACTIVE_ORDERS_PER_RIDER = 3;
// The delivery code is valid this long once the order is out for delivery. A
// customer who wasn't ready can ask for a fresh one.
const OTP_VALID_MINUTES = 120;
const MAX_OTP_REGENERATIONS = 5;
// A handover more than this far from the customer's pin is flagged for review
// (recorded, never blocked: GPS drift and pin error are normal).
const DELIVERY_FAR_METERS = 500;
const ACTIVE_ORDER_MESSAGE =
  "You already have an active order in progress. You can only place one order at a time.";

// ── Firestore-backed rate limiter ────────────────────────────────────
// Counters live in /rateLimits/{action}_{uid} (client access is denied by the
// catch-all rule), so limits hold across function instances and cold starts.
// Set a TTL policy on `expireAt` to garbage-collect old windows.
const RATE_LIMIT_WINDOW_MS = 60_000; // 1 minute
const RATE_LIMIT_MAX_CALLS = 20;     // max calls per window per UID

// Keyed by "action_uid" rather than uid alone — a burst on one callable
// (e.g. an admin uploading several product images via
// getCloudinarySignature) must not lock the same user out of an unrelated
// action (placeOrder, cancelOrder, ...). Infrastructure errors fail open so a
// Firestore hiccup on the counter never takes ordering down with it.
async function checkRateLimit(uid: string, action: string): Promise<void> {
  const ref = db.collection("rateLimits").doc(`${action}_${uid}`);
  const now = Date.now();
  let exceeded = false;
  try {
    exceeded = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.data();
      const windowStart = Number(data?.windowStart ?? 0);
      if (!data || now - windowStart > RATE_LIMIT_WINDOW_MS) {
        tx.set(ref, {
          count: 1,
          windowStart: now,
          expireAt: Timestamp.fromMillis(now + 2 * RATE_LIMIT_WINDOW_MS),
        });
        return false;
      }
      if (Number(data.count ?? 0) >= RATE_LIMIT_MAX_CALLS) return true;
      tx.update(ref, { count: FieldValue.increment(1) });
      return false;
    });
  } catch (e) {
    console.error(`[RATE_LIMIT_ERROR] ${action}_${uid}:`, e);
    return;
  }
  if (exceeded) {
    throw new HttpsError("resource-exhausted", "Too many requests. Please try again later.");
  }
}

// Blinkit-style rider auto-broadcast: tier-1 (village-matched on-duty riders)
// escalates to tier-2 (all on-duty riders) after this many seconds with no
// acceptance, and tier-2 itself is then re-broadcast ("retried forever") on
// this same cadence by the escalateStaleOrders scheduled function — there is
// no admin manual-assign fallback, so this must never give up.
const BROADCAST_RETRY_SECONDS = 90;
// Each unaccepted order is (re)broadcast at most this many times (~15 min at
// the 90s cadence). Without a cap, one stuck order pushed every on-duty rider
// ~960 times over its 24h life. After the cap it stops pushing and stays
// visible to riders in-app and to the admin as "searching" until it's taken,
// cancelled, or expires.
const MAX_BROADCASTS = 10;
const ESCALATOR_BATCH_LIMIT = 200;
// Orders pending longer than this are auto-cancelled by expireStaleOrders.
// Kept generous so a rider broadcast cycle has time to work.
const EXPIRY_HOURS = 24;

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

interface DeliveryZone {
  name: string;
  latitude: number;
  longitude: number;
  radiusMeters: number;
}

/**
 * The delivery zones in force: the admin-configured `/config/app.serviceZones`
 * (each with its own radius) when present and valid, else the built-in
 * VILLAGES list. The client checks the same zones, so a zone the admin adds is
 * orderable instead of passing the app and failing here.
 */
function deliveryZonesFromConfig(config: FirebaseFirestore.DocumentData): DeliveryZone[] {
  const raw = config?.serviceZones;
  const zones: DeliveryZone[] = Array.isArray(raw)
    ? raw
        .map((z: any) => ({
          name: String(z?.name ?? "").trim(),
          latitude: Number(z?.lat),
          longitude: Number(z?.lng),
          radiusMeters: Number(z?.radiusKm) * 1000,
        }))
        .filter(
          (z) =>
            z.name.length > 0 &&
            isValidCoordinate(z.latitude, z.longitude) &&
            Number.isFinite(z.radiusMeters) &&
            z.radiusMeters > 0
        )
    : [];
  if (zones.length > 0) return zones;
  return VILLAGES.map((v) => ({
    name: v.name,
    latitude: v.latitude,
    longitude: v.longitude,
    radiusMeters: SERVICE_RADIUS_METERS,
  }));
}

/** Which zone (if any) contains the point, plus how close the point is to the
 * nearest zone centre (used to reject an un-pinned "centroid" placeholder). */
function resolveDeliveryZone(
  lat: number,
  lng: number,
  zones: DeliveryZone[]
): { zone: DeliveryZone | null; zoneDistance: number; nearestCentreDistance: number } {
  let zone: DeliveryZone | null = null;
  let zoneDistance = Infinity;
  let nearestCentreDistance = Infinity;
  for (const z of zones) {
    const d = haversineMeters(lat, lng, z.latitude, z.longitude);
    nearestCentreDistance = Math.min(nearestCentreDistance, d);
    if (d <= z.radiusMeters && d < zoneDistance) {
      zone = z;
      zoneDistance = d;
    }
  }
  return { zone, zoneDistance, nearestCentreDistance };
}

/** What the customer pays per unit: a valid discount (0 < discounted < price)
 * when the admin has set one, else the list price. The app shows the same
 * figure (Product.effectivePrice), so the displayed and charged price agree. */
function effectivePrice(product: FirebaseFirestore.DocumentData): number {
  const price = Number(product.price ?? 0);
  const discounted = product.discountedPrice;
  if (typeof discounted === "number" && Number.isFinite(discounted) && discounted > 0 && discounted < price) {
    return discounted;
  }
  return price;
}

/** A product the admin has switched off (either flag) can't be ordered. */
function isProductSellable(product: FirebaseFirestore.DocumentData): boolean {
  return product.isActive !== false && product.isAvailable !== false;
}

// A real house pin never lands within a few metres of a village centroid, but
// the client's map default / "no pin" fallback is exactly a centroid. Treat it
// as "customer never pinned" so riders don't get a fake location.
const CENTROID_PLACEHOLDER_METERS = 5;

function isValidCoordinate(lat: number, lng: number): boolean {
  return Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180;
}

/**
 * Canonical 10-digit Indian mobile number from what a profile may hold
 * ("9876543210", "+91 98765 43210", "09876543210"), or null when it isn't one.
 * A rider must be able to call this number, so an order without a usable one
 * is refused rather than dispatched.
 */
function normalizeIndianMobile(raw: unknown): string | null {
  const compact = String(raw ?? "").replace(/[\s-]/g, "");
  const match = compact.match(/^(?:\+?91|0)?([6-9]\d{9})$/);
  return match ? match[1] : null;
}

/** Constant-time string comparison (avoids leaking OTP digits via timing). */
function safeEqual(a: string, b: string): boolean {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  return ab.length === bb.length && timingSafeEqual(ab, bb);
}

/** A rider location sent with a status change, or null when none was sent.
 * Present-but-malformed is rejected rather than silently dropped. */
function parseRiderLocation(raw: unknown): { lat: number; lng: number; accuracy: number | null } | null {
  if (raw === undefined || raw === null) return null;
  const loc = raw as { lat?: unknown; lng?: unknown; accuracy?: unknown };
  if (
    typeof loc.lat !== "number" ||
    typeof loc.lng !== "number" ||
    !isValidCoordinate(loc.lat, loc.lng)
  ) {
    throw new HttpsError("invalid-argument", "The location sent with this update is invalid.");
  }
  const accuracy = typeof loc.accuracy === "number" && Number.isFinite(loc.accuracy) && loc.accuracy >= 0
    ? loc.accuracy
    : null;
  return { lat: loc.lat, lng: loc.lng, accuracy };
}

/** First name only — all a rider needs before accepting an order. */
function firstName(value: unknown): string {
  const n = String(value ?? "").trim().split(/\s+/)[0];
  return n || "Customer";
}

/** Re-reads the live rider doc: a disabled or soft-deleted rider must not be
 * able to act on orders through callables while a stale token is still valid. */
async function assertActiveRider(uid: string): Promise<void> {
  const snap = await db.collection("deliveryBoys").doc(uid).get();
  const data = snap.data();
  if (!data || data.isActive === false || data.isDeleted === true) {
    throw new HttpsError("permission-denied", "Your account is deactivated. Contact support.");
  }
}

/** True for an order that is open for any rider to claim. */
function isOpenOffer(order: FirebaseFirestore.DocumentData | undefined): boolean {
  return !!order && order.status === "pending" && !order.deliveryBoyId;
}

/**
 * Maintains /orderOffers/{orderId}: the PII-free view of an unclaimed order
 * that riders may read. The full order (customer phone, address, GPS pin) is
 * readable only by the customer, an admin, and the rider who accepted it.
 */
async function syncOrderOffer(
  orderId: string,
  order: FirebaseFirestore.DocumentData | undefined
): Promise<void> {
  const ref = db.collection("orderOffers").doc(orderId);
  try {
    if (!order || !isOpenOffer(order)) {
      await ref.delete();
      return;
    }
    const items = Array.isArray(order.items) ? order.items : [];
    await ref.set({
      status: "pending",
      deliveryBoyId: null,
      customerName: firstName(order.customerName),
      deliveryAddress: "",
      village: String(order.village ?? ""),
      items: items.map((i: any) => ({
        productId: String(i?.productId ?? ""),
        name: String(i?.name ?? ""),
        price: Number(i?.price ?? 0),
        quantity: Number(i?.quantity ?? 0),
      })),
      subtotal: Number(order.subtotal ?? 0),
      deliveryFee: Number(order.deliveryFee ?? 0),
      totalAmount: Number(order.totalAmount ?? 0),
      paymentMethod: String(order.paymentMethod ?? "COD"),
      createdAt: order.createdAt ?? Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  } catch (e) {
    console.error(`[OFFER_SYNC_FAILED] order ${orderId}:`, e);
  }
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

  // Village names are admin-editable free text, so match them trimmed and
  // case-insensitively in memory rather than with an exact Firestore ==
  // (which silently fell through to tier 2 on any casing/whitespace drift).
  const normalize = (s: unknown) => String(s ?? "").trim().toLowerCase();
  const onDutyRiders = await db.collection("deliveryBoys")
    .where("isActive", "==", true)
    .where("onDuty", "==", true)
    .get();
  const localRiders = onDutyRiders.docs.filter((d) => normalize(d.data().village) === normalize(village));

  const tier = localRiders.length > 0 ? 1 : 2;
  const candidateDocs = tier === 1 ? localRiders : onDutyRiders.docs;

  const tokenOwners = tokenOwnersFromDocs(candidateDocs);
  const tokens = Array.from(tokenOwners.keys());

  await sendPushToTokens(
    tokens,
    "New delivery nearby",
    `New order from ${firstName(order.customerName)} in ${village}. Tap to accept.`,
    { orderId, type: "new_order_offer" },
    tokenOwners
  );

  await db.collection("orders").doc(orderId).set(
    { notifyTier: tier, notifiedAt: Timestamp.now(), broadcastCount: 1 },
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
export const placeOrder = onCall({ region: REGION, enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to place an order.");
  }
  await checkRateLimit(uid, "placeOrder");

  // Idempotency: the client sends one requestId per checkout attempt. The
  // order id is derived from (uid, requestId), so a retry after a lost
  // response returns the order that already exists instead of failing with
  // "you already have an active order".
  const requestId = String(request.data?.requestId ?? "").trim();
  if (requestId && !/^[A-Za-z0-9_-]{8,64}$/.test(requestId)) {
    throw new HttpsError("invalid-argument", "Invalid request id.");
  }
  const orderRef = requestId
    ? db.collection("orders").doc(
        createHash("sha256").update(`${uid}:${requestId}`).digest("hex").slice(0, 20)
      )
    : db.collection("orders").doc();
  if (requestId) {
    const existingSnap = await orderRef.get();
    if (existingSnap.exists) {
      const existing = existingSnap.data() as FirebaseFirestore.DocumentData;
      if (existing.customerId !== uid) {
        throw new HttpsError("permission-denied", "Invalid request id.");
      }
      const privateSnap = await orderRef.collection("private").doc("delivery").get();
      return {
        orderId: orderRef.id,
        otp: String(privateSnap.data()?.otp ?? ""),
        subtotal: Number(existing.subtotal ?? 0),
        deliveryFee: Number(existing.deliveryFee ?? 0),
        totalAmount: Number(existing.totalAmount ?? 0),
        deduplicated: true,
      };
    }
  }

  const items = request.data?.items as OrderItemInput[] | undefined;
  const deliveryAddress = String(request.data?.deliveryAddress ?? "").trim();
  const deliveryInstructions = String(request.data?.deliveryInstructions ?? "").trim().slice(0, 500);
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
  if (latitude === null || longitude === null || !isValidCoordinate(latitude, longitude)) {
    throw new HttpsError(
      "invalid-argument",
      "A delivery location (GPS coordinates) is required to place an order."
    );
  }
  const configSnap = await db.collection("config").doc("app").get();
  const config = configSnap.exists ? (configSnap.data() as FirebaseFirestore.DocumentData) : {};
  // Identity gate: email/password accounts must have proved they own the
  // address (Google accounts arrive verified). Admins can switch this off with
  // config.requireVerifiedEmail=false, e.g. while an email provider is down.
  if (config.requireVerifiedEmail !== false && request.auth?.token?.email_verified !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Verify your email address before placing an order. Check your inbox for the verification link."
    );
  }
  const resolved = resolveDeliveryZone(latitude, longitude, deliveryZonesFromConfig(config));
  if (!resolved.zone) {
    throw new HttpsError(
      "failed-precondition",
      "This delivery address is outside our service area."
    );
  }
  if (resolved.nearestCentreDistance < CENTROID_PLACEHOLDER_METERS) {
    throw new HttpsError(
      "invalid-argument",
      "Please pin your exact delivery location on the map."
    );
  }
  const nearest = { name: resolved.zone.name };
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
  const customerName = String(user.name ?? "").trim();
  if (!customerName) {
    throw new HttpsError("failed-precondition", "Add your name to your profile before ordering.");
  }
  const customerMobile = normalizeIndianMobile(user.phone);
  if (!customerMobile) {
    throw new HttpsError(
      "failed-precondition",
      "Add a valid 10-digit mobile number to your profile before ordering."
    );
  }

  if (config.storeOpen === false) {
    throw new HttpsError("failed-precondition", "The store is currently closed. Please try later.");
  }
  if (config.maintenanceMode === true) {
    throw new HttpsError(
      "failed-precondition",
      "The store is under maintenance right now. Please try again shortly."
    );
  }

  // Fast pre-check for a friendly early error (also covers orders that
  // predate the lock doc). The authoritative one-active-order guard is the
  // orderLocks doc inside the transaction below — this query alone can't stop
  // two concurrent requests from both passing.
  const activeOrderSnap = await db.collection("orders")
    .where("customerId", "==", uid)
    .where("status", "in", ACTIVE_ORDER_STATUSES)
    .limit(1)
    .get();
  if (!activeOrderSnap.empty) {
    throw new HttpsError("failed-precondition", ACTIVE_ORDER_MESSAGE);
  }
  const deliveryFeeConfig = Number(config.deliveryFee ?? 30);
  const freeDeliveryAbove = Number(config.freeDeliveryAbove ?? 300);
  const minimumOrderAmount = Number(config.minimumOrderAmount ?? 0);

  const otp = String(randomInt(1000, 10000));
  const lockRef = db.collection("orderLocks").doc(uid);

  const totals = await db.runTransaction(async (tx) => {
    // All reads first (Firestore requires reads before writes in a tx).
    const lockSnap = await tx.get(lockRef);
    const lockedOrderId = lockSnap.exists ? lockSnap.data()?.orderId : undefined;
    if (typeof lockedOrderId === "string" && lockedOrderId) {
      const lockedOrderSnap = await tx.get(db.collection("orders").doc(lockedOrderId));
      if (lockedOrderSnap.exists && ACTIVE_ORDER_STATUSES.includes(lockedOrderSnap.data()?.status)) {
        throw new HttpsError("failed-precondition", ACTIVE_ORDER_MESSAGE);
      }
    }

    const productRefs = items.map((item) => db.collection("products").doc(item.productId));
    const productSnaps = await tx.getAll(...productRefs);

    let subtotal = 0;
    const orderItems = items.map((item, i) => {
      const snap = productSnaps[i];
      if (!snap.exists) {
        throw new HttpsError("not-found", "One of the products is no longer available.");
      }
      const product = snap.data() as FirebaseFirestore.DocumentData;
      // Prescription medicines can't be sold without verifying a prescription,
      // and the app has no prescription upload/verification flow yet — so they
      // are blocked here rather than sold unverified. Lift this when a real
      // verification step exists.
      if (product.requiresPrescription === true) {
        throw new HttpsError(
          "failed-precondition",
          `"${product.name}" is a prescription medicine and can't be ordered in the app yet.`
        );
      }
      if (!isProductSellable(product)) {
        throw new HttpsError(
          "failed-precondition",
          `"${product.name}" is not currently available for purchase.`
        );
      }
      const stockVal = Number(product.stock ?? 0);
      const physicalStock = Number(product.physicalStock ?? stockVal);
      const reservedStock = Number(product.reservedStock ?? 0);
      // Always derive from the source-of-truth fields — a stored
      // availableStock edited by hand in the console must not be trusted.
      const availableStock = physicalStock - reservedStock;

      if (availableStock < item.quantity) {
        throw new HttpsError(
          "failed-precondition",
          `"${product.name}" has only ${availableStock} units available for purchase.`
        );
      }
      const listPrice = Number(product.price ?? 0);
      const price = effectivePrice(product);
      if (!Number.isFinite(price) || price <= 0) {
        throw new HttpsError(
          "failed-precondition",
          `"${product.name}" is not currently available for purchase.`
        );
      }
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
        actorType: "customer",
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
        // The undiscounted price, for receipts. `price` is what was charged.
        listPrice,
        quantity: item.quantity,
      };
    });

    if (minimumOrderAmount > 0 && subtotal < minimumOrderAmount) {
      throw new HttpsError(
        "failed-precondition",
        `Minimum order amount is ₹${minimumOrderAmount}.`
      );
    }

    const deliveryFee = subtotal > freeDeliveryAbove ? 0 : deliveryFeeConfig;
    const totalAmount = subtotal + deliveryFee;
    const now = Timestamp.now();

    tx.set(lockRef, { orderId: orderRef.id, updatedAt: now });
    tx.set(orderRef, {
      customerId: uid,
      customerName,
      // Always +91-prefixed so riders can call or WhatsApp it as stored.
      customerPhone: `+91${customerMobile}`,
      deliveryAddress,
      deliveryInstructions: deliveryInstructions || null,
      // Derived from the pinned coordinates (not the profile's village) so a
      // customer with addresses in several villages routes to the right riders.
      village: nearest.name,
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
 * Allows a customer to cancel their order if it is still in the 'pending' state.
 * Stock release is handled by the onOrderWritten trigger (same path as
 * expireStaleOrders) to avoid double-release bugs.
 */
export const cancelOrder = onCall({ region: REGION, enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to cancel an order.");
  }
  await checkRateLimit(uid, "cancelOrder");

  const orderId = String(request.data?.orderId ?? "").trim();
  const reason = String(request.data?.reason ?? "Cancelled by customer").trim();

  if (!orderId) {
    throw new HttpsError("invalid-argument", "Order ID is required.");
  }

  const orderRef = db.collection("orders").doc(orderId);

  await db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }

    const order = orderSnap.data() as FirebaseFirestore.DocumentData;

    // Check if caller is active admin
    const adminSnap = await tx.get(db.collection("admins").doc(uid));
    const isAdmin = adminSnap.exists && adminSnap.data()?.isActive !== false;

    if (!isAdmin && order.customerId !== uid) {
      throw new HttpsError("permission-denied", "You can only cancel your own orders.");
    }

    if (!isAdmin && order.status !== "pending" && order.status !== "assigned") {
      throw new HttpsError(
        "failed-precondition",
        `Order cannot be cancelled once in status '${order.status}'.`
      );
    }

    // A closed order must never be re-cancelled: cancelling a delivered order
    // would release stock that the delivery already consumed.
    if (order.status === "delivered" || order.status === "cancelled") {
      throw new HttpsError(
        "failed-precondition",
        `Order is already ${order.status} and can't be cancelled.`
      );
    }

    const cancelledByRole = isAdmin ? "admin" : "customer";

    tx.update(orderRef, {
      status: "cancelled",
      cancelReason: reason,
      cancelledBy: cancelledByRole,
      cancelledById: uid,
      updatedAt: Timestamp.now(),
    });
  });

  return { success: true };
});

const DELIVERY_FAILURE_REASONS = [
  "Customer unreachable",
  "Customer refused delivery",
  "Wrong or inaccessible address",
  "Other",
] as const;

/**
 * Lets the assigned rider report that an out-for-delivery (or earlier)
 * order could not actually be handed over — e.g. the customer doesn't
 * answer, refuses COD, or the address doesn't exist. Without this there was
 * no way to ever get an order out of an in-progress state short of a manual
 * Firestore console edit: verifyDeliveryOtp is the only path to 'delivered',
 * and the client rules only let a rider advance status forward one step, so
 * a stuck order had no way out for the rider or the customer.
 * Stock release + ledger entry is handled by the existing onOrderWritten
 * cancellation branch, same as cancelOrder/expireStaleOrders.
 */
export const reportDeliveryFailure = onCall({ region: REGION, enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  await checkRateLimit(uid, "reportDeliveryFailure");

  const orderId = String(request.data?.orderId ?? "").trim();
  const reasonInput = String(request.data?.reason ?? "").trim();
  const reason = (DELIVERY_FAILURE_REASONS as readonly string[]).includes(reasonInput)
    ? reasonInput
    : "Other";

  if (!orderId) {
    throw new HttpsError("invalid-argument", "Order ID is required.");
  }
  await assertActiveRider(uid);

  const orderRef = db.collection("orders").doc(orderId);

  await db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }

    const order = orderSnap.data() as FirebaseFirestore.DocumentData;
    if (order.deliveryBoyId !== uid) {
      throw new HttpsError("permission-denied", "This order isn't assigned to you.");
    }

    if (!["assigned", "picked_up", "out_for_delivery"].includes(order.status)) {
      throw new HttpsError(
        "failed-precondition",
        "This order is no longer in a state that can be marked undelivered."
      );
    }

    tx.update(orderRef, {
      status: "cancelled",
      cancelReason: reason,
      cancelledBy: "rider",
      updatedAt: Timestamp.now(),
    });
  });

  return { success: true };
});

/**
 * Verifies the customer's delivery OTP and marks the order delivered.
 * Callable only by the rider the order is assigned to, only while the
 * order is out for delivery, with a capped number of attempts.
 */
export const verifyDeliveryOtp = onCall({ region: REGION, enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  await checkRateLimit(uid, "verifyDeliveryOtp");

  const orderId = String(request.data?.orderId ?? "");
  const otp = String(request.data?.otp ?? "").trim();
  if (!orderId || !/^\d{4}$/.test(otp)) {
    throw new HttpsError("invalid-argument", "Order ID and a 4-digit OTP are required.");
  }
  await assertActiveRider(uid);
  const riderLocation = parseRiderLocation(request.data?.location);

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
    // Idempotent: a retry after the network dropped the first response must
    // not tell the rider their (already committed) delivery failed.
    if (order.status === "delivered") {
      return { kind: "delivered" as const };
    }
    if (order.status !== "out_for_delivery") {
      throw new HttpsError("failed-precondition", "Order is not out for delivery.");
    }

    // COD: the rider must confirm the exact amount collected. Checked before
    // the OTP so a mistaken amount never burns one of the OTP attempts, and
    // recorded below so a later dispute can be traced to a figure the rider
    // confirmed rather than one the server assumed.
    const rawCollected = request.data?.collectedAmount;
    const collectedAmount = typeof rawCollected === "number" ? rawCollected : NaN;
    if (!Number.isFinite(collectedAmount) || collectedAmount < 0) {
      throw new HttpsError(
        "invalid-argument",
        "Confirm the cash you collected before completing the delivery."
      );
    }
    const amountDue = Number(order.totalAmount ?? 0);
    if (Math.round(collectedAmount * 100) !== Math.round(amountDue * 100)) {
      throw new HttpsError(
        "failed-precondition",
        `Collect exactly ₹${amountDue} from the customer. If they can't pay, report the delivery as failed.`
      );
    }

    const privateRef = orderRef.collection("private").doc("delivery");
    const privateSnap = await tx.get(privateRef);
    if (!privateSnap.exists) {
      throw new HttpsError("internal", "Delivery verification data missing. Contact admin.");
    }
    const secret = privateSnap.data() as FirebaseFirestore.DocumentData;
    // The payout rate in force at delivery time is frozen onto the order, so
    // later rate changes never reprice a rider's history.
    const configSnap = await tx.get(db.collection("config").doc("app"));
    const riderPayout = Number(configSnap.data()?.riderPayoutPerDelivery ?? 30);

    // An expired code is refused before it is compared, so the rider's
    // attempts aren't spent on a code that can no longer work.
    const expiresAtMs = secret.expiresAt instanceof Timestamp ? secret.expiresAt.toMillis() : 0;
    if (expiresAtMs > 0 && expiresAtMs < Date.now()) {
      return { kind: "expired" as const };
    }

    const totalAttempts = Number(secret.totalAttempts ?? secret.attempts ?? 0);
    if (totalAttempts >= MAX_OTP_TOTAL_ATTEMPTS) {
      return { kind: "hard_locked" as const };
    }

    const nowMs = Date.now();
    const lockedUntilMs = secret.lockedUntil instanceof Timestamp ? secret.lockedUntil.toMillis() : 0;
    if (lockedUntilMs > nowMs) {
      return { kind: "cooling_down" as const, minutes: Math.ceil((lockedUntilMs - nowMs) / 60000) };
    }
    // A lockout that has expired starts a fresh window of attempts.
    const windowAttempts = lockedUntilMs > 0 ? 0 : Number(secret.attempts ?? 0);

    if (!safeEqual(String(secret.otp ?? ""), otp)) {
      const newWindow = windowAttempts + 1;
      const lockNow = newWindow >= MAX_OTP_ATTEMPTS;
      tx.update(privateRef, {
        attempts: lockNow ? 0 : newWindow,
        totalAttempts: totalAttempts + 1,
        lockedUntil: lockNow ? Timestamp.fromMillis(nowMs + OTP_LOCKOUT_MINUTES * 60000) : null,
      });
      return {
        kind: "wrong_otp" as const,
        remaining: lockNow ? 0 : MAX_OTP_ATTEMPTS - newWindow,
        locked: lockNow,
      };
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
            actorType: "rider",
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

    const deliveredNow = Timestamp.now();
    // Where the handover happened, and how far that is from the customer's
    // pin. Recorded for disputes; a far handover is flagged, never blocked.
    let proof: Record<string, unknown> = {};
    if (riderLocation) {
      // An order without a pin has null coordinates; Number(null) is 0, which
      // would read as a real point off the coast of Africa.
      const hasPin =
        typeof order.latitude === "number" &&
        typeof order.longitude === "number" &&
        isValidCoordinate(order.latitude, order.longitude);
      const distance = hasPin
        ? Math.round(haversineMeters(riderLocation.lat, riderLocation.lng, order.latitude, order.longitude))
        : null;
      proof = {
        deliveryLocation: {
          lat: riderLocation.lat,
          lng: riderLocation.lng,
          accuracy: riderLocation.accuracy,
          at: deliveredNow,
        },
        deliveryDistanceMeters: distance,
        deliveryFar: distance !== null && distance > DELIVERY_FAR_METERS,
      };
    }
    tx.update(orderRef, {
      ...proof,
      status: "delivered",
      // The reservation was consumed by this delivery (see the "sale" ledger
      // entries above) — flag it so no later cancel can release it again.
      stockReleased: true,
      paymentStatus: "paid",
      codCollectedAmount: collectedAmount,
      codCollectedBy: uid,
      codCollectedAt: deliveredNow,
      riderPayout,
      deliveredAt: deliveredNow,
      updatedAt: deliveredNow,
    });
    return { kind: "delivered" as const };
  });

  switch (outcome.kind) {
    case "expired":
      throw new HttpsError(
        "failed-precondition",
        "This delivery code has expired. Ask the customer to open their order and get a new code."
      );
    case "hard_locked":
      throw new HttpsError(
        "resource-exhausted",
        "Too many incorrect attempts on this order. Ask the admin to reset OTP verification."
      );
    case "cooling_down":
      throw new HttpsError(
        "resource-exhausted",
        `Too many incorrect attempts. Try again in ${outcome.minutes} minute${outcome.minutes === 1 ? "" : "s"}.`
      );
    case "wrong_otp":
      throw new HttpsError(
        "permission-denied",
        outcome.locked
          ? `Incorrect delivery OTP. Locked for ${OTP_LOCKOUT_MINUTES} minutes.`
          : `Incorrect delivery OTP. ${outcome.remaining} attempt${outcome.remaining === 1 ? "" : "s"} left.`
      );
    default:
      return { success: true };
  }
});

/**
 * Admin-only recovery path for an order stuck at verifyDeliveryOtp's
 * MAX_OTP_ATTEMPTS cap: resets the attempt counter so the rider can retry
 * (or the admin can walk the customer through re-reading the OTP).
 */
export const resetOtpAttempts = onCall({ region: REGION, enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }

  const adminSnap = await db.collection("admins").doc(uid).get();
  if (!adminSnap.exists || adminSnap.data()?.isActive === false) {
    throw new HttpsError("permission-denied", "Only active admins can reset OTP attempts.");
  }

  const orderId = String(request.data?.orderId ?? "");
  if (!orderId) {
    throw new HttpsError("invalid-argument", "orderId is required.");
  }

  const privateRef = db.collection("orders").doc(orderId).collection("private").doc("delivery");
  const privateSnap = await privateRef.get();
  if (!privateSnap.exists) {
    throw new HttpsError("not-found", "No delivery verification data for this order.");
  }

  await privateRef.update({ attempts: 0, totalAttempts: 0, lockedUntil: null });
  console.log(`[OTP_ATTEMPTS_RESET] order ${orderId} reset by admin ${uid}`);

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
export const acceptOrder = onCall({ region: REGION, enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  await checkRateLimit(uid, "acceptOrder");
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

  const configSnap = await db.collection("config").doc("app").get();
  const configuredMax = Number(configSnap.data()?.maxActiveOrdersPerRider);
  const maxActiveOrders = Number.isFinite(configuredMax) && configuredMax >= 1
    ? Math.min(Math.floor(configuredMax), 20)
    : DEFAULT_MAX_ACTIVE_ORDERS_PER_RIDER;

  const orderRef = db.collection("orders").doc(orderId);
  const outcome = await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }
    const order = snap.data() as FirebaseFirestore.DocumentData;
    // Idempotent for the rider who already won it (double-tap / retry after a
    // dropped response) — otherwise they'd be told "taken by another rider".
    if (order.deliveryBoyId === uid && order.status === "assigned") {
      return "accepted";
    }
    if (order.status !== "pending" || order.deliveryBoyId) {
      return "taken";
    }

    // A rider may only hold so many orders at once. Counted inside the
    // transaction so two simultaneous accepts can't both slip under the cap.
    const heldSnap = await tx.get(
      db.collection("orders")
        .where("deliveryBoyId", "==", uid)
        .where("status", "in", RIDER_HELD_STATUSES)
    );
    if (heldSnap.size >= maxActiveOrders) {
      return "at_capacity";
    }

    tx.delete(db.collection("orderOffers").doc(orderId));
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
  if (outcome === "at_capacity") {
    throw new HttpsError(
      "failed-precondition",
      `You already have ${maxActiveOrders} active deliveries. Finish one before accepting another.`
    );
  }
  return { success: true };
});

/**
 * Moves the rider's own order one step forward (assigned → picked_up →
 * out_for_delivery) and records when and — if the app could get a fix — where.
 * This is the only path for those transitions (the rules no longer let a rider
 * write status directly), so the timestamps and locations can't be skipped.
 * Going out for delivery also starts the delivery code's validity window.
 * 'delivered' remains verifyDeliveryOtp's alone.
 */
export const advanceOrderStatus = onCall({ region: REGION, enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  await checkRateLimit(uid, "advanceOrderStatus");

  const orderId = String(request.data?.orderId ?? "").trim();
  if (!orderId) {
    throw new HttpsError("invalid-argument", "orderId is required.");
  }
  const location = parseRiderLocation(request.data?.location);
  await assertActiveRider(uid);

  const NEXT: Record<string, string> = { assigned: "picked_up", picked_up: "out_for_delivery" };
  const orderRef = db.collection("orders").doc(orderId);
  const privateRef = orderRef.collection("private").doc("delivery");

  const status = await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }
    const order = snap.data() as FirebaseFirestore.DocumentData;
    if (order.deliveryBoyId !== uid) {
      throw new HttpsError("permission-denied", "This order isn't assigned to you.");
    }
    const requested = String(request.data?.status ?? "").trim();
    const next = NEXT[order.status];
    if (!next) {
      throw new HttpsError(
        "failed-precondition",
        order.status === "cancelled"
          ? "This order was cancelled. Go back and check its status."
          : `This order can't be moved on from '${order.status}'.`
      );
    }
    // Idempotent retry: the client already asked for the state it is in.
    if (requested && requested === order.status) {
      return order.status as string;
    }
    if (requested && requested !== next) {
      throw new HttpsError("failed-precondition", `The next step for this order is '${next}'.`);
    }

    const now = Timestamp.now();
    const point = location
      ? { lat: location.lat, lng: location.lng, accuracy: location.accuracy, at: now }
      : null;
    const update: Record<string, unknown> = { status: next, updatedAt: now };
    if (next === "picked_up") {
      update.pickedUpAt = now;
      update.pickupLocation = point;
    } else {
      update.outForDeliveryAt = now;
      update.dispatchLocation = point;
    }
    tx.update(orderRef, update);

    if (next === "out_for_delivery") {
      // The code starts counting down now; the customer can refresh it.
      tx.set(
        privateRef,
        { expiresAt: Timestamp.fromMillis(now.toMillis() + OTP_VALID_MINUTES * 60_000) },
        { merge: true }
      );
    }
    return next;
  });

  return { success: true, status };
});

/**
 * Gives the ordering customer a fresh delivery code — for a code that was
 * shared by mistake or has expired. Resets the failed-attempt counters and, if
 * the order is already out for delivery, restarts the validity window.
 */
export const regenerateDeliveryOtp = onCall({ region: REGION, enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  await checkRateLimit(uid, "regenerateDeliveryOtp");

  const orderId = String(request.data?.orderId ?? "").trim();
  if (!orderId) {
    throw new HttpsError("invalid-argument", "orderId is required.");
  }

  const orderRef = db.collection("orders").doc(orderId);
  const privateRef = orderRef.collection("private").doc("delivery");

  return db.runTransaction(async (tx) => {
    const [orderSnap, privateSnap] = await Promise.all([tx.get(orderRef), tx.get(privateRef)]);
    if (!orderSnap.exists) {
      throw new HttpsError("not-found", "Order not found.");
    }
    const order = orderSnap.data() as FirebaseFirestore.DocumentData;
    if (order.customerId !== uid) {
      throw new HttpsError("permission-denied", "You can only refresh the code for your own orders.");
    }
    if (!RIDER_HELD_STATUSES.includes(order.status)) {
      throw new HttpsError(
        "failed-precondition",
        order.status === "pending"
          ? "A delivery partner hasn't accepted this order yet."
          : "This order is closed, so its delivery code can't be refreshed."
      );
    }
    const secret = (privateSnap.data() ?? {}) as FirebaseFirestore.DocumentData;
    const regenerations = Number(secret.regenerations ?? 0);
    if (regenerations >= MAX_OTP_REGENERATIONS) {
      throw new HttpsError(
        "resource-exhausted",
        "You've refreshed this code too many times. Contact support if you need help."
      );
    }

    const now = Timestamp.now();
    const otp = String(randomInt(1000, 10000));
    const expiresAt = order.status === "out_for_delivery"
      ? Timestamp.fromMillis(now.toMillis() + OTP_VALID_MINUTES * 60_000)
      : null;
    tx.set(
      privateRef,
      {
        otp,
        attempts: 0,
        totalAttempts: 0,
        lockedUntil: null,
        regenerations: regenerations + 1,
        regeneratedAt: now,
        expiresAt,
      },
      { merge: true }
    );
    return { otp, expiresAtMs: expiresAt ? expiresAt.toMillis() : null };
  });
});

/**
 * Releases the stock reserved by a cancelled order and writes the "return"
 * ledger entries. Idempotent: the order is re-read inside the transaction and
 * `stockReleased` is set atomically with the stock writes. Throws on failure
 * so callers can record it (see repairStockReleases).
 */
async function releaseOrderStock(
  orderRef: FirebaseFirestore.DocumentReference,
  orderId: string,
  orderData: FirebaseFirestore.DocumentData
): Promise<void> {
  const itemsList = (orderData.items || []) as { productId: string; quantity: number }[];
  if (itemsList.length === 0) return;
  const productRefs = itemsList.map((item) => db.collection("products").doc(item.productId));

  await db.runTransaction(async (tx) => {
    // Re-read the order inside the tx: a stale snapshot would release the same
    // reservation twice for a retried / concurrent delivery and eat other
    // orders' reserved stock.
    const [orderSnap, ...productSnaps] = await tx.getAll(orderRef, ...productRefs);
    const fresh = orderSnap.data();
    if (fresh?.stockReleased || fresh?.status === "delivered") return;

    // cancelledBy carries who actually triggered this release (customer via
    // cancelOrder, rider via reportDeliveryFailure, system via auto-expire).
    const cancelActorType = orderData.cancelledBy === "customer"
      ? "customer"
      : orderData.cancelledBy === "rider"
        ? "rider"
        : orderData.cancelledBy === "admin"
          ? "admin"
          : "system";
    const cancelActorId = orderData.cancelledBy === "rider"
      ? (orderData.deliveryBoyId || "system")
      : orderData.cancelledBy === "admin"
        ? (orderData.cancelledById || "system")
        : (orderData.customerId || "system");

    for (let i = 0; i < itemsList.length; i++) {
      const item = itemsList[i];
      const prodSnap = productSnaps[i];
      if (!prodSnap.exists) continue;
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
        updatedAt: Timestamp.now(),
      });

      tx.set(db.collection("inventoryLogs").doc(), {
        productId: item.productId,
        adminId: cancelActorId,
        actorType: cancelActorType,
        orderId,
        changeType: "return",
        physicalDelta: 0,
        reservedDelta: -item.quantity,
        notes: `Order #${orderId} cancelled; reservation released.`,
        timestamp: Timestamp.now(),
      });
    }
    tx.set(orderRef, { stockReleased: true, stockReleaseFailed: FieldValue.delete() }, { merge: true });
  });
}

/**
 * Retries stock releases that failed inside onOrderWritten. Without this a
 * transient error strands `reservedStock` and makes the product look sold out.
 */
export const repairStockReleases = onSchedule(
  { region: REGION, schedule: "every 15 minutes" },
  async () => {
    const flagged = await db.collection("orders")
      .where("stockReleaseFailed", "==", true)
      .limit(ESCALATOR_BATCH_LIMIT)
      .get();
    for (const doc of flagged.docs) {
      const order = doc.data();
      try {
        if (order.status !== "cancelled" || order.stockReleased) {
          await doc.ref.update({ stockReleaseFailed: FieldValue.delete() });
          continue;
        }
        await releaseOrderStock(doc.ref, doc.id, order);
      } catch (e) {
        console.error(`[STOCK_REPAIR_FAILED] order ${doc.id}:`, e);
      }
    }
  }
);

/**
 * Automatically updates active order count and completed revenue.
 */
export const onOrderWritten = onDocumentWritten({ region: REGION, document: "orders/{orderId}" }, async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  const statsRef = db.collection("config").doc("dashboard_stats");

  // Keep the rider-visible, PII-free offer in step with whether the order is
  // still open for any rider to claim.
  if (isOpenOffer(beforeData) !== isOpenOffer(afterData)) {
    await syncOrderOffer(event.params.orderId, afterData);
  }

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
      // If transition to cancelled: release reserved stock and log return.
      // Guarded by `stockReleased` so a redelivered/retried trigger event
      // can never double-release the same reservation, and by the delivered
      // check because a delivery already consumed the reservation.
      if (
        afterStatus === "cancelled" &&
        beforeStatus !== "cancelled" &&
        beforeStatus !== "delivered" &&
        !afterData.stockReleased
      ) {
        const orderRef = event.data!.after.ref;
        try {
          await releaseOrderStock(orderRef, event.params.orderId, afterData);
        } catch (err) {
          console.error(
            `[STOCK_RELEASE_FAILED] order ${event.params.orderId} was cancelled but its reserved ` +
            `stock could not be released; repairStockReleases will retry.`,
            err
          );
          // Flag the order so the scheduled repair job picks it up. Status is
          // unchanged, so this write does not re-enter the branch above.
          await orderRef
            .set({ stockReleaseFailed: true }, { merge: true })
            .catch((e) => console.error("Failed to flag stockReleaseFailed:", e));
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
        await auth.updateUser(riderId, { disabled: false });
      } else {
        await auth.setCustomUserClaims(riderId, { role: null, delivery: null });
        // Claims alone linger until the ID token expires (~1h): disable the
        // account and revoke refresh tokens so the session actually ends.
        await auth.updateUser(riderId, { disabled: true });
        await auth.revokeRefreshTokens(riderId);
      }
    } catch (e) {
      console.error(`Failed to sync auth state for rider ${riderId}:`, e);
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

  const beforeExists = !!beforeData && isProductSellable(beforeData);
  const afterExists = !!afterData && isProductSellable(afterData);

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
      await auth.updateUser(adminId, { disabled: false });
    } else {
      await auth.setCustomUserClaims(adminId, { role: null, admin: null });
      await auth.updateUser(adminId, { disabled: true });
      await auth.revokeRefreshTokens(adminId);
    }
  } catch (e) {
    console.error(`Failed to sync auth state for admin ${adminId}:`, e);
  }
});

/**
 * Creates a rider auth user login and registers them in deliveryBoys collection.
 * Only callable by authenticated admins.
 */
export const createRiderLogin = onCall({ region: REGION, enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  await checkRateLimit(uid, "createRiderLogin");

  // Verify that the caller is an active admin
  const adminSnap = await db.collection("admins").doc(uid).get();
  if (!adminSnap.exists || adminSnap.data()?.isActive === false) {
    throw new HttpsError("permission-denied", "Only active admins can register riders.");
  }

  const email = String(request.data?.email ?? "").trim().toLowerCase();
  const name = String(request.data?.name ?? "").trim();
  const phone = String(request.data?.phone ?? "").trim();
  const village = String(request.data?.village ?? "").trim();
  const vehicleNo = String(request.data?.vehicleNo ?? "").trim();
  const licenseNo = String(request.data?.licenseNo ?? "").trim();

  if (!email || !name || !phone || !village) {
    throw new HttpsError("invalid-argument", "Missing or invalid required rider details.");
  }

  // Generated server-side rather than accepted from the admin's client, so
  // the credential transported to the rider is never chosen/known by a
  // third party and always meets a real strength floor.
  const password = randomBytes(9).toString("base64url");

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

  try {
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
  } catch (error) {
    // Don't leave an Auth account with no rider doc behind: the admin would
    // retry and hit "email already exists" with no way to recover.
    console.error(`[RIDER_CREATE_FAILED] rolling back Auth user ${riderUid}:`, error);
    await db.collection("deliveryBoys").doc(riderUid).delete().catch(() => undefined);
    await auth.deleteUser(riderUid).catch(() => undefined);
    throw new HttpsError("internal", "Failed to create the rider. Please try again.");
  }

  return { success: true, uid: riderUid, temporaryPassword: password };
});

// ── Geocoding proxy ─────────────────────────────────────────────────
// The app used to call the public Nominatim endpoint straight from every
// device (no caching, an inconsistent User-Agent, no throttle), which that
// service's usage policy doesn't allow at scale. The app now calls these
// callables instead: they identify the app, cache results in Firestore, are
// App Check + rate limited per user, and are the single place to swap in a
// paid geocoder — set GEOCODER_BASE_URL (Nominatim-compatible API) and
// GEOCODER_CONTACT_EMAIL in the function's environment.
const GEOCODER_BASE_URL = (process.env.GEOCODER_BASE_URL ?? "https://nominatim.openstreetmap.org").replace(/\/+$/, "");
const GEOCODER_CONTACT = process.env.GEOCODER_CONTACT_EMAIL ?? "support@jcmart.app";
const GEOCODER_TIMEOUT_MS = 8_000;
const GEOCODE_CACHE_DAYS = 30;
const SEARCH_RESULT_LIMIT = 6;

async function geocoderGet(path: string, params: Record<string, string>): Promise<any> {
  const url = `${GEOCODER_BASE_URL}${path}?${new URLSearchParams({ format: "jsonv2", ...params }).toString()}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), GEOCODER_TIMEOUT_MS);
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": `JCMart/1.0 (${GEOCODER_CONTACT})`, "Accept-Language": "en" },
      signal: controller.signal,
    });
    if (!res.ok) throw new Error(`geocoder responded ${res.status}`);
    return await res.json();
  } finally {
    clearTimeout(timer);
  }
}

async function readGeocodeCache(key: string): Promise<any | null> {
  const snap = await db.collection("geocodeCache").doc(key).get();
  const data = snap.data();
  if (!data || !(data.fetchedAt instanceof Timestamp)) return null;
  const ageMs = Date.now() - data.fetchedAt.toMillis();
  return ageMs < GEOCODE_CACHE_DAYS * 24 * 3600 * 1000 ? data.value : null;
}

function writeGeocodeCache(key: string, value: unknown): Promise<unknown> {
  return db
    .collection("geocodeCache")
    .doc(key)
    .set({ value, fetchedAt: Timestamp.now() })
    .catch((e) => console.error("[GEOCODE_CACHE_WRITE_FAILED]", e));
}

/** Address details for a pinned point, to pre-fill the address form. Best
 * effort: the client treats any failure as "fill it in yourself". */
export const reverseGeocode = onCall({ region: REGION, enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  await checkRateLimit(uid, "geocode");

  const lat = typeof request.data?.lat === "number" ? request.data.lat : NaN;
  const lng = typeof request.data?.lng === "number" ? request.data.lng : NaN;
  if (!isValidCoordinate(lat, lng)) {
    throw new HttpsError("invalid-argument", "A valid location is required.");
  }

  // ~11 m grid: neighbouring pins share an entry, which is what makes the
  // cache effective in a small service area.
  const cacheKey = `rev_${lat.toFixed(4)}_${lng.toFixed(4)}`;
  const cached = await readGeocodeCache(cacheKey);
  if (cached) return cached;

  let body: any;
  try {
    body = await geocoderGet("/reverse", {
      lat: String(lat),
      lon: String(lng),
      zoom: "18",
      addressdetails: "1",
    });
  } catch (e) {
    console.error("[GEOCODE_REVERSE_FAILED]", e);
    throw new HttpsError("unavailable", "Address lookup is unavailable right now.");
  }

  const address = body?.address ?? {};
  const result = {
    road: String(address.road ?? address.suburb ?? address.neighbourhood ?? ""),
    mandal: String(address.county ?? address.suburb ?? address.neighbourhood ?? ""),
    district: String(address.state_district ?? address.county ?? address.state ?? ""),
    pincode: String(address.postcode ?? ""),
    label: String(body?.display_name ?? ""),
  };
  await writeGeocodeCache(cacheKey, result);
  return result;
});

/** Address / landmark search inside the delivery area, so a customer who can't
 * (or won't) use GPS can still find their house. */
export const searchAddress = onCall({ region: REGION, enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  await checkRateLimit(uid, "geocode");

  const query = String(request.data?.query ?? "").trim().replace(/\s+/g, " ");
  if (query.length < 3 || query.length > 100) {
    throw new HttpsError("invalid-argument", "Enter at least 3 characters to search.");
  }

  const configSnap = await db.collection("config").doc("app").get();
  const zones = deliveryZonesFromConfig(configSnap.exists ? (configSnap.data() as FirebaseFirestore.DocumentData) : {});

  // Bound the search to the delivery area (each zone's circle, as a box) so
  // suggestions are places we can actually reach.
  const degPerMeterLat = 1 / 111_320;
  let west = Infinity, east = -Infinity, south = Infinity, north = -Infinity;
  for (const z of zones) {
    const dLat = z.radiusMeters * degPerMeterLat;
    const dLng = z.radiusMeters * degPerMeterLat / Math.max(Math.cos((z.latitude * Math.PI) / 180), 0.01);
    west = Math.min(west, z.longitude - dLng);
    east = Math.max(east, z.longitude + dLng);
    south = Math.min(south, z.latitude - dLat);
    north = Math.max(north, z.latitude + dLat);
  }

  const cacheKey = `q_${createHash("sha1").update(`${query.toLowerCase()}|${west}|${south}|${east}|${north}`).digest("hex")}`;
  let places = await readGeocodeCache(cacheKey);
  if (!places) {
    let body: any;
    try {
      body = await geocoderGet("/search", {
        q: query,
        limit: String(SEARCH_RESULT_LIMIT),
        countrycodes: "in",
        viewbox: `${west},${north},${east},${south}`,
        bounded: "1",
      });
    } catch (e) {
      console.error("[GEOCODE_SEARCH_FAILED]", e);
      throw new HttpsError("unavailable", "Address search is unavailable right now.");
    }
    places = (Array.isArray(body) ? body : [])
      .map((r: any) => ({
        label: String(r?.display_name ?? "").trim(),
        lat: Number(r?.lat),
        lng: Number(r?.lon),
      }))
      .filter((p: any) => p.label && isValidCoordinate(p.lat, p.lng))
      .slice(0, SEARCH_RESULT_LIMIT);
    await writeGeocodeCache(cacheKey, places);
  }

  return {
    places: places.map((p: any) => {
      const resolved = resolveDeliveryZone(p.lat, p.lng, zones);
      return { ...p, zone: resolved.zone?.name ?? null };
    }),
  };
});

/**
 * Computes a signed Cloudinary upload signature server-side so the API
 * secret never ships inside the client binary. Admin-only — the only
 * current image uploads (product photos, banners) are admin actions.
 */
export const getCloudinarySignature = onCall(
  { region: REGION, secrets: [cloudinaryApiSecret, cloudinaryApiKey], enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" },
  async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  await checkRateLimit(uid, "getCloudinarySignature");

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
      apiKey: cloudinaryApiKey.value(),
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
      const count = Number(order.broadcastCount ?? 1);

      if (count >= MAX_BROADCASTS) {
        // Stop pushing. Push notifiedAt far into the future so this order
        // drops out of the `notifiedAt <= cutoff` query (and out of the batch
        // limit) instead of being re-evaluated every minute.
        await doc.ref.set({
          broadcastExhausted: true,
          notifiedAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 3600 * 1000),
        }, { merge: true });
        console.warn(`[BROADCAST_EXHAUSTED] order ${doc.id} unaccepted after ${count} broadcasts.`);
        continue;
      }

      await sendPushToTokens(
        tokens,
        "Delivery still needed nearby",
        `Order from ${firstName(order.customerName)} in ${order.village ?? ""} is still waiting for a rider.`,
        { orderId: doc.id, type: "new_order_offer" },
        tokenOwners
      );

      await doc.ref.set(
        { notifyTier: 2, notifiedAt: Timestamp.now(), broadcastCount: count + 1 },
        { merge: true }
      );
    }
  }
);

/**
 * Auto-cancels orders that have been pending (unassigned) for longer than
 * EXPIRY_HOURS. This releases stranded stock reservations — the existing
 * onOrderWritten cancellation branch handles the stock release + ledger
 * write automatically.
 *
 * Runs every 30 minutes. Processes at most ESCALATOR_BATCH_LIMIT orders
 * per invocation to stay within the Functions timeout.
 */
export const expireStaleOrders = onSchedule(
  { region: REGION, schedule: "every 30 minutes" },
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - EXPIRY_HOURS * 3600 * 1000);
    const stale = await db.collection("orders")
      .where("status", "==", "pending")
      .where("createdAt", "<=", cutoff)
      .limit(ESCALATOR_BATCH_LIMIT)
      .get();

    if (stale.empty) return;

    let expired = 0;
    for (const doc of stale.docs) {
      try {
        // Re-check inside a transaction: a rider may have accepted between the
        // query above and this write, and a blind set() would cancel an order
        // that is already assigned.
        const didExpire = await db.runTransaction(async (tx) => {
          const snap = await tx.get(doc.ref);
          const order = snap.data();
          if (!order || order.status !== "pending" || order.deliveryBoyId) return false;
          tx.update(doc.ref, {
            status: "cancelled",
            cancelReason: "auto_expired",
            cancelledBy: "system",
            updatedAt: Timestamp.now(),
          });
          return true;
        });
        if (didExpire) expired++;
      } catch (e) {
        console.error(`[EXPIRE_FAILED] order ${doc.id}:`, e);
      }
    }

    if (expired > 0) {
      console.log(`[EXPIRE_STALE] Cancelled ${expired} stale pending orders.`);
    }
  }
);

/**
 * Permanently deletes the authenticated user's account and scrubs PII from
 * Firestore. Required by Google Play policy and DPDP Act 2023.
 * Retains order documents intact for tax/accounting requirements.
 */
export const deleteAccount = onCall(
  { region: REGION, enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to delete your account.");
    }
    await checkRateLimit(uid, "deleteAccount");

    // Rider and admin logins are provisioned and removed by an administrator.
    // Letting one delete its own auth user would strand its deliveryBoys /
    // admins doc and any orders it is carrying.
    if (request.auth?.token?.delivery === true || request.auth?.token?.admin === true) {
      throw new HttpsError(
        "permission-denied",
        "Rider and admin accounts are removed by an administrator."
      );
    }

    // An in-flight order still needs its address, phone and OTP to be delivered.
    const activeSnap = await db.collection("orders")
      .where("customerId", "==", uid)
      .where("status", "in", ACTIVE_ORDER_STATUSES)
      .limit(1)
      .get();
    if (!activeSnap.empty) {
      throw new HttpsError(
        "failed-precondition",
        "You have an order in progress. Delete your account after it is delivered or cancelled."
      );
    }

    const userRef = db.collection("users").doc(uid);
    const userSnap = await userRef.get();

    // Scrub the identifying fields from the customer's orders. Amounts, items
    // and dates stay for tax/accounting; name, phone, address, notes and the
    // map pin — which identify a person — do not.
    const ordersSnap = await db.collection("orders").where("customerId", "==", uid).get();
    for (let i = 0; i < ordersSnap.docs.length; i += 400) {
      const batch = db.batch();
      for (const orderDoc of ordersSnap.docs.slice(i, i + 400)) {
        batch.update(orderDoc.ref, {
          customerName: "Deleted User",
          customerPhone: "",
          deliveryAddress: "",
          deliveryInstructions: null,
          latitude: null,
          longitude: null,
          customerAnonymized: true,
        });
      }
      await batch.commit();
    }

    // Support conversations are free text full of personal details — delete
    // them outright (ticket + messages).
    const ticketsSnap = await db.collection("supportTickets").where("customerId", "==", uid).get();
    for (const ticketDoc of ticketsSnap.docs) {
      await db.recursiveDelete(ticketDoc.ref);
    }

    await db.collection("orderLocks").doc(uid).delete();

    if (userSnap.exists) {
      // Anonymize the profile and drop everything else the user stored on it.
      await userRef.set({
        uid,
        name: "Deleted User",
        email: "",
        phone: "",
        role: "customer",
        isActive: false,
        isDeleted: true,
        deletedAt: Timestamp.now(),
        addresses: [],
        fcmTokens: [],
        favoriteProductIds: [],
        cart: FieldValue.delete(),
        avatarUrl: null,
        village: "",
        mandal: "",
        district: "",
        updatedAt: Timestamp.now(),
      }, { merge: true });
    }

    // Delete user from Firebase Auth. Done last: every step above is
    // idempotent, so if this fails the user can simply retry the deletion.
    try {
      await getAuth().deleteUser(uid);
    } catch (e) {
      console.error(`Failed to delete Firebase Auth user ${uid}:`, e);
      throw new HttpsError("internal", "Failed to delete authentication user.");
    }

    return { success: true };
  }
);


