// @ts-nocheck — a stray firebase@12 in a parent node_modules shadows the
// firebase@10 types this file was written against (duplicate Firestore types);
// runtime behaviour is unaffected. Remove once that duplicate is gone.
import * as fs from "fs";
import * as path from "path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { setDoc, doc, updateDoc, getDoc } from "firebase/firestore";

const PROJECT_ID = "demo-hypermart-rules";

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: "localhost",
      port: 8090,
      rules: fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

describe("firestore.rules — orders", () => {
  it("lets a customer cancel their own pending order but not touch other fields", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "orders/order1"), {
        customerId: "cust1",
        status: "pending",
        totalAmount: 100,
      });
    });

    const asCustomer = testEnv.authenticatedContext("cust1").firestore();
    await assertSucceeds(
      updateDoc(doc(asCustomer, "orders/order1"), { status: "cancelled", updatedAt: new Date() })
    );
  });

  it("blocks a customer from cancelling someone else's order", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "orders/order1"), {
        customerId: "cust1",
        status: "pending",
        totalAmount: 100,
      });
    });

    const asOtherCustomer = testEnv.authenticatedContext("cust2").firestore();
    await assertFails(
      updateDoc(doc(asOtherCustomer, "orders/order1"), { status: "cancelled", updatedAt: new Date() })
    );
  });

  it("blocks a customer from smuggling other field changes into a cancellation", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "orders/order1"), {
        customerId: "cust1",
        status: "pending",
        totalAmount: 100,
      });
    });

    const asCustomer = testEnv.authenticatedContext("cust1").firestore();
    await assertFails(
      updateDoc(doc(asCustomer, "orders/order1"), {
        status: "cancelled",
        updatedAt: new Date(),
        totalAmount: 1, // not in the allowed hasOnly() set
      })
    );
  });

  it("lets a customer rate a delivered order exactly once", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "orders/order1"), {
        customerId: "cust1",
        status: "delivered",
        totalAmount: 100,
      });
    });

    const asCustomer = testEnv.authenticatedContext("cust1").firestore();
    await assertSucceeds(
      updateDoc(doc(asCustomer, "orders/order1"), {
        rating: 5,
        ratingComment: "Great!",
        ratedAt: new Date(),
        updatedAt: new Date(),
      })
    );
  });

  it("blocks a second rating write once the order already has one", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "orders/order1"), {
        customerId: "cust1",
        status: "delivered",
        totalAmount: 100,
        rating: 5,
      });
    });

    const asCustomer = testEnv.authenticatedContext("cust1").firestore();
    await assertFails(
      updateDoc(doc(asCustomer, "orders/order1"), { rating: 1, updatedAt: new Date() })
    );
  });

  describe("disabled / deleted riders", () => {
    async function seedPendingOrderAndRider(rider: Record<string, unknown> | null) {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        const adminDb = ctx.firestore();
        await setDoc(doc(adminDb, "orders/order1"), {
          customerId: "cust1",
          status: "pending",
          deliveryBoyId: null,
          totalAmount: 100,
        });
        await setDoc(doc(adminDb, "orderOffers/order1"), {
          status: "pending",
          deliveryBoyId: null,
          customerName: "Asha",
          village: "Bhimavaram",
          totalAmount: 100,
        });
        if (rider) await setDoc(doc(adminDb, "deliveryBoys/rider1"), rider);
      });
    }

    it("blocks a soft-deleted rider from reading offers even with a stale delivery claim", async () => {
      await seedPendingOrderAndRider({ uid: "rider1", isActive: false, isDeleted: true });

      const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
      await assertFails(getDoc(doc(asRider, "orderOffers/order1")));
    });

    it("blocks a disabled (isActive:false) rider even when their doc still exists", async () => {
      await seedPendingOrderAndRider({ uid: "rider1", isActive: false });

      const asRider = testEnv.authenticatedContext("rider1", {}).firestore();
      await assertFails(getDoc(doc(asRider, "orderOffers/order1")));
    });

    it("still lets an active rider with a doc (no claim needed) read an offer", async () => {
      await seedPendingOrderAndRider({ uid: "rider1", isActive: true });

      const asRider = testEnv.authenticatedContext("rider1", {}).firestore();
      await assertSucceeds(getDoc(doc(asRider, "orderOffers/order1")));
    });

    it("still lets a claimed rider with no doc yet read an offer (legacy path)", async () => {
      await seedPendingOrderAndRider(null);

      const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
      await assertSucceeds(getDoc(doc(asRider, "orderOffers/order1")));
    });
  });

  it("lets an assigned rider advance status exactly one step forward", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "orders/order1"), {
        deliveryBoyId: "rider1",
        status: "assigned",
        totalAmount: 100,
      });
    });

    const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
    await assertSucceeds(
      updateDoc(doc(asRider, "orders/order1"), { status: "picked_up", updatedAt: new Date() })
    );
  });

  it("blocks a rider from skipping a status step", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "orders/order1"), {
        deliveryBoyId: "rider1",
        status: "assigned",
        totalAmount: 100,
      });
    });

    const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
    await assertFails(
      updateDoc(doc(asRider, "orders/order1"), { status: "out_for_delivery", updatedAt: new Date() })
    );
  });

  it("blocks a rider from setting status directly to delivered (OTP-only path)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "orders/order1"), {
        deliveryBoyId: "rider1",
        status: "out_for_delivery",
        totalAmount: 100,
      });
    });

    const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
    await assertFails(
      updateDoc(doc(asRider, "orders/order1"), { status: "delivered", updatedAt: new Date() })
    );
  });

  it("blocks direct order creation from a client (placeOrder Cloud Function only)", async () => {
    const asCustomer = testEnv.authenticatedContext("cust1").firestore();
    await assertFails(
      setDoc(doc(asCustomer, "orders/order1"), {
        customerId: "cust1",
        status: "pending",
        totalAmount: 100,
      })
    );
  });

  it("shows a pending, unassigned order to riders only through the PII-free offer, never the full order", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const adminDb = ctx.firestore();
      await setDoc(doc(adminDb, "orders/order1"), {
        customerId: "cust1",
        customerPhone: "9999999999",
        deliveryAddress: "12 Main St",
        status: "pending",
        deliveryBoyId: null,
        totalAmount: 100,
      });
      await setDoc(doc(adminDb, "orderOffers/order1"), {
        status: "pending",
        deliveryBoyId: null,
        customerName: "Asha",
        village: "Bhimavaram",
        totalAmount: 100,
      });
    });

    const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
    await assertFails(getDoc(doc(asRider, "orders/order1")));
    await assertSucceeds(getDoc(doc(asRider, "orderOffers/order1")));
  });

  it("blocks clients (customers, riders, admins) from writing offers", async () => {
    const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
    await assertFails(setDoc(doc(asRider, "orderOffers/order1"), { status: "pending" }));
    const asAdmin = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
    await assertFails(setDoc(doc(asAdmin, "orderOffers/order1"), { status: "pending" }));
  });

  it("lets a rider read the full order once it is assigned to them", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "orders/order1"), {
        customerId: "cust1",
        status: "assigned",
        deliveryBoyId: "rider1",
        customerPhone: "9999999999",
        totalAmount: 100,
      });
    });
    const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
    await assertSucceeds(getDoc(doc(asRider, "orders/order1")));
  });

  describe("admin order writes", () => {
    async function seedOrder(status: string) {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), "orders/order1"), {
          customerId: "cust1",
          status,
          deliveryBoyId: status === "pending" ? null : "rider1",
          totalAmount: 100,
        });
      });
    }

    it("lets an admin cancel an open order", async () => {
      await seedOrder("out_for_delivery");
      const asAdmin = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
      await assertSucceeds(
        updateDoc(doc(asAdmin, "orders/order1"), {
          status: "cancelled",
          cancelReason: "test",
          cancelledBy: "admin",
          cancelledById: "admin1",
          updatedAt: new Date(),
        })
      );
    });

    it("lets an admin hand an assigned order back to the rider pool", async () => {
      await seedOrder("assigned");
      const asAdmin = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
      await assertSucceeds(
        updateDoc(doc(asAdmin, "orders/order1"), {
          status: "pending",
          deliveryBoyId: null,
          deliveryBoyName: null,
          deliveryBoyPhone: null,
          unassignedFrom: "rider1",
          updatedAt: new Date(),
        })
      );
    });

    it("blocks an admin from setting an order to delivered (OTP-only path)", async () => {
      await seedOrder("out_for_delivery");
      const asAdmin = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
      await assertFails(
        updateDoc(doc(asAdmin, "orders/order1"), { status: "delivered", updatedAt: new Date() })
      );
    });

    it("blocks an admin from editing money or re-cancelling a closed order", async () => {
      await seedOrder("out_for_delivery");
      const asAdmin = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
      await assertFails(updateDoc(doc(asAdmin, "orders/order1"), { totalAmount: 1 }));

      await testEnv.clearFirestore();
      await seedOrder("delivered");
      await assertFails(
        updateDoc(doc(asAdmin, "orders/order1"), { status: "cancelled", updatedAt: new Date() })
      );
    });

    it("blocks an admin from assigning a rider by direct write", async () => {
      await seedOrder("pending");
      const asAdmin = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
      await assertFails(
        updateDoc(doc(asAdmin, "orders/order1"), {
          status: "pending",
          deliveryBoyId: "rider1",
          updatedAt: new Date(),
        })
      );
    });

    it("ignores the admin claim once the admins doc is deactivated", async () => {
      await seedOrder("pending");
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), "admins/admin1"), { isActive: false });
      });
      const asAdmin = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
      await assertFails(getDoc(doc(asAdmin, "orders/order1")));
    });
  });

  describe("rating bounds", () => {
    async function seedDelivered() {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), "orders/order1"), {
          customerId: "cust1",
          status: "delivered",
          totalAmount: 100,
        });
      });
    }

    it("rejects a rating outside 1-5", async () => {
      await seedDelivered();
      const asCustomer = testEnv.authenticatedContext("cust1").firestore();
      await assertFails(
        updateDoc(doc(asCustomer, "orders/order1"), { rating: 99, ratedAt: new Date(), updatedAt: new Date() })
      );
    });

    it("rejects an oversized rating comment", async () => {
      await seedDelivered();
      const asCustomer = testEnv.authenticatedContext("cust1").firestore();
      await assertFails(
        updateDoc(doc(asCustomer, "orders/order1"), {
          rating: 5,
          ratingComment: "x".repeat(501),
          ratedAt: new Date(),
          updatedAt: new Date(),
        })
      );
    });

    it("accepts a valid rating with a null comment", async () => {
      await seedDelivered();
      const asCustomer = testEnv.authenticatedContext("cust1").firestore();
      await assertSucceeds(
        updateDoc(doc(asCustomer, "orders/order1"), {
          rating: 4,
          ratingComment: null,
          ratedAt: new Date(),
          updatedAt: new Date(),
        })
      );
    });
  });

  describe("user document size caps", () => {
    it("rejects an oversized cart and accepts a normal one", async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), "users/cust1"), { role: "customer", isActive: true });
      });
      const asCustomer = testEnv.authenticatedContext("cust1").firestore();
      const bigCart: Record<string, unknown> = {};
      for (let i = 0; i < 101; i++) bigCart[`p${i}`] = { quantity: 1 };
      await assertFails(updateDoc(doc(asCustomer, "users/cust1"), { cart: bigCart }));
      await assertSucceeds(updateDoc(doc(asCustomer, "users/cust1"), { cart: { p1: { quantity: 1 } } }));
    });
  });

  it("still blocks a rider from reading an order already assigned to someone else", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "orders/order1"), {
        customerId: "cust1",
        status: "assigned",
        deliveryBoyId: "otherRider",
        totalAmount: 100,
      });
    });

    const { getDoc } = await import("firebase/firestore");
    const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
    await assertFails(getDoc(doc(asRider, "orders/order1")));
  });

  it("blocks a rider from directly writing deliveryBoyId on the client (claiming stays callable-only)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "orders/order1"), {
        customerId: "cust1",
        status: "pending",
        deliveryBoyId: null,
        totalAmount: 100,
      });
    });

    const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
    await assertFails(
      updateDoc(doc(asRider, "orders/order1"), {
        status: "assigned",
        deliveryBoyId: "rider1",
        updatedAt: new Date(),
      })
    );
  });

  it("hides the delivery OTP from riders and admins, exposing it only to the ordering customer", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      // One firestore() per context — a second call re-applies settings to an
      // instance that's already in use and throws.
      const adminDb = ctx.firestore();
      await setDoc(doc(adminDb, "orders/order1"), { customerId: "cust1", status: "out_for_delivery" });
      await setDoc(doc(adminDb, "orders/order1/private/delivery"), { otp: "1234", attempts: 0 });
    });

    const asCustomer = testEnv.authenticatedContext("cust1").firestore();
    await assertSucceeds(getDoc(doc(asCustomer, "orders/order1/private/delivery")));

    const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
    await assertFails(getDoc(doc(asRider, "orders/order1/private/delivery")));

    const asAdmin = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
    await assertFails(getDoc(doc(asAdmin, "orders/order1/private/delivery")));
  });
});

