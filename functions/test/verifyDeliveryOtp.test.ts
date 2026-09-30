import { verifyDeliveryOtp } from "../src/index";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { clearFirestore, callableRequest } from "./testUtils";

const db = getFirestore();

async function seedOrder(
  orderId: string,
  overrides: Record<string, unknown> = {},
  secret: Record<string, unknown> = {}
) {
  await db
    .collection("orders")
    .doc(orderId)
    .set({
      customerId: "cust1",
      deliveryBoyId: "rider1",
      status: "out_for_delivery",
      items: [{ productId: "prod1", quantity: 2 }],
      totalAmount: 130,
      ...overrides,
    });
  await db
    .collection("orders")
    .doc(orderId)
    .collection("private")
    .doc("delivery")
    .set({ otp: "1234", attempts: 0, ...secret });
}

async function readSecret(orderId: string) {
  const snap = await db.collection("orders").doc(orderId).collection("private").doc("delivery").get();
  return snap.data() ?? {};
}

const minutesFromNow = (m: number) => Timestamp.fromMillis(Date.now() + m * 60_000);

describe("verifyDeliveryOtp", () => {
  beforeEach(async () => {
    await clearFirestore();
    await db.collection("products").doc("prod1").set({
      name: "Test Product",
      physicalStock: 10,
      reservedStock: 2,
      availableStock: 8,
    });
  });

  it("marks the order delivered and decrements physical stock on correct OTP", async () => {
    await seedOrder("order1");

    const result = await verifyDeliveryOtp.run(
      callableRequest({ orderId: "order1", otp: "1234" }, "rider1")
    );
    expect(result.success).toBe(true);

    const orderSnap = await db.collection("orders").doc("order1").get();
    expect(orderSnap.data()?.status).toBe("delivered");

    const productSnap = await db.collection("products").doc("prod1").get();
    expect(productSnap.data()?.physicalStock).toBe(8);
    expect(productSnap.data()?.reservedStock).toBe(0);

    const ledgerSnap = await db
      .collection("inventoryLogs")
      .where("orderId", "==", "order1")
      .get();
    expect(ledgerSnap.size).toBe(1);
    expect(ledgerSnap.docs[0].data().changeType).toBe("sale");
  });

  describe("rider payout snapshot", () => {
    it("freezes the payout rate in force at delivery onto the order", async () => {
      await db.collection("config").doc("app").set({ riderPayoutPerDelivery: 42 });
      await seedOrder("order1");

      await verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234" }, "rider1"));

      // A later rate change must not reprice the delivered order.
      await db.collection("config").doc("app").set({ riderPayoutPerDelivery: 99 });
      const snap = await db.collection("orders").doc("order1").get();
      expect(snap.data()?.riderPayout).toBe(42);
    });

    it("falls back to the default payout when none is configured", async () => {
      await seedOrder("order1");

      await verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234" }, "rider1"));

      const snap = await db.collection("orders").doc("order1").get();
      expect(snap.data()?.riderPayout).toBe(30);
    });

    it("does not record a payout when the OTP is wrong", async () => {
      await seedOrder("order1");

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "0000" }, "rider1"))
      ).rejects.toThrow();

      const snap = await db.collection("orders").doc("order1").get();
      expect(snap.data()?.riderPayout).toBeUndefined();
    });
  });

  describe("wrong OTP handling", () => {
    it("counts the attempt, tells the rider how many are left, and does not deliver", async () => {
      await seedOrder("order1");

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "0000" }, "rider1"))
      ).rejects.toThrow(/Incorrect delivery OTP\. 4 attempts left/);

      const secret = await readSecret("order1");
      expect(secret.attempts).toBe(1);
      expect(secret.totalAttempts).toBe(1);

      const orderSnap = await db.collection("orders").doc("order1").get();
      expect(orderSnap.data()?.status).toBe("out_for_delivery");
    });

    it("locks the rider out for a cooldown after the 5th wrong OTP", async () => {
      await seedOrder("order1", {}, { attempts: 4, totalAttempts: 4 });

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "0000" }, "rider1"))
      ).rejects.toThrow(/Locked for 10 minutes/);

      const secret = await readSecret("order1");
      expect(secret.attempts).toBe(0);
      expect(secret.totalAttempts).toBe(5);
      expect(secret.lockedUntil.toMillis()).toBeGreaterThan(Date.now());
    });

    it("rejects even the CORRECT OTP while the cooldown is active", async () => {
      await seedOrder("order1", {}, { attempts: 0, totalAttempts: 5, lockedUntil: minutesFromNow(7) });

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234" }, "rider1"))
      ).rejects.toThrow(/Try again in \d+ minutes?/);

      const orderSnap = await db.collection("orders").doc("order1").get();
      expect(orderSnap.data()?.status).toBe("out_for_delivery");
    });

    it("unlocks by itself once the cooldown expires — no admin needed", async () => {
      await seedOrder(
        "order1",
        {},
        { attempts: 0, totalAttempts: 5, lockedUntil: minutesFromNow(-1) }
      );

      const result = await verifyDeliveryOtp.run(
        callableRequest({ orderId: "order1", otp: "1234" }, "rider1")
      );
      expect(result.success).toBe(true);
    });

    it("gives a fresh window of attempts after the cooldown expires", async () => {
      await seedOrder(
        "order1",
        {},
        { attempts: 0, totalAttempts: 5, lockedUntil: minutesFromNow(-1) }
      );

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "0000" }, "rider1"))
      ).rejects.toThrow(/4 attempts left/);

      const secret = await readSecret("order1");
      expect(secret.attempts).toBe(1);
      expect(secret.totalAttempts).toBe(6);
      expect(secret.lockedUntil).toBeNull();
    });

    it("hard-locks after the lifetime cap until an admin resets it", async () => {
      await seedOrder("order1", {}, { attempts: 0, totalAttempts: 15, lockedUntil: minutesFromNow(-60) });

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234" }, "rider1"))
      ).rejects.toThrow(/Ask the admin to reset OTP verification/);
    });

    it("honours attempts recorded by the old schema (attempts only, no totalAttempts)", async () => {
      await seedOrder("order1", {}, { attempts: 4 });

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "0000" }, "rider1"))
      ).rejects.toThrow(/Locked for 10 minutes/);
    });
  });

  describe("idempotency", () => {
    it("a retry after the first call already delivered the order succeeds without touching stock again", async () => {
      await seedOrder("order1");

      await verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234" }, "rider1"));
      // Response was lost; the rider's app retries with the same OTP.
      const retry = await verifyDeliveryOtp.run(
        callableRequest({ orderId: "order1", otp: "1234" }, "rider1")
      );
      expect(retry.success).toBe(true);

      const productSnap = await db.collection("products").doc("prod1").get();
      expect(productSnap.data()?.physicalStock).toBe(8);
      expect(productSnap.data()?.reservedStock).toBe(0);

      const ledgerSnap = await db
        .collection("inventoryLogs")
        .where("orderId", "==", "order1")
        .get();
      expect(ledgerSnap.size).toBe(1);
    });

    it("does not let a different rider 'verify' an already-delivered order", async () => {
      await seedOrder("order1", { status: "delivered" });

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234" }, "otherRider"))
      ).rejects.toThrow(/not assigned to you/);
    });
  });

  it("rejects verification from a rider the order isn't assigned to", async () => {
    await seedOrder("order1");

    await expect(
      verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234" }, "otherRider"))
    ).rejects.toThrow(/not assigned to you/);
  });

  it("rejects verification while the order isn't out for delivery", async () => {
    await seedOrder("order1", { status: "picked_up" });

    await expect(
      verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234" }, "rider1"))
    ).rejects.toThrow(/not out for delivery/);
  });

  it("rejects a malformed OTP before touching Firestore", async () => {
    await expect(
      verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "12" }, "rider1"))
    ).rejects.toThrow(/4-digit OTP/);
  });
});
