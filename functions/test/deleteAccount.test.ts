import { deleteAccount } from "../src/index";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { clearAuth, clearFirestore, callableRequest } from "./testUtils";

const db = getFirestore();

async function seedCustomer(uid: string) {
  await getAuth().createUser({ uid, email: `${uid}@example.com`, password: "Passw0rd!x" });
  await db.collection("users").doc(uid).set({
    uid,
    name: "Real Name",
    email: `${uid}@example.com`,
    phone: "9876543210",
    role: "customer",
    isActive: true,
    village: "Bhimavaram",
    addresses: [{ id: "a1", name: "Home", addressLine1: "12 Main Rd" }],
    fcmTokens: ["tok"],
    favoriteProductIds: ["p1"],
    cart: { p1: { quantity: 2 } },
  });
}

async function seedOrder(id: string, uid: string, status: string) {
  await db.collection("orders").doc(id).set({
    customerId: uid,
    customerName: "Real Name",
    customerPhone: "9876543210",
    deliveryAddress: "12 Main Rd, Bhimavaram",
    deliveryInstructions: "Ring twice",
    village: "Bhimavaram",
    latitude: 16.546,
    longitude: 81.5225,
    status,
    totalAmount: 130,
    items: [{ productId: "p1", name: "Milk", price: 50, quantity: 2 }],
    createdAt: Timestamp.now(),
  });
}

async function authUserExists(uid: string) {
  try {
    await getAuth().getUser(uid);
    return true;
  } catch {
    return false;
  }
}

describe("deleteAccount", () => {
  beforeEach(async () => {
    await clearFirestore();
    await clearAuth();
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(deleteAccount.run(callableRequest({}, null))).rejects.toThrow(/Sign in/);
  });

  it("refuses while the customer has an order in progress, and changes nothing", async () => {
    await seedCustomer("cust1");
    await seedOrder("order1", "cust1", "out_for_delivery");

    await expect(deleteAccount.run(callableRequest({}, "cust1"))).rejects.toThrow(/order in progress/);

    expect((await db.collection("users").doc("cust1").get()).data()?.name).toBe("Real Name");
    expect((await db.collection("orders").doc("order1").get()).data()?.customerName).toBe("Real Name");
    expect(await authUserExists("cust1")).toBe(true);
  });

  it("refuses rider and admin accounts (an admin removes those)", async () => {
    await seedCustomer("rider1");
    await expect(
      deleteAccount.run(callableRequest({}, "rider1", { delivery: true }))
    ).rejects.toThrow(/removed by an administrator/);
    await expect(
      deleteAccount.run(callableRequest({}, "rider1", { admin: true }))
    ).rejects.toThrow(/removed by an administrator/);
    expect(await authUserExists("rider1")).toBe(true);
  });

  it("scrubs identifying fields from past orders but keeps amounts and items", async () => {
    await seedCustomer("cust1");
    await seedOrder("order1", "cust1", "delivered");
    await seedOrder("order2", "cust1", "cancelled");

    await deleteAccount.run(callableRequest({}, "cust1"));

    for (const id of ["order1", "order2"]) {
      const o = (await db.collection("orders").doc(id).get()).data()!;
      expect(o.customerName).toBe("Deleted User");
      expect(o.customerPhone).toBe("");
      expect(o.deliveryAddress).toBe("");
      expect(o.deliveryInstructions).toBeNull();
      expect(o.latitude).toBeNull();
      expect(o.longitude).toBeNull();
      // Kept for accounting.
      expect(o.totalAmount).toBe(130);
      expect(o.items).toHaveLength(1);
      expect(o.village).toBe("Bhimavaram");
    }
  });

  it("deletes support tickets together with their messages", async () => {
    await seedCustomer("cust1");
    await db.collection("supportTickets").doc("t1").set({ customerId: "cust1", customerName: "Real Name" });
    await db.collection("supportTickets").doc("t1").collection("messages").doc("m1").set({ message: "my number is 98765" });
    await db.collection("supportTickets").doc("t2").set({ customerId: "someoneElse" });

    await deleteAccount.run(callableRequest({}, "cust1"));

    expect((await db.collection("supportTickets").doc("t1").get()).exists).toBe(false);
    expect((await db.collection("supportTickets").doc("t1").collection("messages").get()).empty).toBe(true);
    // Another customer's ticket is untouched.
    expect((await db.collection("supportTickets").doc("t2").get()).exists).toBe(true);
  });

  it("anonymizes the profile, drops cart/favourites/addresses, clears the order lock, and deletes the auth user", async () => {
    await seedCustomer("cust1");
    await db.collection("orderLocks").doc("cust1").set({ orderId: "old" });

    const result = await deleteAccount.run(callableRequest({}, "cust1"));
    expect(result.success).toBe(true);

    const u = (await db.collection("users").doc("cust1").get()).data()!;
    expect(u.name).toBe("Deleted User");
    expect(u.email).toBe("");
    expect(u.phone).toBe("");
    expect(u.isDeleted).toBe(true);
    expect(u.isActive).toBe(false);
    expect(u.addresses).toEqual([]);
    expect(u.fcmTokens).toEqual([]);
    expect(u.favoriteProductIds).toEqual([]);
    expect(u.cart).toBeUndefined();
    expect((await db.collection("orderLocks").doc("cust1").get()).exists).toBe(false);
    expect(await authUserExists("cust1")).toBe(false);
  });

  it("is retryable: running it again after a partial run still succeeds", async () => {
    await seedCustomer("cust1");
    await seedOrder("order1", "cust1", "delivered");
    // Simulate a previous run that scrubbed data but died before deleting the auth user.
    await db.collection("orders").doc("order1").update({ customerName: "Deleted User" });

    await expect(deleteAccount.run(callableRequest({}, "cust1"))).resolves.toEqual({ success: true });
    expect(await authUserExists("cust1")).toBe(false);
  });
});
