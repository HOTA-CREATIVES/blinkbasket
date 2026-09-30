import { resetOtpAttempts } from "../src/index";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { clearFirestore, callableRequest } from "./testUtils";

const db = getFirestore();

async function seedOrderWithMaxedOutOtp(orderId: string) {
  await db.collection("orders").doc(orderId).set({
    customerId: "cust1",
    deliveryBoyId: "rider1",
    status: "out_for_delivery",
  });
  await db
    .collection("orders")
    .doc(orderId)
    .collection("private")
    .doc("delivery")
    .set({
      otp: "1234",
      attempts: 5,
      totalAttempts: 15,
      lockedUntil: Timestamp.fromMillis(Date.now() + 10 * 60_000),
    });
}

async function seedAdmin(uid: string, overrides: Record<string, unknown> = {}) {
  await db.collection("admins").doc(uid).set({ isActive: true, ...overrides });
}

describe("resetOtpAttempts", () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  it("rejects a non-admin caller", async () => {
    await seedOrderWithMaxedOutOtp("order1");

    await expect(
      resetOtpAttempts.run(callableRequest({ orderId: "order1" }, "cust1"))
    ).rejects.toThrow(/Only active admins/);
  });

  it("rejects a deactivated admin", async () => {
    await seedOrderWithMaxedOutOtp("order1");
    await seedAdmin("admin1", { isActive: false });

    await expect(
      resetOtpAttempts.run(callableRequest({ orderId: "order1" }, "admin1"))
    ).rejects.toThrow(/Only active admins/);
  });

  it("lets an active admin reset the attempt counter, unblocking further verification", async () => {
    await seedOrderWithMaxedOutOtp("order1");
    await seedAdmin("admin1");

    const result = await resetOtpAttempts.run(callableRequest({ orderId: "order1" }, "admin1"));
    expect(result.success).toBe(true);

    const privateSnap = await db
      .collection("orders")
      .doc("order1")
      .collection("private")
      .doc("delivery")
      .get();
    expect(privateSnap.data()?.attempts).toBe(0);
    expect(privateSnap.data()?.totalAttempts).toBe(0);
    expect(privateSnap.data()?.lockedUntil).toBeNull();
  });

  it("rejects when there is no delivery verification data for the order", async () => {
    await seedAdmin("admin1");

    await expect(
      resetOtpAttempts.run(callableRequest({ orderId: "missing-order" }, "admin1"))
    ).rejects.toThrow(/No delivery verification data/);
  });
});
