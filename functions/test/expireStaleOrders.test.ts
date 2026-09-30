import { expireStaleOrders } from "../src/index";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { clearFirestore } from "./testUtils";

const db = getFirestore();

const TWO_DAYS_AGO = Timestamp.fromMillis(Date.now() - 48 * 3600 * 1000);
const JUST_NOW = Timestamp.fromMillis(Date.now() - 60 * 1000);

async function seedOrder(orderId: string, overrides: Record<string, unknown> = {}) {
  await db.collection("orders").doc(orderId).set({
    customerId: "cust1",
    status: "pending",
    deliveryBoyId: null,
    createdAt: TWO_DAYS_AGO,
    items: [],
    ...overrides,
  });
}

async function run() {
  await expireStaleOrders.run({} as never);
}

describe("expireStaleOrders", () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("cancels an old pending order nobody accepted", async () => {
    await seedOrder("order1");

    await run();

    const snap = await db.collection("orders").doc("order1").get();
    expect(snap.data()?.status).toBe("cancelled");
    expect(snap.data()?.cancelledBy).toBe("system");
    expect(snap.data()?.cancelReason).toBe("auto_expired");
  });

  it("leaves a recent pending order alone", async () => {
    await seedOrder("order1", { createdAt: JUST_NOW });

    await run();

    const snap = await db.collection("orders").doc("order1").get();
    expect(snap.data()?.status).toBe("pending");
  });

  it("leaves an old order that a rider already holds alone", async () => {
    await seedOrder("order1", { status: "assigned", deliveryBoyId: "rider1" });

    await run();

    const snap = await db.collection("orders").doc("order1").get();
    expect(snap.data()?.status).toBe("assigned");
  });

  it("does NOT cancel an order a rider accepts between the query and the write", async () => {
    await seedOrder("order1");

    // The scheduler's query already returned order1 as pending+unassigned.
    // Simulate a rider winning acceptOrder in the gap before its write.
    const realRunTransaction = db.runTransaction.bind(db);
    jest.spyOn(db, "runTransaction").mockImplementationOnce((async (fn: any, opts: any) => {
      await db.collection("orders").doc("order1").update({
        status: "assigned",
        deliveryBoyId: "rider1",
      });
      return realRunTransaction(fn, opts);
    }) as any);

    await run();

    const snap = await db.collection("orders").doc("order1").get();
    expect(snap.data()?.status).toBe("assigned");
    expect(snap.data()?.deliveryBoyId).toBe("rider1");
    expect(snap.data()?.cancelledBy).toBeUndefined();
  });
});
