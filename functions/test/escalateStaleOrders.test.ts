const sendEachForMulticast = jest.fn().mockResolvedValue({ successCount: 1, failureCount: 0 });

jest.mock("firebase-admin/messaging", () => ({
  getMessaging: () => ({ sendEachForMulticast }),
}));

import { escalateStaleOrders } from "../src/index";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { clearFirestore } from "./testUtils";

const db = getFirestore();

const STALE = Timestamp.fromMillis(Date.now() - 200_000); // > BROADCAST_RETRY_SECONDS (90s)
const FRESH = Timestamp.fromMillis(Date.now() - 5_000);

async function run() {
  await escalateStaleOrders.run({} as never);
}

describe("escalateStaleOrders", () => {
  beforeEach(async () => {
    await clearFirestore();
    sendEachForMulticast.mockClear();
  });

  it("escalates a stale tier-1 order to tier 2 and re-broadcasts to every on-duty rider", async () => {
    await db.collection("deliveryBoys").doc("localRider").set({
      isActive: true,
      onDuty: true,
      village: "Bhimavaram",
      fcmTokens: ["local-token"],
    });
    await db.collection("deliveryBoys").doc("otherRider").set({
      isActive: true,
      onDuty: true,
      village: "Mentada",
      fcmTokens: ["other-token"],
    });
    await db.collection("orders").doc("order1").set({
      status: "pending",
      deliveryBoyId: null,
      village: "Bhimavaram",
      customerName: "Test Customer",
      notifyTier: 1,
      notifiedAt: STALE,
    });

    await run();

    const orderSnap = await db.collection("orders").doc("order1").get();
    expect(orderSnap.data()?.notifyTier).toBe(2);

    expect(sendEachForMulticast).toHaveBeenCalledTimes(1);
    const tokens = sendEachForMulticast.mock.calls[0][0].tokens;
    expect(tokens.sort()).toEqual(["local-token", "other-token"]);
  });

  it("counts each re-broadcast", async () => {
    await db.collection("deliveryBoys").doc("rider1").set({
      isActive: true,
      onDuty: true,
      village: "Bhimavaram",
      fcmTokens: ["t1"],
    });
    await db.collection("orders").doc("order1").set({
      status: "pending",
      deliveryBoyId: null,
      village: "Bhimavaram",
      customerName: "Test Customer",
      notifyTier: 1,
      notifiedAt: STALE,
      broadcastCount: 3,
    });

    await run();

    const snap = await db.collection("orders").doc("order1").get();
    expect(snap.data()?.broadcastCount).toBe(4);
    expect(sendEachForMulticast).toHaveBeenCalledTimes(1);
  });

  it("stops pushing after the broadcast cap and takes the order out of the escalation query", async () => {
    await db.collection("deliveryBoys").doc("rider1").set({
      isActive: true,
      onDuty: true,
      village: "Bhimavaram",
      fcmTokens: ["t1"],
    });
    await db.collection("orders").doc("order1").set({
      status: "pending",
      deliveryBoyId: null,
      village: "Bhimavaram",
      customerName: "Test Customer",
      notifyTier: 2,
      notifiedAt: STALE,
      broadcastCount: 10, // MAX_BROADCASTS
    });

    await run();

    expect(sendEachForMulticast).not.toHaveBeenCalled();
    const snap = await db.collection("orders").doc("order1").get();
    expect(snap.data()?.broadcastExhausted).toBe(true);
    // Parked in the future so the `notifiedAt <= cutoff` scan stops seeing it.
    expect(snap.data()?.notifiedAt.toMillis()).toBeGreaterThan(Date.now());

    // A second run does nothing at all.
    await run();
    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  it("keeps re-broadcasting a stale tier-2 order until the cap", async () => {
    await db.collection("deliveryBoys").doc("rider1").set({
      isActive: true,
      onDuty: true,
      village: "Bhimavaram",
      fcmTokens: ["rider-token"],
    });
    await db.collection("orders").doc("order1").set({
      status: "pending",
      deliveryBoyId: null,
      village: "Bhimavaram",
      notifyTier: 2,
      notifiedAt: STALE,
    });

    await run();

    expect(sendEachForMulticast).toHaveBeenCalledTimes(1);
    const orderSnap = await db.collection("orders").doc("order1").get();
    expect(orderSnap.data()?.notifyTier).toBe(2);
  });

  it("does not touch an order that was notified recently", async () => {
    await db.collection("orders").doc("order1").set({
      status: "pending",
      deliveryBoyId: null,
      village: "Bhimavaram",
      notifyTier: 1,
      notifiedAt: FRESH,
    });

    await run();

    expect(sendEachForMulticast).not.toHaveBeenCalled();
    const orderSnap = await db.collection("orders").doc("order1").get();
    expect(orderSnap.data()?.notifyTier).toBe(1);
  });

  it("excludes an already-assigned order even if its notifiedAt is stale", async () => {
    await db.collection("orders").doc("order1").set({
      status: "assigned",
      deliveryBoyId: "rider1",
      village: "Bhimavaram",
      notifyTier: 1,
      notifiedAt: STALE,
    });

    await run();

    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });
});
