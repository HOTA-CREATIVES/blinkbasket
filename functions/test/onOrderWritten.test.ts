import functionsTest from "firebase-functions-test";
import { onOrderWritten, repairStockReleases } from "../src/index";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestore, PROJECT_ID } from "./testUtils";

const db = getFirestore();
const test = functionsTest({ projectId: PROJECT_ID });

/** {} mocks a snapshot of a document that doesn't exist (per firebase-functions-test docs). */
function docSnap(data: Record<string, unknown> | undefined, refPath: string) {
  return test.firestore.makeDocumentSnapshot(data ?? {}, refPath);
}

async function fireOrderWritten(
  orderId: string,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined
) {
  const refPath = `orders/${orderId}`;
  const change = test.makeChange(docSnap(before, refPath), docSnap(after, refPath));
  await onOrderWritten.run({
    data: change,
    params: { orderId },
  } as never);
}

describe("onOrderWritten", () => {
  beforeEach(async () => {
    await clearFirestore();
    await db.collection("config").doc("dashboard_stats").set({
      activeOrdersCount: 0,
      completedRevenue: 0,
    });
  });

  afterAll(async () => {
    await test.cleanup();
  });

  describe("rider offers (PII-free)", () => {
    const fullOrder = {
      status: "pending",
      deliveryBoyId: null,
      customerId: "cust1",
      customerName: "Asha Kumari",
      customerPhone: "9876543210",
      deliveryAddress: "12 Main Street",
      latitude: 16.546,
      longitude: 81.5225,
      village: "Bhimavaram",
      items: [{ productId: "prod1", name: "Milk", price: 50, quantity: 2 }],
      subtotal: 100,
      deliveryFee: 30,
      totalAmount: 130,
      paymentMethod: "COD",
    };

    it("publishes an offer with no phone, street address or GPS pin when an order opens", async () => {
      await fireOrderWritten("order1", undefined, fullOrder);

      const offer = (await db.collection("orderOffers").doc("order1").get()).data();
      expect(offer).toBeDefined();
      expect(offer?.customerName).toBe("Asha");
      expect(offer?.village).toBe("Bhimavaram");
      expect(offer?.totalAmount).toBe(130);
      expect(offer?.items).toHaveLength(1);
      for (const leaked of ["customerPhone", "latitude", "longitude", "customerId"]) {
        expect(offer?.[leaked]).toBeUndefined();
      }
      expect(offer?.deliveryAddress).toBe("");
    });

    it("removes the offer once a rider accepts the order", async () => {
      await fireOrderWritten("order1", undefined, fullOrder);
      await fireOrderWritten("order1", fullOrder, {
        ...fullOrder,
        status: "assigned",
        deliveryBoyId: "rider1",
      });
      expect((await db.collection("orderOffers").doc("order1").get()).exists).toBe(false);
    });

    it("removes the offer when the order is cancelled", async () => {
      await fireOrderWritten("order1", undefined, fullOrder);
      await fireOrderWritten("order1", fullOrder, { ...fullOrder, status: "cancelled" });
      expect((await db.collection("orderOffers").doc("order1").get()).exists).toBe(false);
    });

    it("re-publishes the offer when an admin hands an assigned order back to the pool", async () => {
      const assigned = { ...fullOrder, status: "assigned", deliveryBoyId: "rider1" };
      await fireOrderWritten("order1", assigned, { ...fullOrder, status: "pending", deliveryBoyId: null });
      expect((await db.collection("orderOffers").doc("order1").get()).exists).toBe(true);
    });
  });

  it("does not release stock when a delivered order is (wrongly) moved to cancelled", async () => {
    await db.collection("products").doc("prod1").set({
      physicalStock: 8,
      reservedStock: 2, // belongs to a different, still-open order
      availableStock: 6,
    });

    await fireOrderWritten(
      "order1",
      { status: "delivered", totalAmount: 100, items: [{ productId: "prod1", quantity: 2 }] },
      { status: "cancelled", totalAmount: 100, items: [{ productId: "prod1", quantity: 2 }] }
    );

    const productSnap = await db.collection("products").doc("prod1").get();
    expect(productSnap.data()?.reservedStock).toBe(2);
    const ledgerSnap = await db.collection("inventoryLogs").where("orderId", "==", "order1").get();
    expect(ledgerSnap.size).toBe(0);
  });

  describe("repairStockReleases", () => {
    it("releases the reservation of a cancelled order whose release previously failed", async () => {
      await db.collection("products").doc("prod1").set({
        physicalStock: 10,
        reservedStock: 3,
        availableStock: 7,
      });
      await db.collection("orders").doc("order1").set({
        status: "cancelled",
        cancelledBy: "customer",
        customerId: "cust1",
        stockReleaseFailed: true,
        items: [{ productId: "prod1", quantity: 3 }],
      });

      await repairStockReleases.run({} as never);

      const productSnap = await db.collection("products").doc("prod1").get();
      expect(productSnap.data()?.reservedStock).toBe(0);
      expect(productSnap.data()?.availableStock).toBe(10);
      const orderSnap = await db.collection("orders").doc("order1").get();
      expect(orderSnap.data()?.stockReleased).toBe(true);
      expect(orderSnap.data()?.stockReleaseFailed).toBeUndefined();

      // A second run must not release again.
      await repairStockReleases.run({} as never);
      const again = await db.collection("products").doc("prod1").get();
      expect(again.data()?.reservedStock).toBe(0);
      expect(again.data()?.availableStock).toBe(10);
    });

    it("clears the flag without touching stock when the order was already released", async () => {
      await db.collection("products").doc("prod1").set({
        physicalStock: 10,
        reservedStock: 1,
        availableStock: 9,
      });
      await db.collection("orders").doc("order1").set({
        status: "cancelled",
        stockReleased: true,
        stockReleaseFailed: true,
        items: [{ productId: "prod1", quantity: 3 }],
      });

      await repairStockReleases.run({} as never);

      const productSnap = await db.collection("products").doc("prod1").get();
      expect(productSnap.data()?.reservedStock).toBe(1);
      const orderSnap = await db.collection("orders").doc("order1").get();
      expect(orderSnap.data()?.stockReleaseFailed).toBeUndefined();
    });
  });

  it("increments activeOrdersCount when a new order is created", async () => {
    await fireOrderWritten("order1", undefined, { status: "pending", totalAmount: 100 });

    const statsSnap = await db.collection("config").doc("dashboard_stats").get();
    expect(statsSnap.data()?.activeOrdersCount).toBe(1);
  });

  it("increments completedRevenue and decrements activeOrdersCount when delivered", async () => {
    await db.collection("config").doc("dashboard_stats").set({
      activeOrdersCount: 1,
      completedRevenue: 0,
    });

    await fireOrderWritten(
      "order1",
      { status: "out_for_delivery", totalAmount: 250 },
      { status: "delivered", totalAmount: 250 }
    );

    const statsSnap = await db.collection("config").doc("dashboard_stats").get();
    expect(statsSnap.data()?.activeOrdersCount).toBe(0);
    expect(statsSnap.data()?.completedRevenue).toBe(250);
  });

  it("releases reserved stock and writes a return ledger entry on cancellation", async () => {
    await db.collection("products").doc("prod1").set({
      physicalStock: 10,
      reservedStock: 3,
      availableStock: 7,
    });
    await db.collection("config").doc("dashboard_stats").set({
      activeOrdersCount: 1,
      completedRevenue: 0,
    });

    await fireOrderWritten(
      "order1",
      { status: "pending", totalAmount: 100, items: [{ productId: "prod1", quantity: 3 }] },
      {
        status: "cancelled",
        customerId: "cust1",
        totalAmount: 100,
        items: [{ productId: "prod1", quantity: 3 }],
      }
    );

    const productSnap = await db.collection("products").doc("prod1").get();
    expect(productSnap.data()?.reservedStock).toBe(0);
    expect(productSnap.data()?.availableStock).toBe(10);

    const ledgerSnap = await db
      .collection("inventoryLogs")
      .where("orderId", "==", "order1")
      .get();
    expect(ledgerSnap.size).toBe(1);
    expect(ledgerSnap.docs[0].data().changeType).toBe("return");

    const statsSnap = await db.collection("config").doc("dashboard_stats").get();
    expect(statsSnap.data()?.activeOrdersCount).toBe(0);
  });

  it("attributes an admin cancellation to the admin in the inventory ledger", async () => {
    await db.collection("products").doc("prod1").set({
      physicalStock: 10,
      reservedStock: 3,
      availableStock: 7,
    });
    const items = [{ productId: "prod1", quantity: 3 }];

    await fireOrderWritten(
      "order1",
      { status: "assigned", totalAmount: 100, items },
      {
        status: "cancelled",
        cancelledBy: "admin",
        cancelledById: "admin1",
        customerId: "cust1",
        totalAmount: 100,
        items,
      }
    );

    const ledgerSnap = await db.collection("inventoryLogs").where("orderId", "==", "order1").get();
    expect(ledgerSnap.size).toBe(1);
    expect(ledgerSnap.docs[0].data().actorType).toBe("admin");
    expect(ledgerSnap.docs[0].data().adminId).toBe("admin1");

    const productSnap = await db.collection("products").doc("prod1").get();
    expect(productSnap.data()?.reservedStock).toBe(0);
  });

  it("does not double-release when two deliveries of the cancellation event run concurrently", async () => {
    // Another order still holds 2 reserved units of the same product: a
    // double-release of this order's 3 units would eat into those.
    await db.collection("products").doc("prod1").set({
      physicalStock: 10,
      reservedStock: 5, // 3 (this order) + 2 (someone else's)
      availableStock: 5,
    });

    const items = [{ productId: "prod1", quantity: 3 }];
    // The stale event snapshot for BOTH deliveries lacks stockReleased — only
    // an in-transaction re-read of the order can tell the second one apart.
    const cancelled = { status: "cancelled", customerId: "cust1", totalAmount: 100, items };
    const pending = { status: "pending", totalAmount: 100, items };

    await Promise.all([
      fireOrderWritten("order1", pending, cancelled),
      fireOrderWritten("order1", pending, cancelled),
    ]);

    const productSnap = await db.collection("products").doc("prod1").get();
    expect(productSnap.data()?.reservedStock).toBe(2);
    expect(productSnap.data()?.availableStock).toBe(8);

    const ledgerSnap = await db
      .collection("inventoryLogs")
      .where("orderId", "==", "order1")
      .get();
    expect(ledgerSnap.size).toBe(1);
  });

  it("does not double-release stock if the cancellation trigger fires again (idempotency guard)", async () => {
    await db.collection("products").doc("prod1").set({
      physicalStock: 10,
      reservedStock: 3,
      availableStock: 7,
    });

    const cancelledOrder = {
      status: "cancelled",
      customerId: "cust1",
      totalAmount: 100,
      items: [{ productId: "prod1", quantity: 3 }],
    };

    // First delivery of the event: releases the reservation and marks
    // stockReleased on the order.
    await fireOrderWritten(
      "order1",
      { status: "pending", totalAmount: 100, items: [{ productId: "prod1", quantity: 3 }] },
      cancelledOrder
    );

    // A redelivered/retried event for the same transition — the after-data
    // now carries stockReleased: true, as the first run would have set it.
    await fireOrderWritten(
      "order1",
      { status: "pending", totalAmount: 100, items: [{ productId: "prod1", quantity: 3 }] },
      { ...cancelledOrder, stockReleased: true }
    );

    const productSnap = await db.collection("products").doc("prod1").get();
    expect(productSnap.data()?.reservedStock).toBe(0);
    expect(productSnap.data()?.availableStock).toBe(10);

    const ledgerSnap = await db
      .collection("inventoryLogs")
      .where("orderId", "==", "order1")
      .get();
    expect(ledgerSnap.size).toBe(1);
  });
});
