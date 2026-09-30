import { rejectOrderOffer } from "../src/index";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestore, callableRequest } from "./testUtils";

const db = getFirestore();

const rejected = async (uid: string) =>
  (await db.collection("deliveryBoys").doc(uid).collection("rejectedOffers").get()).docs.map((d) => d.id);

describe("rejectOrderOffer", () => {
  beforeEach(async () => {
    await clearFirestore();
    await db.collection("deliveryBoys").doc("rider1").set({ name: "R", isActive: true, onDuty: true });
    await db.collection("orderOffers").doc("order1").set({ status: "pending" });
  });

  it("persists the rejection for that rider only, leaving the order untouched", async () => {
    await db.collection("orders").doc("order1").set({ status: "pending" });
    await rejectOrderOffer.run(callableRequest({ orderId: "order1" }, "rider1", { delivery: true }));
    expect(await rejected("rider1")).toEqual(["order1"]);
    expect(await rejected("rider2")).toEqual([]);
    expect((await db.collection("orders").doc("order1").get()).data()?.status).toBe("pending");
    expect((await db.collection("orderOffers").doc("order1").get()).exists).toBe(true);
  });

  it("is idempotent", async () => {
    const req = () => callableRequest({ orderId: "order1" }, "rider1", { delivery: true });
    await rejectOrderOffer.run(req());
    await rejectOrderOffer.run(req());
    expect(await rejected("rider1")).toEqual(["order1"]);
  });

  it("ignores ids that are not open offers", async () => {
    await rejectOrderOffer.run(callableRequest({ orderId: "nope" }, "rider1", { delivery: true }));
    expect(await rejected("rider1")).toEqual([]);
  });

  it("refuses non-riders, unauthenticated callers and deactivated riders", async () => {
    await expect(
      rejectOrderOffer.run(callableRequest({ orderId: "order1" }, "cust1", {}))
    ).rejects.toThrow(/delivery partners/);
    await db.collection("deliveryBoys").doc("rider1").update({ isActive: false });
    await expect(
      rejectOrderOffer.run(callableRequest({ orderId: "order1" }, "rider1", { delivery: true }))
    ).rejects.toThrow(/deactivated/);
  });
});
