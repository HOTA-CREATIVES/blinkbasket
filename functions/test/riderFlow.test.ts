import {
  acceptOrder,
  advanceOrderStatus,
  regenerateDeliveryOtp,
  verifyDeliveryOtp,
} from "../src/index";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { clearFirestore, callableRequest } from "./testUtils";

const db = getFirestore();

// The customer's pin (Bhimavaram) and points near / far from it.
const PIN = { latitude: 16.546, longitude: 81.5225 };
const NEAR = { lat: 16.5461, lng: 81.5226, accuracy: 12 }; // ~15 m away
const FAR = { lat: 16.6, lng: 81.6, accuracy: 20 }; // several km away

async function seedRider(uid: string, overrides: Record<string, unknown> = {}) {
  await db.collection("deliveryBoys").doc(uid).set({
    name: "Test Rider",
    phone: "9999999999",
    isActive: true,
    onDuty: true,
    village: "Bhimavaram",
    ...overrides,
  });
}

async function seedOrder(
  orderId: string,
  overrides: Record<string, unknown> = {},
  secret: Record<string, unknown> | null = { otp: "1234", attempts: 0 }
) {
  await db.collection("orders").doc(orderId).set({
    customerId: "cust1",
    customerName: "Asha",
    status: "assigned",
    deliveryBoyId: "rider1",
    village: "Bhimavaram",
    items: [],
    totalAmount: 130,
    ...PIN,
    ...overrides,
  });
  if (secret) {
    await db.collection("orders").doc(orderId).collection("private").doc("delivery").set(secret);
  }
}

const readOrder = async (id: string) => (await db.collection("orders").doc(id).get()).data() ?? {};
const readSecret = async (id: string) =>
  (await db.collection("orders").doc(id).collection("private").doc("delivery").get()).data() ?? {};

beforeEach(async () => {
  await clearFirestore();
  await seedRider("rider1");
});

describe("acceptOrder capacity", () => {
  const accept = (orderId: string, uid = "rider1") =>
    acceptOrder.run(callableRequest({ orderId }, uid, { delivery: true }));

  it("lets a rider hold up to the default limit, then refuses another", async () => {
    for (const [i, status] of ["assigned", "picked_up", "out_for_delivery"].entries()) {
      await seedOrder(`held${i}`, { status });
    }
    await seedOrder("open", { status: "pending", deliveryBoyId: null });

    await expect(accept("open")).rejects.toThrow(/already have 3 active deliveries/);

    const order = await readOrder("open");
    expect(order.status).toBe("pending");
    expect(order.deliveryBoyId).toBeNull();
  });

  it("accepts when the rider is under the limit", async () => {
    await seedOrder("held0", { status: "assigned" });
    await seedOrder("held1", { status: "picked_up" });
    await seedOrder("open", { status: "pending", deliveryBoyId: null });

    await accept("open");
    expect((await readOrder("open")).deliveryBoyId).toBe("rider1");
  });

  it("does not count delivered, cancelled or other riders' orders", async () => {
    await seedOrder("d", { status: "delivered" });
    await seedOrder("c", { status: "cancelled" });
    await seedOrder("other1", { status: "assigned", deliveryBoyId: "rider2" });
    await seedOrder("other2", { status: "assigned", deliveryBoyId: "rider2" });
    await seedOrder("other3", { status: "assigned", deliveryBoyId: "rider2" });
    await seedOrder("open", { status: "pending", deliveryBoyId: null });

    await accept("open");
    expect((await readOrder("open")).deliveryBoyId).toBe("rider1");
  });

  it("honours config.maxActiveOrdersPerRider", async () => {
    await db.collection("config").doc("app").set({ maxActiveOrdersPerRider: 1 });
    await seedOrder("held0", { status: "assigned" });
    await seedOrder("open", { status: "pending", deliveryBoyId: null });

    await expect(accept("open")).rejects.toThrow(/already have 1 active deliver/);
  });

  it("ignores a nonsensical configured limit and uses the default", async () => {
    await db.collection("config").doc("app").set({ maxActiveOrdersPerRider: 0 });
    await seedOrder("open", { status: "pending", deliveryBoyId: null });
    await accept("open");
    expect((await readOrder("open")).deliveryBoyId).toBe("rider1");
  });

  it("a retry by the rider who already holds the order still succeeds at capacity", async () => {
    for (const [i, status] of ["assigned", "picked_up", "out_for_delivery"].entries()) {
      await seedOrder(`held${i}`, { status });
    }
    const result = await accept("held0");
    expect(result.success).toBe(true);
  });

  it("lets exactly one of two simultaneous accepts through when only one slot is left", async () => {
    await seedOrder("held0", { status: "assigned" });
    await seedOrder("held1", { status: "assigned" });
    await seedOrder("open1", { status: "pending", deliveryBoyId: null });
    await seedOrder("open2", { status: "pending", deliveryBoyId: null });

    const results = await Promise.allSettled([accept("open1"), accept("open2")]);

    expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    const held = await db.collection("orders").where("deliveryBoyId", "==", "rider1").get();
    expect(held.size).toBe(3);
  });
});

