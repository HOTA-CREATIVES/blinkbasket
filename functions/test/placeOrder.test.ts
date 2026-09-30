import { placeOrder } from "../src/index";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestore, callableRequest } from "./testUtils";

const db = getFirestore();

// ~180 m from the Bhimavaram centroid (16.5449, 81.5212) — a plausible house
// pin. The centroid itself is rejected as an "unpinned" placeholder.
const PIN = { latitude: 16.546, longitude: 81.5225 };

async function seedUser(uid: string, overrides: Record<string, unknown> = {}) {
  await db.collection("users").doc(uid).set({
    name: "Test Customer",
    phone: "9876543210",
    village: "Bhimavaram",
    role: "customer",
    isActive: true,
    ...overrides,
  });
}

async function seedProduct(id: string, overrides: Record<string, unknown> = {}) {
  await db.collection("products").doc(id).set({
    name: "Test Product",
    price: 50,
    physicalStock: 10,
    reservedStock: 0,
    availableStock: 10,
    ...overrides,
  });
}

async function seedConfig(overrides: Record<string, unknown> = {}) {
  await db.collection("config").doc("app").set({
    storeOpen: true,
    deliveryFee: 30,
    freeDeliveryAbove: 300,
    ...overrides,
  });
}

function order(
  uid: string,
  extra: Record<string, unknown> = {},
  tokenOverrides: Record<string, unknown> = {}
) {
  return callableRequest(
    {
      items: [{ productId: "prod1", quantity: 1 }],
      deliveryAddress: "Addr",
      ...PIN,
      ...extra,
    },
    uid,
    { email_verified: true, ...tokenOverrides }
  );
}

// placeOrder rate-limits per uid (20 calls / minute, in memory). This file makes
// more than that as "cust1", so each test runs a minute later on a fake clock —
// the limiter's window resets without the tests depending on its size.
let fakeNow = Date.now();