describe("firestore.rules — deliveryBoys self-registration", () => {
  // createRiderLogin now writes `uid` (= doc id = auth uid) when it creates the
  // rider, so the old "claim an unlinked whitelist doc by matching email" path
  // was removed from the rules. It must stay closed: a matching email alone
  // must NOT let an arbitrary signed-in user take over a rider doc.
  it("no longer lets a signed-in user claim an unlinked rider doc just by matching its email", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "deliveryBoys/riderDoc1"), {
        email: "rider@example.com",
        name: "Test Rider",
        isActive: true,
      });
    });

    const asRider = testEnv
      .authenticatedContext("rider1", { email: "rider@example.com" })
      .firestore();
    await assertFails(updateDoc(doc(asRider, "deliveryBoys/riderDoc1"), { uid: "rider1" }));
  });

  it("blocks a rider from changing fields beyond uid/fcmTokens during self-registration", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "deliveryBoys/riderDoc1"), {
        email: "rider@example.com",
        name: "Test Rider",
        isActive: true,
      });
    });

    const asRider = testEnv
      .authenticatedContext("rider1", { email: "rider@example.com" })
      .firestore();
    await assertFails(
      updateDoc(doc(asRider, "deliveryBoys/riderDoc1"), { uid: "rider1", isActive: false })
    );
  });

  it("lets an already-registered rider update their own fcmTokens without touching uid", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "deliveryBoys/riderDoc1"), {
        email: "rider@example.com",
        uid: "rider1",
        name: "Test Rider",
        isActive: true,
        fcmTokens: [],
      });
    });

    const asRider = testEnv
      .authenticatedContext("rider1", { email: "rider@example.com" })
      .firestore();
    await assertSucceeds(
      updateDoc(doc(asRider, "deliveryBoys/riderDoc1"), { fcmTokens: ["token-abc"] })
    );
  });

  it("blocks a rider from changing uid to someone else's while also updating fcmTokens", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "deliveryBoys/riderDoc1"), {
        email: "rider@example.com",
        uid: "rider1",
        name: "Test Rider",
        isActive: true,
        fcmTokens: [],
      });
    });

    const asRider = testEnv
      .authenticatedContext("rider1", { email: "rider@example.com" })
      .firestore();
    await assertFails(
      updateDoc(doc(asRider, "deliveryBoys/riderDoc1"), {
        uid: "someone-else",
        fcmTokens: ["token-abc"],
      })
    );
  });

  it("blocks self-registration when the authenticated email doesn't match the whitelist doc", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "deliveryBoys/riderDoc1"), {
        email: "rider@example.com",
        name: "Test Rider",
        isActive: true,
      });
    });

    const asImposter = testEnv
      .authenticatedContext("imposter1", { email: "someone-else@example.com" })
      .firestore();
    await assertFails(updateDoc(doc(asImposter, "deliveryBoys/riderDoc1"), { uid: "imposter1" }));
  });
});

