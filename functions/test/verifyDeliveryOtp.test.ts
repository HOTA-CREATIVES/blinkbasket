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
    // verifyDeliveryOtp re-reads the live rider doc, so riders must exist.
    await db.collection("deliveryBoys").doc("rider1").set({ isActive: true });
    await db.collection("deliveryBoys").doc("otherRider").set({ isActive: true });
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
      callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1")
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

      await verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1"));

      // A later rate change must not reprice the delivered order.
      await db.collection("config").doc("app").set({ riderPayoutPerDelivery: 99 });
      const snap = await db.collection("orders").doc("order1").get();
      expect(snap.data()?.riderPayout).toBe(42);
    });

    it("falls back to the default payout when none is configured", async () => {
      await seedOrder("order1");

      await verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1"));

      const snap = await db.collection("orders").doc("order1").get();
      expect(snap.data()?.riderPayout).toBe(30);
    });

    it("does not record a payout when the OTP is wrong", async () => {
      await seedOrder("order1");

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "0000", collectedAmount: 130 }, "rider1"))
      ).rejects.toThrow();

      const snap = await db.collection("orders").doc("order1").get();
      expect(snap.data()?.riderPayout).toBeUndefined();
    });
  });

  describe("wrong OTP handling", () => {
    it("counts the attempt, tells the rider how many are left, and does not deliver", async () => {
      await seedOrder("order1");

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "0000", collectedAmount: 130 }, "rider1"))
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
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "0000", collectedAmount: 130 }, "rider1"))
      ).rejects.toThrow(/Locked for 10 minutes/);

      const secret = await readSecret("order1");
      expect(secret.attempts).toBe(0);
      expect(secret.totalAttempts).toBe(5);
      expect(secret.lockedUntil.toMillis()).toBeGreaterThan(Date.now());
    });

    it("rejects even the CORRECT OTP while the cooldown is active", async () => {
      await seedOrder("order1", {}, { attempts: 0, totalAttempts: 5, lockedUntil: minutesFromNow(7) });

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1"))
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
        callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1")
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
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "0000", collectedAmount: 130 }, "rider1"))
      ).rejects.toThrow(/4 attempts left/);

      const secret = await readSecret("order1");
      expect(secret.attempts).toBe(1);
      expect(secret.totalAttempts).toBe(6);
      expect(secret.lockedUntil).toBeNull();
    });

    it("hard-locks after the lifetime cap until an admin resets it", async () => {
      await seedOrder("order1", {}, { attempts: 0, totalAttempts: 15, lockedUntil: minutesFromNow(-60) });

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1"))
      ).rejects.toThrow(/Ask the admin to reset OTP verification/);
    });

    it("honours attempts recorded by the old schema (attempts only, no totalAttempts)", async () => {
      await seedOrder("order1", {}, { attempts: 4 });

      await expect(
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "0000", collectedAmount: 130 }, "rider1"))
      ).rejects.toThrow(/Locked for 10 minutes/);
    });
  });

  describe("idempotency", () => {
    it("a retry after the first call already delivered the order succeeds without touching stock again", async () => {
      await seedOrder("order1");

      await verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1"));
      // Response was lost; the rider's app retries with the same OTP.
      const retry = await verifyDeliveryOtp.run(
        callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1")
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
        verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "otherRider"))
      ).rejects.toThrow(/not assigned to you/);
    });
  });

  describe("COD collection confirmation", () => {
    it("records the amount the rider confirmed and marks the order paid", async () => {
      await seedOrder("order1", { totalAmount: 130 });

      await verifyDeliveryOtp.run(
        callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1")
      );

      const order = (await db.collection("orders").doc("order1").get()).data();
      expect(order?.status).toBe("delivered");
      expect(order?.paymentStatus).toBe("paid");
      expect(order?.codCollectedAmount).toBe(130);
      expect(order?.codCollectedBy).toBe("rider1");
    });

    it("refuses to deliver without a collected amount", async () => {
      await seedOrder("order1");
      for (const data of [
        { orderId: "order1", otp: "1234" },
        { orderId: "order1", otp: "1234", collectedAmount: "130" },
        { orderId: "order1", otp: "1234", collectedAmount: null },
        { orderId: "order1", otp: "1234", collectedAmount: -1 },
      ]) {
        await expect(
          verifyDeliveryOtp.run(callableRequest(data, "rider1"))
        ).rejects.toThrow(/Confirm the cash you collected/);
      }
      expect((await db.collection("orders").doc("order1").get()).data()?.status).toBe("out_for_delivery");
    });

    it("refuses a collected amount that isn't the order total, without spending an OTP attempt or touching stock", async () => {
      await seedOrder("order1", { totalAmount: 130 });

      await expect(
        verifyDeliveryOtp.run(
          callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 100 }, "rider1")
        )
      ).rejects.toThrow(/Collect exactly ₹130/);

      const order = (await db.collection("orders").doc("order1").get()).data();
      expect(order?.status).toBe("out_for_delivery");
      expect(order?.codCollectedAmount).toBeUndefined();
      expect((await readSecret("order1")).attempts).toBe(0);
      const product = (await db.collection("products").doc("prod1").get()).data();
      expect(product?.physicalStock).toBe(10);
    });

    it("compares to the paisa, not as floating point", async () => {
      await seedOrder("order1", { totalAmount: 129.9 });
      await verifyDeliveryOtp.run(
        callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 129.9 }, "rider1")
      );
      expect((await db.collection("orders").doc("order1").get()).data()?.status).toBe("delivered");
    });

    it("still validates the OTP once the amount is right", async () => {
      await seedOrder("order1", { totalAmount: 130 });
      await expect(
        verifyDeliveryOtp.run(
          callableRequest({ orderId: "order1", otp: "0000", collectedAmount: 130 }, "rider1")
        )
      ).rejects.toThrow(/Incorrect delivery OTP/);
      expect((await readSecret("order1")).attempts).toBe(1);
    });

    it("keeps a retry of an already-delivered order idempotent without a new amount", async () => {
      await seedOrder("order1", { totalAmount: 130 });
      await verifyDeliveryOtp.run(
        callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1")
      );
      const retry = await verifyDeliveryOtp.run(
        callableRequest({ orderId: "order1", otp: "1234" }, "rider1")
      );
      expect(retry.success).toBe(true);
      expect((await db.collection("orders").doc("order1").get()).data()?.codCollectedAmount).toBe(130);
    });
  });

  it("rejects a deactivated rider even on their own assigned order", async () => {
    await seedOrder("order1");
    await db.collection("deliveryBoys").doc("rider1").set({ isActive: false });

    await expect(
      verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1"))
    ).rejects.toThrow(/deactivated/);

    const orderSnap = await db.collection("orders").doc("order1").get();
    expect(orderSnap.data()?.status).toBe("out_for_delivery");
  });

  it("marks the order stockReleased so a later cancel can't release the consumed reservation", async () => {
    await seedOrder("order1");
    await verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1"));
    const orderSnap = await db.collection("orders").doc("order1").get();
    expect(orderSnap.data()?.stockReleased).toBe(true);
  });

  it("rejects verification from a rider the order isn't assigned to", async () => {
    await seedOrder("order1");

    await expect(
      verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "otherRider"))
    ).rejects.toThrow(/not assigned to you/);
  });

  it("rejects verification while the order isn't out for delivery", async () => {
    await seedOrder("order1", { status: "picked_up" });

    await expect(
      verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234", collectedAmount: 130 }, "rider1"))
    ).rejects.toThrow(/not out for delivery/);
  });

  it("rejects a malformed OTP before touching Firestore", async () => {
    await expect(
      verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "12", collectedAmount: 130 }, "rider1"))
    ).rejects.toThrow(/4-digit OTP/);
  });
});