describe("placeOrder", () => {
  beforeEach(async () => {
    fakeNow += 61_000;
    jest.spyOn(Date, "now").mockImplementation(() => fakeNow);
    await clearFirestore();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("computes totals server-side and decrements stock, ignoring any client-sent price", async () => {
    await seedUser("cust1");
    await seedProduct("prod1", { price: 50, physicalStock: 10, availableStock: 10 });
    await seedConfig();

    const result = await placeOrder.run(
      order("cust1", {
        items: [{ productId: "prod1", quantity: 2, price: 1 }],
        deliveryAddress: "12 Main Street, Bhimavaram",
      })
    );

    expect(result.subtotal).toBe(100);
    expect(result.deliveryFee).toBe(30);
    expect(result.totalAmount).toBe(130);
    expect(result.otp).toMatch(/^\d{4}$/);

    const productSnap = await db.collection("products").doc("prod1").get();
    expect(productSnap.data()?.reservedStock).toBe(2);
    expect(productSnap.data()?.availableStock).toBe(8);

    const orderSnap = await db.collection("orders").doc(result.orderId).get();
    expect(orderSnap.data()?.status).toBe("pending");
    expect(orderSnap.data()?.items[0].price).toBe(50);
  });

  describe("idempotency (requestId)", () => {
    it("returns the existing order on a retry instead of failing or double-reserving", async () => {
      await seedUser("cust1");
      await seedProduct("prod1", { price: 50, physicalStock: 10, availableStock: 10 });
      await seedConfig();

      const first = await placeOrder.run(order("cust1", { requestId: "req-abc-12345" }));
      const retry = await placeOrder.run(order("cust1", { requestId: "req-abc-12345" }));

      expect(retry.orderId).toBe(first.orderId);
      expect(retry.otp).toBe(first.otp);
      expect(retry.totalAmount).toBe(first.totalAmount);
      expect(retry.deduplicated).toBe(true);

      const orders = await db.collection("orders").where("customerId", "==", "cust1").get();
      expect(orders.size).toBe(1);
      const productSnap = await db.collection("products").doc("prod1").get();
      expect(productSnap.data()?.reservedStock).toBe(1);
    });

    it("does not let a different customer collide on the same requestId", async () => {
      await seedUser("cust1");
      await seedUser("cust2");
      await seedProduct("prod1", { price: 50, physicalStock: 10, availableStock: 10 });
      await seedConfig();

      const a = await placeOrder.run(order("cust1", { requestId: "req-abc-12345" }));
      const b = await placeOrder.run(order("cust2", { requestId: "req-abc-12345" }));
      expect(b.orderId).not.toBe(a.orderId);
    });

    it("rejects a malformed requestId", async () => {
      await seedUser("cust1");
      await seedProduct("prod1");
      await seedConfig();
      await expect(
        placeOrder.run(order("cust1", { requestId: "bad id!" }))
      ).rejects.toThrow(/Invalid request id/);
    });
  });

  it("waives the delivery fee once the subtotal exceeds the free-delivery threshold", async () => {
    await seedUser("cust1");
    await seedProduct("prod1", { price: 200, availableStock: 10 });
    await seedConfig({ freeDeliveryAbove: 300 });

    const result = await placeOrder.run(
      order("cust1", { items: [{ productId: "prod1", quantity: 2 }] })
    );

    expect(result.subtotal).toBe(400);
    expect(result.deliveryFee).toBe(0);
    expect(result.totalAmount).toBe(400);
  });

  it("rejects when requested quantity exceeds available stock", async () => {
    await seedUser("cust1");
    await seedProduct("prod1", { physicalStock: 1, availableStock: 1 });
    await seedConfig();

    await expect(
      placeOrder.run(order("cust1", { items: [{ productId: "prod1", quantity: 5 }] }))
    ).rejects.toThrow(/only 1 units available/);
  });

  it("derives availability from physical - reserved, not the stored availableStock", async () => {
    await seedUser("cust1");
    // availableStock was hand-edited to 10 but 9 of 10 units are reserved.
    await seedProduct("prod1", { physicalStock: 10, reservedStock: 9, availableStock: 10 });
    await seedConfig();

    await expect(
      placeOrder.run(order("cust1", { items: [{ productId: "prod1", quantity: 2 }] }))
    ).rejects.toThrow(/only 1 units available/);
  });

  it("blocks prescription medicines (no verification flow exists) and reserves nothing", async () => {
    await seedUser("cust1");
    await seedProduct("prod1", { name: "Antibiotic", requiresPrescription: true });
    await seedConfig();

    await expect(placeOrder.run(order("cust1"))).rejects.toThrow(/prescription medicine/);

    const productSnap = await db.collection("products").doc("prod1").get();
    expect(productSnap.data()?.reservedStock).toBe(0);
  });

  it("rejects a product the admin switched off with isAvailable=false (what the app's flag writes)", async () => {
    await seedUser("cust1");
    await seedProduct("prod1", { isAvailable: false });
    await seedConfig();

    await expect(placeOrder.run(order("cust1"))).rejects.toThrow(/not currently available/);
    const productSnap = await db.collection("products").doc("prod1").get();
    expect(productSnap.data()?.reservedStock).toBe(0);
  });

  describe("discounted pricing", () => {
    it("charges the discounted price the app displays and records the list price", async () => {
      await seedUser("cust1");
      await seedProduct("prod1", { price: 100, discountedPrice: 80, availableStock: 10 });
      await seedConfig({ freeDeliveryAbove: 1000 });

      const result = await placeOrder.run(
        order("cust1", { items: [{ productId: "prod1", quantity: 2 }] })
      );

      expect(result.subtotal).toBe(160);
      const orderSnap = await db.collection("orders").doc(result.orderId).get();
      expect(orderSnap.data()?.items[0].price).toBe(80);
      expect(orderSnap.data()?.items[0].listPrice).toBe(100);
    });

    it.each([
      ["equal to the list price", 100],
      ["above the list price", 150],
      ["zero", 0],
      ["negative", -5],
      ["not a number", "80"],
    ])("ignores a discount that is %s and charges the list price", async (_label, discountedPrice) => {
      await seedUser("cust1");
      await seedProduct("prod1", { price: 100, discountedPrice, availableStock: 10 });
      await seedConfig({ freeDeliveryAbove: 1000 });

      const result = await placeOrder.run(order("cust1"));
      expect(result.subtotal).toBe(100);
    });
  });

  it("rejects an inactive (deactivated) product", async () => {
    await seedUser("cust1");
    await seedProduct("prod1", { isActive: false });
    await seedConfig();

    await expect(placeOrder.run(order("cust1"))).rejects.toThrow(/not currently available/);
  });

  it("enforces the configured minimum order amount server-side", async () => {
    await seedUser("cust1");
    await seedProduct("prod1", { price: 50 });
    await seedConfig({ minimumOrderAmount: 100 });

    await expect(placeOrder.run(order("cust1"))).rejects.toThrow(/Minimum order amount is ₹100/);

    // Nothing was reserved by the rejected attempt.
    const productSnap = await db.collection("products").doc("prod1").get();
    expect(productSnap.data()?.reservedStock).toBe(0);
  });

  it("rejects duplicate products in the same order", async () => {
    await seedUser("cust1");
    await seedProduct("prod1");
    await seedConfig();

    await expect(
      placeOrder.run(
        order("cust1", {
          items: [
            { productId: "prod1", quantity: 1 },
            { productId: "prod1", quantity: 1 },
          ],
        })
      )
    ).rejects.toThrow(/Duplicate product/);
  });

  it("rejects a product with a zero or missing price rather than charging nothing for it", async () => {
    await seedUser("cust1");
    await seedProduct("prod1", { price: 0 });
    await seedConfig();

    await expect(placeOrder.run(order("cust1"))).rejects.toThrow(/not currently available/);
  });

  it("rejects when the store is closed", async () => {
    await seedUser("cust1");
    await seedProduct("prod1");
    await seedConfig({ storeOpen: false });

    await expect(placeOrder.run(order("cust1"))).rejects.toThrow(/store is currently closed/);
  });

  it("rejects while the store is in maintenance mode", async () => {
    await seedUser("cust1");
    await seedProduct("prod1");
    await seedConfig({ maintenanceMode: true });

    await expect(placeOrder.run(order("cust1"))).rejects.toThrow(/under maintenance/);
  });

  it("rejects more than the max distinct items per order", async () => {
    await seedUser("cust1");
    await seedConfig();
    const items = Array.from({ length: 51 }, (_, i) => ({ productId: `p${i}`, quantity: 1 }));

    await expect(
      placeOrder.run(callableRequest({ items, deliveryAddress: "Addr" }, "cust1"))
    ).rejects.toThrow(/Too many distinct items/);
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      placeOrder.run(
        callableRequest({ items: [{ productId: "prod1", quantity: 1 }], deliveryAddress: "Addr" }, null)
      )
    ).rejects.toThrow(/Sign in/);
  });

  describe("identity checks", () => {
    beforeEach(async () => {
      await seedProduct("prod1");
    });

    it("rejects an email/password account that hasn't verified its email", async () => {
      await seedUser("cust1");
      await seedConfig();
      await expect(
        placeOrder.run(order("cust1", {}, { email_verified: false }))
      ).rejects.toThrow(/Verify your email/);
      const productSnap = await db.collection("products").doc("prod1").get();
      expect(productSnap.data()?.reservedStock).toBe(0);
    });

    it("rejects a token that doesn't carry email_verified at all", async () => {
      await seedUser("cust1");
      await seedConfig();
      await expect(
        placeOrder.run(order("cust1", {}, { email_verified: undefined }))
      ).rejects.toThrow(/Verify your email/);
    });

    it("lets an admin turn the verification requirement off", async () => {
      await seedUser("cust1");
      await seedConfig({ requireVerifiedEmail: false });
      const result = await placeOrder.run(order("cust1", {}, { email_verified: false }));
      expect(result.orderId).toBeTruthy();
    });

    it.each(["", "12345", "98765", "5876543210", "98765abcde", "98765432101"])(
      "refuses to dispatch an order whose profile phone is unusable (%p)",
      async (phone) => {
        await seedUser("cust1", { phone });
        await seedConfig();
        await expect(placeOrder.run(order("cust1"))).rejects.toThrow(/valid 10-digit mobile/);
        const productSnap = await db.collection("products").doc("prod1").get();
        expect(productSnap.data()?.reservedStock).toBe(0);
      }
    );

    it.each([
      ["9876543210", "+919876543210"],
      ["+91 98765 43210", "+919876543210"],
      ["+919876543210", "+919876543210"],
      ["09876543210", "+919876543210"],
      ["98765-43210", "+919876543210"],
    ])("stores %p as the canonical %p on the order", async (phone, stored) => {
      await seedUser("cust1", { phone });
      await seedConfig();
      const result = await placeOrder.run(order("cust1"));
      const orderSnap = await db.collection("orders").doc(result.orderId).get();
      expect(orderSnap.data()?.customerPhone).toBe(stored);
    });

    it("refuses an order when the profile has no name", async () => {
      await seedUser("cust1", { name: "  " });
      await seedConfig();
      await expect(placeOrder.run(order("cust1"))).rejects.toThrow(/Add your name/);
    });
  });

  describe("delivery location", () => {
    beforeEach(async () => {
      await seedUser("cust1");
      await seedProduct("prod1");
      await seedConfig();
    });

    it("rejects when delivery coordinates are missing", async () => {
      await expect(
        placeOrder.run(
          callableRequest(
            { items: [{ productId: "prod1", quantity: 1 }], deliveryAddress: "Addr" },
            "cust1"
          )
        )
      ).rejects.toThrow(/GPS coordinates/);
    });

    it("rejects non-finite or out-of-range coordinates", async () => {
      for (const bad of [
        { latitude: "Infinity", longitude: 81.52 },
        { latitude: 16.55, longitude: "NaN" },
        { latitude: 999, longitude: 81.52 },
        { latitude: 16.55, longitude: -500 },
      ]) {
        await expect(placeOrder.run(order("cust1", bad))).rejects.toThrow(/GPS coordinates/);
      }
    });

    it("rejects delivery coordinates far outside the service area", async () => {
      await expect(
        placeOrder.run(order("cust1", { latitude: 19.076, longitude: 72.8777 }))
      ).rejects.toThrow(/outside our service area/);
    });

    it("rejects a pin that is exactly a village centroid (map default / unpinned fallback)", async () => {
      await expect(
        placeOrder.run(order("cust1", { latitude: 16.5449, longitude: 81.5212 }))
      ).rejects.toThrow(/pin your exact delivery location/);

      // ...and nothing was reserved.
      const productSnap = await db.collection("products").doc("prod1").get();
      expect(productSnap.data()?.reservedStock).toBe(0);
    });

    it("accepts delivery coordinates within the service radius", async () => {
      const result = await placeOrder.run(order("cust1", { latitude: 16.55, longitude: 81.52 }));
      expect(result.orderId).toBeTruthy();
    });

    describe("admin-configured service zones", () => {
      // 25 km from Bhimavaram, i.e. outside the built-in 12 km village radius.
      const FAR = { latitude: 16.77, longitude: 81.52 };
      const zone = (over: Record<string, unknown> = {}) => ({
        name: "Palakollu",
        lat: 16.77,
        lng: 81.53,
        radiusKm: 5,
        ...over,
      });

      it("accepts a pin inside an admin-added zone the built-in list doesn't cover", async () => {
        await seedConfig({ serviceZones: [zone()] });
        const result = await placeOrder.run(order("cust1", FAR));
        const orderSnap = await db.collection("orders").doc(result.orderId).get();
        expect(orderSnap.data()?.village).toBe("Palakollu");
      });

      it("uses the zone's own radius, rejecting a pin just outside it", async () => {
        await seedConfig({ serviceZones: [zone({ radiusKm: 0.2 })] });
        await expect(placeOrder.run(order("cust1", FAR))).rejects.toThrow(/outside our service area/);
      });

      it("stops serving a village the admin removed from the zone list", async () => {
        await seedConfig({ serviceZones: [zone()] });
        await expect(
          placeOrder.run(order("cust1", { latitude: 16.55, longitude: 81.52 }))
        ).rejects.toThrow(/outside our service area/);
      });

      it("falls back to the built-in villages when the configured zones are unusable", async () => {
        await seedConfig({ serviceZones: [{ name: "", lat: "x", lng: null, radiusKm: -1 }] });
        const result = await placeOrder.run(order("cust1", { latitude: 16.55, longitude: 81.52 }));
        expect(result.orderId).toBeTruthy();
      });

      it("still rejects a pin that is exactly a configured zone centre", async () => {
        await seedConfig({ serviceZones: [zone()] });
        await expect(
          placeOrder.run(order("cust1", { latitude: 16.77, longitude: 81.53 }))
        ).rejects.toThrow(/pin your exact/);
      });
    });

    it("derives the order's village from the pin, not the profile village", async () => {
      // Profile says Mentada, but the customer pinned a spot in Bhimavaram.
      await seedUser("cust1", { village: "Mentada" });

      const result = await placeOrder.run(order("cust1", PIN));

      const orderSnap = await db.collection("orders").doc(result.orderId).get();
      expect(orderSnap.data()?.village).toBe("Bhimavaram");
      expect(orderSnap.data()?.latitude).toBe(PIN.latitude);
      expect(orderSnap.data()?.longitude).toBe(PIN.longitude);
    });
  });

  describe("one active order per customer", () => {
    // Fresh uid per test: placeOrder's in-memory rate limiter (20 calls/min
    // per uid) is shared across this whole file, so reusing "cust1" here
    // would trip it and mask what these tests are checking.
    let uid = "";
    let n = 0;

    beforeEach(async () => {
      uid = `activeCust${++n}`;
      await seedUser(uid);
      await seedProduct("prod1", { physicalStock: 10, availableStock: 10 });
      await seedConfig();
    });

    it("rejects a second order while the first is still active", async () => {
      await placeOrder.run(order(uid));

      await expect(placeOrder.run(order(uid))).rejects.toThrow(/already have an active order/);
    });

    it("lets exactly one of two concurrent requests through (no double-tap / two-device race)", async () => {
      const outcomes = await Promise.allSettled([
        placeOrder.run(order(uid)),
        placeOrder.run(order(uid)),
      ]);

      expect(outcomes.filter((o) => o.status === "fulfilled")).toHaveLength(1);
      const rejected = outcomes.filter((o) => o.status === "rejected") as PromiseRejectedResult[];
      expect(rejected).toHaveLength(1);
      expect(rejected[0].reason.message).toMatch(/already have an active order/);

      const orders = await db.collection("orders").where("customerId", "==", uid).get();
      expect(orders.size).toBe(1);

      // Only one order's worth of stock is reserved.
      const productSnap = await db.collection("products").doc("prod1").get();
      expect(productSnap.data()?.reservedStock).toBe(1);
    });

    it("allows a new order once the previous one is delivered (lock self-heals)", async () => {
      const first = await placeOrder.run(order(uid));
      await db.collection("orders").doc(first.orderId).update({ status: "delivered" });

      const second = await placeOrder.run(order(uid));
      expect(second.orderId).not.toBe(first.orderId);
    });

    it("allows a new order once the previous one is cancelled", async () => {
      const first = await placeOrder.run(order(uid));
      await db.collection("orders").doc(first.orderId).update({ status: "cancelled" });

      const second = await placeOrder.run(order(uid));
      expect(second.orderId).not.toBe(first.orderId);
    });
  });
});
