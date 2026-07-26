import { verifyDeliveryOtp } from "../src/index";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestore, callableRequest } from "./testUtils";

const db = getFirestore();

async function seedOrder(orderId: string, overrides: Record<string, unknown> = {}) {
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
    .set({ otp: "1234", attempts: 0 });
}

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

  it("increments the attempt counter and does not deliver on wrong OTP", async () => {
    await seedOrder("order1");

    await expect(
      verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "0000" }, "rider1"))
    ).rejects.toThrow(/Incorrect delivery OTP/);

    const privateSnap = await db
      .collection("orders")
      .doc("order1")
      .collection("private")
      .doc("delivery")
      .get();
    expect(privateSnap.data()?.attempts).toBe(1);

    const orderSnap = await db.collection("orders").doc("order1").get();
    expect(orderSnap.data()?.status).toBe("out_for_delivery");
  });

  it("blocks further attempts after the 5th wrong OTP", async () => {
    await seedOrder("order1");
    await db
      .collection("orders")
      .doc("order1")
      .collection("private")
      .doc("delivery")
      .set({ otp: "1234", attempts: 5 });

    await expect(
      verifyDeliveryOtp.run(callableRequest({ orderId: "order1", otp: "1234" }, "rider1"))
    ).rejects.toThrow(/Too many incorrect attempts/);
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
