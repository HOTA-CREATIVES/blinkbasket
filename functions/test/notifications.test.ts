const sendEachForMulticast = jest.fn().mockResolvedValue({ successCount: 1, failureCount: 0 });

jest.mock("firebase-admin/messaging", () => ({
  getMessaging: () => ({ sendEachForMulticast }),
}));

import functionsTest from "firebase-functions-test";
import { onOrderWritten } from "../src/index";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestore, PROJECT_ID } from "./testUtils";

const db = getFirestore();
const test = functionsTest({ projectId: PROJECT_ID });

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
  await onOrderWritten.run({ data: change, params: { orderId } } as never);
}

describe("onOrderWritten — push notifications", () => {
  beforeEach(async () => {
    await clearFirestore();
    sendEachForMulticast.mockClear();
    await db.collection("config").doc("dashboard_stats").set({
      activeOrdersCount: 0,
      completedRevenue: 0,
    });
  });

  afterAll(async () => {
    await test.cleanup();
  });

  it("notifies the customer and the newly-assigned rider when an order is assigned", async () => {
    await db.collection("users").doc("cust1").set({ fcmTokens: ["cust-token-1"] });
    await db.collection("deliveryBoys").doc("rider1").set({ fcmTokens: ["rider-token-1"] });

    await fireOrderWritten(
      "order1",
      { status: "pending", customerId: "cust1", totalAmount: 100 },
      {
        status: "assigned",
        customerId: "cust1",
        deliveryBoyId: "rider1",
        customerName: "Test Customer",
        totalAmount: 100,
      }
    );

    expect(sendEachForMulticast).toHaveBeenCalledTimes(2);

    const customerCall = sendEachForMulticast.mock.calls.find((c) =>
      c[0].tokens.includes("cust-token-1")
    );
    expect(customerCall[0].notification.body).toMatch(/rider has been assigned/);

    const riderCall = sendEachForMulticast.mock.calls.find((c) =>
      c[0].tokens.includes("rider-token-1")
    );
    expect(riderCall[0].notification.title).toBe("New delivery assigned");
  });

  it("notifies only the customer when the order moves to out_for_delivery", async () => {
    await db.collection("users").doc("cust1").set({ fcmTokens: ["cust-token-1"] });

    await fireOrderWritten(
      "order1",
      { status: "picked_up", customerId: "cust1", deliveryBoyId: "rider1", totalAmount: 100 },
      { status: "out_for_delivery", customerId: "cust1", deliveryBoyId: "rider1", totalAmount: 100 }
    );

    expect(sendEachForMulticast).toHaveBeenCalledTimes(1);
    expect(sendEachForMulticast.mock.calls[0][0].tokens).toEqual(["cust-token-1"]);
    expect(sendEachForMulticast.mock.calls[0][0].notification.body).toMatch(/on the way/);
  });

  it("sends nothing when the customer has no registered devices", async () => {
    await db.collection("users").doc("cust1").set({});

    await fireOrderWritten(
      "order1",
      { status: "out_for_delivery", customerId: "cust1", totalAmount: 100 },
      { status: "delivered", customerId: "cust1", totalAmount: 100 }
    );

    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  it("does not fail the trigger if messaging throws", async () => {
    await db.collection("users").doc("cust1").set({ fcmTokens: ["cust-token-1"] });
    sendEachForMulticast.mockRejectedValueOnce(new Error("messaging down"));

    await expect(
      fireOrderWritten(
        "order1",
        { status: "picked_up", customerId: "cust1", totalAmount: 100 },
        { status: "out_for_delivery", customerId: "cust1", totalAmount: 100 }
      )
    ).resolves.toBeUndefined();

    const statsSnap = await db.collection("config").doc("dashboard_stats").get();
    expect(statsSnap.exists).toBe(true);
  });
});

describe("onOrderWritten — new order broadcast (Blinkit-style auto-assignment)", () => {
  beforeEach(async () => {
    await clearFirestore();
    sendEachForMulticast.mockClear();
    await db.collection("config").doc("dashboard_stats").set({
      activeOrdersCount: 0,
      completedRevenue: 0,
    });
  });

  it("broadcasts tier-1 (village-matched, on-duty) riders only, when any exist", async () => {
    await db.collection("deliveryBoys").doc("localRider").set({
      isActive: true,
      onDuty: true,
      village: "Bhimavaram",
      fcmTokens: ["local-token"],
    });
    await db.collection("deliveryBoys").doc("otherVillageRider").set({
      isActive: true,
      onDuty: true,
      village: "Mentada",
      fcmTokens: ["other-token"],
    });

    await fireOrderWritten("order1", undefined, {
      status: "pending",
      customerName: "Test Customer",
      village: "Bhimavaram",
      totalAmount: 100,
    });

    expect(sendEachForMulticast).toHaveBeenCalledTimes(1);
    expect(sendEachForMulticast.mock.calls[0][0].tokens).toEqual(["local-token"]);

    const orderSnap = await db.collection("orders").doc("order1").get();
    expect(orderSnap.data()?.notifyTier).toBe(1);
    expect(orderSnap.data()?.notifiedAt).toBeDefined();
  });

  it("falls through to tier 2 immediately when no on-duty rider matches the village", async () => {
    await db.collection("deliveryBoys").doc("elsewhereRider").set({
      isActive: true,
      onDuty: true,
      village: "Mentada",
      fcmTokens: ["elsewhere-token"],
    });

    await fireOrderWritten("order1", undefined, {
      status: "pending",
      customerName: "Test Customer",
      village: "Bhimavaram",
      totalAmount: 100,
    });

    expect(sendEachForMulticast).toHaveBeenCalledTimes(1);
    expect(sendEachForMulticast.mock.calls[0][0].tokens).toEqual(["elsewhere-token"]);

    const orderSnap = await db.collection("orders").doc("order1").get();
    expect(orderSnap.data()?.notifyTier).toBe(2);
  });

  it("still records notifyTier/notifiedAt when no rider is on duty anywhere", async () => {
    await fireOrderWritten("order1", undefined, {
      status: "pending",
      customerName: "Test Customer",
      village: "Bhimavaram",
      totalAmount: 100,
    });

    expect(sendEachForMulticast).not.toHaveBeenCalled();

    const orderSnap = await db.collection("orders").doc("order1").get();
    expect(orderSnap.data()?.notifyTier).toBe(2);
    expect(orderSnap.data()?.notifiedAt).toBeDefined();
  });
});
