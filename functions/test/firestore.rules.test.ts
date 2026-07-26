import * as fs from "fs";
import * as path from "path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { setDoc, doc, updateDoc } from "firebase/firestore";

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

  it("lets any on-duty rider read a pending, unassigned order (Blinkit-style broadcast visibility)", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "orders/order1"), {
        customerId: "cust1",
        status: "pending",
        deliveryBoyId: null,
        totalAmount: 100,
      });
    });

    const { getDoc } = await import("firebase/firestore");
    const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
    await assertSucceeds(getDoc(doc(asRider, "orders/order1")));
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
      await setDoc(doc(ctx.firestore(), "orders/order1"), { customerId: "cust1", status: "out_for_delivery" });
      await setDoc(doc(ctx.firestore(), "orders/order1/private/delivery"), { otp: "1234", attempts: 0 });
    });

    const { getDoc } = await import("firebase/firestore");

    const asCustomer = testEnv.authenticatedContext("cust1").firestore();
    await assertSucceeds(getDoc(doc(asCustomer, "orders/order1/private/delivery")));

    const asRider = testEnv.authenticatedContext("rider1", { delivery: true }).firestore();
    await assertFails(getDoc(doc(asRider, "orders/order1/private/delivery")));

    const asAdmin = testEnv.authenticatedContext("admin1", { admin: true }).firestore();
    await assertFails(getDoc(doc(asAdmin, "orders/order1/private/delivery")));
  });
});

describe("firestore.rules — deliveryBoys self-registration", () => {
  it("lets a rider lock in their own uid by matching email, and nothing else", async () => {
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
    await assertSucceeds(updateDoc(doc(asRider, "deliveryBoys/riderDoc1"), { uid: "rider1" }));
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

  it("still blocks a rider from touching isActive or village while updating onDuty", async () => {
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
    await assertFails(
      updateDoc(doc(asRider, "deliveryBoys/rider1"), { onDuty: false, village: "Rayakuduru" })
    );
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
