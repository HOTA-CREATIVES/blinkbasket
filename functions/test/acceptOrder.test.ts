import { acceptOrder } from "../src/index";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestore, callableRequest } from "./testUtils";

const db = getFirestore();

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

async function seedOrder(orderId: string, overrides: Record<string, unknown> = {}) {
  await db
    .collection("orders")
    .doc(orderId)
    .set({
      customerId: "cust1",
      customerName: "Test Customer",
      status: "pending",
      deliveryBoyId: null,
      village: "Bhimavaram",
      totalAmount: 130,
      notifyTier: 1,
      ...overrides,
    });
}

describe("acceptOrder", () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  it("assigns the order to the accepting rider", async () => {
    await seedRider("rider1");
    await seedOrder("order1");

    const result = await acceptOrder.run(
      callableRequest({ orderId: "order1" }, "rider1", { delivery: true })
    );
    expect(result.success).toBe(true);

    const orderSnap = await db.collection("orders").doc("order1").get();
    expect(orderSnap.data()?.status).toBe("assigned");
    expect(orderSnap.data()?.deliveryBoyId).toBe("rider1");
    expect(orderSnap.data()?.deliveryBoyName).toBe("Test Rider");
  });

  it("lets exactly one rider win a concurrent accept race", async () => {
    await seedRider("rider1");
    await seedRider("rider2");
    await seedOrder("order1");

    const outcomes = await Promise.allSettled([
      acceptOrder.run(callableRequest({ orderId: "order1" }, "rider1", { delivery: true })),
      acceptOrder.run(callableRequest({ orderId: "order1" }, "rider2", { delivery: true })),
    ]);

    const fulfilled = outcomes.filter((o) => o.status === "fulfilled");
    const rejected = outcomes.filter((o) => o.status === "rejected");
    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);
    expect((rejected[0] as PromiseRejectedResult).reason.message).toMatch(/already accepted/);

    const orderSnap = await db.collection("orders").doc("order1").get();
    expect(["rider1", "rider2"]).toContain(orderSnap.data()?.deliveryBoyId);
  });

  it("rejects an off-duty rider", async () => {
    await seedRider("rider1", { onDuty: false });
    await seedOrder("order1");

    await expect(
      acceptOrder.run(callableRequest({ orderId: "order1" }, "rider1", { delivery: true }))
    ).rejects.toThrow(/Go on-duty/);
  });

  it("rejects a deactivated rider", async () => {
    await seedRider("rider1", { isActive: false });
    await seedOrder("order1");

    await expect(
      acceptOrder.run(callableRequest({ orderId: "order1" }, "rider1", { delivery: true }))
    ).rejects.toThrow(/deactivated/);
  });

  it("rejects if the order is already assigned", async () => {
    await seedRider("rider1");
    await seedOrder("order1", { status: "assigned", deliveryBoyId: "riderX" });

    await expect(
      acceptOrder.run(callableRequest({ orderId: "order1" }, "rider1", { delivery: true }))
    ).rejects.toThrow(/already accepted/);
  });

  it("rejects a caller without the delivery custom claim", async () => {
    await seedOrder("order1");

    await expect(
      acceptOrder.run(callableRequest({ orderId: "order1" }, "notARider", {}))
    ).rejects.toThrow(/Only delivery partners/);
  });
});
