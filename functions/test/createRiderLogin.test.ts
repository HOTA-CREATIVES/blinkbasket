import { createRiderLogin } from "../src/index";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { clearFirestore, callableRequest } from "./testUtils";

const db = getFirestore();
const auth = getAuth();

async function seedAdmin(uid: string, overrides: Record<string, unknown> = {}) {
  await db.collection("admins").doc(uid).set({ isActive: true, ...overrides });
}

describe("createRiderLogin", () => {
  beforeEach(async () => {
    await clearFirestore();
  });

  it("rejects a non-admin caller", async () => {
    await expect(
      createRiderLogin.run(
        callableRequest(
          { email: "rider1@example.com", name: "Rider One", phone: "9876543210", village: "Bhimavaram" },
          "cust1"
        )
      )
    ).rejects.toThrow(/Only active admins/);
  });

  it("rejects a deactivated admin", async () => {
    await seedAdmin("admin1", { isActive: false });

    await expect(
      createRiderLogin.run(
        callableRequest(
          { email: "rider1@example.com", name: "Rider One", phone: "9876543210", village: "Bhimavaram" },
          "admin1"
        )
      )
    ).rejects.toThrow(/Only active admins/);
  });

  it("generates a temporary password rather than accepting one from the caller, and whitelists the rider", async () => {
    await seedAdmin("admin1");

    const result = await createRiderLogin.run(
      callableRequest(
        {
          email: "rider1@example.com",
          name: "Rider One",
          phone: "9876543210",
          village: "Bhimavaram",
          password: "whatever-the-client-sends-is-ignored",
        },
        "admin1"
      )
    );

    expect(result.success).toBe(true);
    expect(typeof result.temporaryPassword).toBe("string");
    expect(result.temporaryPassword.length).toBeGreaterThanOrEqual(8);

    const userRecord = await auth.getUser(result.uid);
    expect(userRecord.email).toBe("rider1@example.com");

    const riderDoc = await db.collection("deliveryBoys").doc(result.uid).get();
    expect(riderDoc.exists).toBe(true);
    expect(riderDoc.data()?.role).toBe("delivery");

    const claims = (await auth.getUser(result.uid)).customClaims;
    expect(claims?.delivery).toBe(true);
  });

  it("rejects when required rider details are missing", async () => {
    await seedAdmin("admin1");

    await expect(
      createRiderLogin.run(
        callableRequest({ email: "", name: "Rider One", phone: "9876543210", village: "Bhimavaram" }, "admin1")
      )
    ).rejects.toThrow(/Missing or invalid/);
  });
});