describe("advanceOrderStatus", () => {
  const advance = (data: Record<string, unknown>, uid = "rider1") =>
    advanceOrderStatus.run(callableRequest(data, uid, { delivery: true }));

  it("moves assigned → picked_up, recording when and where", async () => {
    await seedOrder("o1");

    const result = await advance({ orderId: "o1", location: NEAR });

    expect(result).toEqual({ success: true, status: "picked_up" });
    const order = await readOrder("o1");
    expect(order.status).toBe("picked_up");
    expect(order.pickedUpAt).toBeInstanceOf(Timestamp);
    expect(order.pickupLocation).toMatchObject({ lat: NEAR.lat, lng: NEAR.lng, accuracy: 12 });
  });

  it("moves picked_up → out_for_delivery and starts the delivery code's validity window", async () => {
    await seedOrder("o1", { status: "picked_up" });
    const before = Date.now();

    await advance({ orderId: "o1", location: NEAR });

    const order = await readOrder("o1");
    expect(order.status).toBe("out_for_delivery");
    expect(order.outForDeliveryAt).toBeInstanceOf(Timestamp);
    expect(order.dispatchLocation).toMatchObject({ lat: NEAR.lat });
    const expiresAt = (await readSecret("o1")).expiresAt as Timestamp;
    expect(expiresAt.toMillis()).toBeGreaterThan(before + 119 * 60_000);
    expect(expiresAt.toMillis()).toBeLessThan(before + 121 * 60_000);
    expect((await readSecret("o1")).otp).toBe("1234");
  });

  it("works without a location (GPS off) and records that no fix was taken", async () => {
    await seedOrder("o1");
    await advance({ orderId: "o1" });
    const order = await readOrder("o1");
    expect(order.status).toBe("picked_up");
    expect(order.pickupLocation).toBeNull();
  });

  it.each([
    [{ lat: "16.5", lng: 81.5 }],
    [{ lat: 16.5 }],
    [{ lat: 95, lng: 81.5 }],
    [{ lat: 16.5, lng: 400 }],
    ["here"],
  ])("rejects a malformed location %p without moving the order", async (location) => {
    await seedOrder("o1");
    await expect(advance({ orderId: "o1", location })).rejects.toThrow(/location .* invalid/);
    expect((await readOrder("o1")).status).toBe("assigned");
  });

  it("never goes straight to delivered, and won't skip a step", async () => {
    await seedOrder("o1");
    await expect(advance({ orderId: "o1", status: "delivered" })).rejects.toThrow(/next step .* 'picked_up'/);
    await expect(advance({ orderId: "o1", status: "out_for_delivery" })).rejects.toThrow(/next step/);
    expect((await readOrder("o1")).status).toBe("assigned");
  });

  it("refuses an order that is out for delivery (delivered is the OTP path's alone)", async () => {
    await seedOrder("o1", { status: "out_for_delivery" });
    await expect(advance({ orderId: "o1" })).rejects.toThrow(/can't be moved on/);
  });

  it("tells the rider when the order was cancelled under them", async () => {
    await seedOrder("o1", { status: "cancelled" });
    await expect(advance({ orderId: "o1" })).rejects.toThrow(/was cancelled/);
  });

  it("only the assigned rider may advance it", async () => {
    await seedOrder("o1");
    await seedRider("rider2");
    await expect(advance({ orderId: "o1" }, "rider2")).rejects.toThrow(/isn't assigned to you/);
    expect((await readOrder("o1")).status).toBe("assigned");
  });

  it("refuses a deactivated rider", async () => {
    await seedOrder("o1");
    await seedRider("rider1", { isActive: false });
    await expect(advance({ orderId: "o1" })).rejects.toThrow(/deactivated/);
  });

  it("is idempotent when a retry names the status the order is already in", async () => {
    await seedOrder("o1");
    await advance({ orderId: "o1", status: "picked_up" });
    const again = await advance({ orderId: "o1", status: "picked_up" });
    expect(again.status).toBe("picked_up");
    expect((await readOrder("o1")).status).toBe("picked_up");
  });

  it("requires sign-in and an order id, and reports a missing order", async () => {
    await expect(
      advanceOrderStatus.run(callableRequest({ orderId: "o1" }, null))
    ).rejects.toThrow(/Sign in/);
    await expect(advance({})).rejects.toThrow(/orderId is required/);
    await expect(advance({ orderId: "nope" })).rejects.toThrow(/not found/);
  });
});

describe("delivery code expiry and regeneration", () => {
  const verify = (data: Record<string, unknown>, uid = "rider1") =>
    verifyDeliveryOtp.run(callableRequest({ collectedAmount: 130, ...data }, uid, { delivery: true }));
  const regenerate = (data: Record<string, unknown>, uid = "cust1") =>
    regenerateDeliveryOtp.run(callableRequest(data, uid));
  const minutes = (m: number) => Timestamp.fromMillis(Date.now() + m * 60_000);

  it("delivers with a code that has not expired", async () => {
    await seedOrder("o1", { status: "out_for_delivery" }, { otp: "1234", attempts: 0, expiresAt: minutes(30) });
    await verify({ orderId: "o1", otp: "1234" });
    expect((await readOrder("o1")).status).toBe("delivered");
  });

  it("refuses an expired code without spending an attempt, even with the right digits", async () => {
    await seedOrder("o1", { status: "out_for_delivery" }, { otp: "1234", attempts: 0, expiresAt: minutes(-5) });

    await expect(verify({ orderId: "o1", otp: "1234" })).rejects.toThrow(/has expired.*new code/);
    await expect(verify({ orderId: "o1", otp: "0000" })).rejects.toThrow(/has expired/);

    expect((await readOrder("o1")).status).toBe("out_for_delivery");
    expect((await readSecret("o1")).attempts).toBe(0);
  });

  it("treats an order with no expiry (placed before this existed) as valid", async () => {
    await seedOrder("o1", { status: "out_for_delivery" }, { otp: "1234", attempts: 0 });
    await verify({ orderId: "o1", otp: "1234" });
    expect((await readOrder("o1")).status).toBe("delivered");
  });

  describe("regenerateDeliveryOtp", () => {
    it("gives the customer a new code, invalidating the old one", async () => {
      await seedOrder("o1", { status: "picked_up" }, { otp: "1234", attempts: 0 });

      const { otp } = await regenerate({ orderId: "o1" });

      expect(otp).toMatch(/^\d{4}$/);
      expect((await readSecret("o1")).otp).toBe(otp);
      expect((await readSecret("o1")).regenerations).toBe(1);
    });

    it("clears failed attempts and any lockout", async () => {
      await seedOrder(
        "o1",
        { status: "out_for_delivery" },
        { otp: "1234", attempts: 4, totalAttempts: 9, lockedUntil: minutes(8) }
      );

      await regenerate({ orderId: "o1" });

      const secret = await readSecret("o1");
      expect(secret.attempts).toBe(0);
      expect(secret.totalAttempts).toBe(0);
      expect(secret.lockedUntil).toBeNull();
    });

    it("restarts the validity window for an order already out for delivery, rescuing an expired code", async () => {
      await seedOrder("o1", { status: "out_for_delivery" }, { otp: "1234", attempts: 0, expiresAt: minutes(-30) });

      const result = await regenerate({ orderId: "o1" });

      expect(result.expiresAtMs).toBeGreaterThan(Date.now() + 100 * 60_000);
      await verify({ orderId: "o1", otp: result.otp });
      expect((await readOrder("o1")).status).toBe("delivered");
    });

    it("does not set an expiry before the order is out for delivery", async () => {
      await seedOrder("o1", { status: "assigned" }, { otp: "1234", attempts: 0 });
      const result = await regenerate({ orderId: "o1" });
      expect(result.expiresAtMs).toBeNull();
    });

    it("the old code stops working", async () => {
      await seedOrder("o1", { status: "out_for_delivery" }, { otp: "1234", attempts: 0 });
      // Force a different code so this can't pass by coincidence.
      await db.collection("orders").doc("o1").collection("private").doc("delivery").update({ otp: "1111" });
      const { otp } = await regenerate({ orderId: "o1" });
      const stale = otp === "1111" ? "2222" : "1111";

      await expect(verify({ orderId: "o1", otp: stale })).rejects.toThrow(/Incorrect delivery OTP/);
    });

    it("is for the ordering customer only", async () => {
      await seedOrder("o1", { status: "assigned" });
      await expect(regenerate({ orderId: "o1" }, "cust2")).rejects.toThrow(/your own orders/);
      await expect(regenerate({ orderId: "o1" }, "rider1")).rejects.toThrow(/your own orders/);
    });

    it.each(["pending", "delivered", "cancelled"])("refuses while the order is %s", async (status) => {
      await seedOrder("o1", { status, deliveryBoyId: status === "pending" ? null : "rider1" });
      await expect(regenerate({ orderId: "o1" })).rejects.toThrow(
        status === "pending" ? /hasn't accepted/ : /closed/
      );
    });

    it("stops after too many refreshes", async () => {
      await seedOrder("o1", { status: "assigned" }, { otp: "1234", attempts: 0, regenerations: 5 });
      await expect(regenerate({ orderId: "o1" })).rejects.toThrow(/too many times/);
    });

    it("requires sign-in and an order id", async () => {
      await expect(regenerate({ orderId: "o1" }, null as unknown as string)).rejects.toThrow(/Sign in/);
      await expect(regenerate({})).rejects.toThrow(/orderId is required/);
      await expect(regenerate({ orderId: "nope" })).rejects.toThrow(/not found/);
    });
  });
});

describe("proof of delivery", () => {
  const verify = (data: Record<string, unknown>) =>
    verifyDeliveryOtp.run(callableRequest({ collectedAmount: 130, ...data }, "rider1", { delivery: true }));

  it("records where the handover happened and how far that was from the customer's pin", async () => {
    await seedOrder("o1", { status: "out_for_delivery" });

    await verify({ orderId: "o1", otp: "1234", location: NEAR });

    const order = await readOrder("o1");
    expect(order.deliveryLocation).toMatchObject({ lat: NEAR.lat, lng: NEAR.lng });
    expect(order.deliveryDistanceMeters).toBeLessThan(50);
    expect(order.deliveryFar).toBe(false);
  });

  it("flags — but does not block — a handover far from the pin", async () => {
    await seedOrder("o1", { status: "out_for_delivery" });

    await verify({ orderId: "o1", otp: "1234", location: FAR });

    const order = await readOrder("o1");
    expect(order.status).toBe("delivered");
    expect(order.deliveryFar).toBe(true);
    expect(order.deliveryDistanceMeters).toBeGreaterThan(500);
  });

  it("still delivers without a location, recording none", async () => {
    await seedOrder("o1", { status: "out_for_delivery" });
    await verify({ orderId: "o1", otp: "1234" });
    const order = await readOrder("o1");
    expect(order.status).toBe("delivered");
    expect(order.deliveryLocation).toBeUndefined();
  });

  it("rejects a malformed location rather than ignoring it", async () => {
    await seedOrder("o1", { status: "out_for_delivery" });
    await expect(
      verify({ orderId: "o1", otp: "1234", location: { lat: 999, lng: 1 } })
    ).rejects.toThrow(/location .* invalid/);
    expect((await readOrder("o1")).status).toBe("out_for_delivery");
  });

  it("records the location but no distance when the order has no pin", async () => {
    await seedOrder("o1", { status: "out_for_delivery", latitude: null, longitude: null });
    await verify({ orderId: "o1", otp: "1234", location: NEAR });
    const order = await readOrder("o1");
    expect(order.deliveryLocation).toMatchObject({ lat: NEAR.lat });
    expect(order.deliveryDistanceMeters).toBeNull();
    expect(order.deliveryFar).toBe(false);
  });
});