describe("firestore.rules — deliveryBoys onDuty / profile self-edit", () => {
  it("lets a registered rider toggle their own onDuty flag", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "deliveryBoys/rider1"), {
        email: "rider@example.com",
        uid: "rider1",
        name: "Test Rider",
        isActive: true,
        onDuty: true,
      });
    });

    const asRider = testEnv
      .authenticatedContext("rider1", { email: "rider@example.com" })
      .firestore();
    await assertSucceeds(updateDoc(doc(asRider, "deliveryBoys/rider1"), { onDuty: false }));
  });

  it("lets a registered rider edit their own avatarUrl and vehicleDetails", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "deliveryBoys/rider1"), {
        email: "rider@example.com",
        uid: "rider1",
        name: "Test Rider",
        isActive: true,
        onDuty: true,
      });
    });

    const asRider = testEnv
      .authenticatedContext("rider1", { email: "rider@example.com" })
      .firestore();
    await assertSucceeds(
      updateDoc(doc(asRider, "deliveryBoys/rider1"), {
        avatarUrl: "https://example.com/a.jpg",
        vehicleDetails: "Bike - AP1234",
      })
    );
  });

  // village is on the rider self-edit allowlist (Edit Profile screen); only the
  // admin-controlled isActive flag must stay locked.
  it("lets a rider edit their own village but still blocks touching isActive while updating onDuty", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "deliveryBoys/rider1"), {
        email: "rider@example.com",
        uid: "rider1",
        name: "Test Rider",
        isActive: true,
        onDuty: true,
        village: "Bhimavaram",
      });
    });

    const asRider = testEnv
      .authenticatedContext("rider1", { email: "rider@example.com" })
      .firestore();
    await assertFails(
      updateDoc(doc(asRider, "deliveryBoys/rider1"), { onDuty: false, isActive: false })
    );
    await assertSucceeds(
      updateDoc(doc(asRider, "deliveryBoys/rider1"), { onDuty: false, village: "Rayakuduru" })
    );
  });
});

