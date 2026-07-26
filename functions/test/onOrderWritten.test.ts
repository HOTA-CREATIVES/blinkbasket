import functionsTest from "firebase-functions-test";
import { onOrderWritten } from "../src/index";
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
