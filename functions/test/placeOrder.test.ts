import { placeOrder } from "../src/index";
import { getFirestore } from "firebase-admin/firestore";
import { clearFirestore, callableRequest } from "./testUtils";

const db = getFirestore();

async function seedUser(uid: string, overrides: Record<string, unknown> = {}) {
  await db.collection("users").doc(uid).set({
    name: "Test Customer",
    phone: "9876543210",
    village: "Bhimavaram",
    role: "customer",
    isActive: true,
    ...overrides,
  });
}

async function seedProduct(id: string, overrides: Record<string, unknown> = {}) {
  await db.collection("products").doc(id).set({
    name: "Test Product",
    price: 50,
    physicalStock: 10,
    reservedStock: 0,
    availableStock: 10,
    ...overrides,
  });
}

async function seedConfig(overrides: Record<string, unknown> = {}) {
  await db.collection("config").doc("app").set({
    storeOpen: true,
    deliveryFee: 30,
    freeDeliveryAbove: 300,
    ...overrides,
  });
}

describe("placeOrder", () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  it("computes totals server-side and decrements stock, ignoring any client-sent price", async () => {
    await seedUser("cust1");
    await seedProduct("prod1", { price: 50, physicalStock: 10, availableStock: 10 });
    await seedConfig();

    const result = await placeOrder.run(
      callableRequest(
        {
          items: [{ productId: "prod1", quantity: 2, price: 1 }],
          deliveryAddress: "12 Main Street, Bhimavaram",
          latitude: 16.5449,
          longitude: 81.5212,
        },
        "cust1"
      )
    );

    expect(result.subtotal).toBe(100);
    expect(result.deliveryFee).toBe(30);
    expect(result.totalAmount).toBe(130);
    expect(result.otp).toMatch(/^\d{4}$/);

    const productSnap = await db.collection("products").doc("prod1").get();
    expect(productSnap.data()?.reservedStock).toBe(2);
    expect(productSnap.data()?.availableStock).toBe(8);

    const orderSnap = await db.collection("orders").doc(result.orderId).get();
    expect(orderSnap.data()?.status).toBe("pending");
    expect(orderSnap.data()?.items[0].price).toBe(50);
  });

  it("waives the delivery fee once the subtotal exceeds the free-delivery threshold", async () => {
    await seedUser("cust1");
    await seedProduct("prod1", { price: 200, availableStock: 10 });
    await seedConfig({ freeDeliveryAbove: 300 });

    const result = await placeOrder.run(
      callableRequest(
        {
          items: [{ productId: "prod1", quantity: 2 }],
          deliveryAddress: "Addr",
          latitude: 16.5449,
          longitude: 81.5212,
        },
        "cust1"
      )
    );

    expect(result.subtotal).toBe(400);
    expect(result.deliveryFee).toBe(0);
    expect(result.totalAmount).toBe(400);
  });

  it("rejects when requested quantity exceeds available stock", async () => {
    await seedUser("cust1");
    await seedProduct("prod1", { availableStock: 1 });
    await seedConfig();

    await expect(
      placeOrder.run(
        callableRequest(
          {
            items: [{ productId: "prod1", quantity: 5 }],
            deliveryAddress: "Addr",
            latitude: 16.5449,
            longitude: 81.5212,
          },
          "cust1"
        )
      )
    ).rejects.toThrow(/only 1 units available/);
  });

  it("rejects duplicate products in the same order", async () => {
    await seedUser("cust1");
    await seedProduct("prod1");
    await seedConfig();

    await expect(
      placeOrder.run(
        callableRequest(
          {
            items: [
              { productId: "prod1", quantity: 1 },
              { productId: "prod1", quantity: 1 },
            ],
            deliveryAddress: "Addr",
            latitude: 16.5449,
            longitude: 81.5212,
          },
          "cust1"
        )
      )
    ).rejects.toThrow(/Duplicate product/);
  });

  it("rejects when the store is closed", async () => {
    await seedUser("cust1");
    await seedProduct("prod1");
    await seedConfig({ storeOpen: false });

    await expect(
      placeOrder.run(
        callableRequest(
          {
            items: [{ productId: "prod1", quantity: 1 }],
            deliveryAddress: "Addr",
            latitude: 16.5449,
            longitude: 81.5212,
          },
          "cust1"
        )
      )
    ).rejects.toThrow(/store is currently closed/);
  });

  it("rejects more than the max distinct items per order", async () => {
    await seedUser("cust1");
    await seedConfig();
    const items = Array.from({ length: 51 }, (_, i) => ({ productId: `p${i}`, quantity: 1 }));

    await expect(
      placeOrder.run(callableRequest({ items, deliveryAddress: "Addr" }, "cust1"))
    ).rejects.toThrow(/Too many distinct items/);
  });

  it("rejects an unauthenticated caller", async () => {
    await expect(
      placeOrder.run(
        callableRequest({ items: [{ productId: "prod1", quantity: 1 }], deliveryAddress: "Addr" }, null)
      )
    ).rejects.toThrow(/Sign in/);
  });

  it("rejects when delivery coordinates are missing", async () => {
    await seedUser("cust1");
    await seedProduct("prod1");
    await seedConfig();

    await expect(
      placeOrder.run(
        callableRequest(
          { items: [{ productId: "prod1", quantity: 1 }], deliveryAddress: "Addr" },
          "cust1"
        )
      )
    ).rejects.toThrow(/GPS coordinates/);
  });

  it("rejects delivery coordinates far outside the service area", async () => {
    await seedUser("cust1");
    await seedProduct("prod1");
    await seedConfig();

    await expect(
      placeOrder.run(
        callableRequest(
          {
            items: [{ productId: "prod1", quantity: 1 }],
            deliveryAddress: "Somewhere else",
            latitude: 19.076,
            longitude: 72.8777,
          },
          "cust1"
        )
      )
    ).rejects.toThrow(/outside our service area/);
  });

  it("accepts delivery coordinates within the service radius", async () => {
    await seedUser("cust1");
    await seedProduct("prod1");
    await seedConfig();

    const result = await placeOrder.run(
      callableRequest(
        {
          items: [{ productId: "prod1", quantity: 1 }],
          deliveryAddress: "Near Bhimavaram",
          latitude: 16.55,
          longitude: 81.52,
        },
        "cust1"
      )
    );
    expect(result.orderId).toBeTruthy();
  });
});