describe("firestore.rules — products", () => {
  it("lets anyone, even unauthenticated, read the catalog", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "products/prod1"), { name: "Milk", price: 50 });
    });

    const { getDoc } = await import("firebase/firestore");
    const asAnon = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(asAnon, "products/prod1")));
  });

  it("blocks an unauthenticated client from creating a product", async () => {
    const asAnon = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(asAnon, "products/prod1"), { name: "Milk", price: 50 })
    );
  });

  it("blocks a signed-in non-admin from creating or updating a product", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "products/prod1"), { name: "Milk", price: 50 });
    });

    const asCustomer = testEnv.authenticatedContext("cust1").firestore();
    await assertFails(setDoc(doc(asCustomer, "products/prod2"), { name: "Bread", price: 30 }));
    await assertFails(updateDoc(doc(asCustomer, "products/prod1"), { price: 1 }));
  });

  it("blocks an admin from setting a zero or negative price", async () => {
    const asAdmin = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
    await assertFails(setDoc(doc(asAdmin, "products/prod1"), { name: "Milk", price: 0 }));
    await assertFails(setDoc(doc(asAdmin, "products/prod2"), { name: "Milk", price: -5 }));
  });

  it("lets an admin create and update a product with a positive price", async () => {
    const asAdmin = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
    await assertSucceeds(setDoc(doc(asAdmin, "products/prod1"), { name: "Milk", price: 50 }));
    await assertSucceeds(updateDoc(doc(asAdmin, "products/prod1"), { price: 55 }));
  });
});

describe("firestore.rules — config", () => {
  it("blocks a non-admin from writing store config", async () => {
    const asCustomer = testEnv.authenticatedContext("cust1").firestore();
    await assertFails(setDoc(doc(asCustomer, "config/app"), { storeOpen: false }));
  });

  it("lets an admin write store config", async () => {
    const asAdmin = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
    await assertSucceeds(setDoc(doc(asAdmin, "config/app"), { storeOpen: false }));
  });
});

describe("firestore.rules — users self-update", () => {
  it("lets a customer update their own profile fields but not their role", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "users/cust1"), {
        name: "Old Name",
        role: "customer",
        isActive: true,
      });
    });

    const asCustomer = testEnv.authenticatedContext("cust1").firestore();
    await assertSucceeds(updateDoc(doc(asCustomer, "users/cust1"), { name: "New Name" }));
    await assertFails(updateDoc(doc(asCustomer, "users/cust1"), { role: "admin" }));
  });
});
