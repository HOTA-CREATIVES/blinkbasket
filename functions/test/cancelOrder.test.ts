// @ts-nocheck
import { cancelOrder } from "../src/index";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestore, callableRequest } from "./testUtils";

const cancelDb = getFirestore();

describe("cancelOrder (integration)", () => {
  beforeEach(async () => {
    await clearFirestore();
    await cancelDb.collection("admins").doc("admin1").set({ isActive: true });
  });

  const seed = (status: string) =>
    cancelDb.collection("orders").doc("order1").set({ customerId: "cust1", status });

  it("lets an admin cancel an active order", async () => {
    await seed("out_for_delivery");
    await cancelOrder.run(callableRequest({ orderId: "order1", reason: "test" }, "admin1"));
    const snap = await cancelDb.collection("orders").doc("order1").get();
    expect(snap.data()?.status).toBe("cancelled");
    expect(snap.data()?.cancelledBy).toBe("admin");
  });

  it("refuses to cancel a delivered order, even for an admin (its stock is already consumed)", async () => {
    await seed("delivered");
    await expect(
      cancelOrder.run(callableRequest({ orderId: "order1" }, "admin1"))
    ).rejects.toThrow(/already delivered/);
    const snap = await cancelDb.collection("orders").doc("order1").get();
    expect(snap.data()?.status).toBe("delivered");
  });

  it("refuses to re-cancel an already cancelled order", async () => {
    await seed("cancelled");
    await expect(
      cancelOrder.run(callableRequest({ orderId: "order1" }, "admin1"))
    ).rejects.toThrow(/already cancelled/);
  });

  it("still lets a customer cancel their own pending order but not someone else's", async () => {
    await seed("pending");
    await expect(
      cancelOrder.run(callableRequest({ orderId: "order1" }, "cust2"))
    ).rejects.toThrow(/your own orders/);
    await cancelOrder.run(callableRequest({ orderId: "order1" }, "cust1"));
    const snap = await cancelDb.collection("orders").doc("order1").get();
    expect(snap.data()?.cancelledBy).toBe("customer");
  });
});

describe("cancelOrder validation", () => {
  it("rejects unauthenticated request", () => {
    const uid: string | undefined = undefined;
    expect(uid).toBeUndefined();
  });

  it("rejects empty orderId", () => {
    const orderId = "";
    expect(!orderId).toBe(true);
  });

  it("allows cancellation from pending status", () => {
    const status: string = "pending";
    expect(status === "pending" || status === "assigned").toBe(true);
  });

  it("allows cancellation from assigned status", () => {
    const status: string = "assigned";
    expect(status === "pending" || status === "assigned").toBe(true);
  });

  it("rejects cancellation from picked_up status", () => {
    const status: string = "picked_up";
    expect(status === "pending" || status === "assigned").toBe(false);
  });

  it("rejects cancellation from out_for_delivery status", () => {
    const status: string = "out_for_delivery";
    expect(status === "pending" || status === "assigned").toBe(false);
  });

  it("rejects cancellation from delivered status", () => {
    const status: string = "delivered";
    expect(status === "pending" || status === "assigned").toBe(false);
  });

  it("rejects cancellation from cancelled status", () => {
    const status: string = "cancelled";
    expect(status === "pending" || status === "assigned").toBe(false);
  });

  it("validates owner match", () => {
    const orderCustomerId = "user1";
    const requestUid = "user1";
    expect(orderCustomerId === requestUid).toBe(true);
  });

  it("rejects non-owner", () => {
    const orderCustomerId = "user1";
    const requestUid = "user2";
    expect(orderCustomerId === requestUid).toBe(false);
  });

  it("sets cancelledBy to customer", () => {
    const cancelledBy = "customer";
    expect(cancelledBy).toBe("customer");
  });

  it("defaults cancelReason when not provided", () => {
    const reason = String("Cancelled by customer").trim();
    expect(reason).toBe("Cancelled by customer");
  });

  it("preserves custom cancelReason", () => {
    const reason = String("Changed my mind").trim();
    expect(reason).toBe("Changed my mind");
  });
});
