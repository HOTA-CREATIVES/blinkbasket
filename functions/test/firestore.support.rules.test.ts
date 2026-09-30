// @ts-nocheck — same duplicate-firebase-types situation as firestore.rules.test.ts.
import * as fs from "fs";
import * as path from "path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { setDoc, doc, updateDoc, getDoc, writeBatch } from "firebase/firestore";

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-hypermart-support-rules",
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

const ticket = (over: Record<string, unknown> = {}) => ({
  customerId: "cust1",
  customerName: "Test Customer",
  customerPhone: "9876543210",
  subject: "Late order",
  category: "order",
  status: "open",
  priority: "normal",
  createdAt: new Date(),
  updatedAt: new Date(),
  lastMessage: "hi",
  unreadCustomerCount: 0,
  unreadAdminCount: 1,
  ...over,
});

const message = (over: Record<string, unknown> = {}) => ({
  ticketId: "t1",
  senderId: "cust1",
  senderName: "Test Customer",
  senderRole: "customer",
  message: "hello",
  timestamp: new Date(),
  isRead: false,
  ...over,
});

async function seedTicket(over: Record<string, unknown> = {}) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "supportTickets/t1"), ticket(over));
  });
}

const asCustomer = () => testEnv.authenticatedContext("cust1").firestore();
const asOtherCustomer = () => testEnv.authenticatedContext("cust2").firestore();
const asAdmin = () => testEnv.authenticatedContext("admin1", { admin: true }).firestore();

describe("support tickets — creating", () => {
  it("lets a customer open a ticket with its first message and the system welcome in one batch", async () => {
    const db = asCustomer();
    const batch = writeBatch(db);
    batch.set(doc(db, "supportTickets/t9"), ticket());
    batch.set(doc(db, "supportTickets/t9/messages/m1"), message({ ticketId: "t9" }));
    batch.set(
      doc(db, "supportTickets/t9/messages/m2"),
      message({ ticketId: "t9", senderId: "system", senderName: "Support Bot", senderRole: "system" })
    );
    await assertSucceeds(batch.commit());
  });

  it("blocks opening a ticket on behalf of another customer", async () => {
    await assertFails(setDoc(doc(asCustomer(), "supportTickets/t9"), ticket({ customerId: "cust2" })));
  });

  it("blocks opening a ticket that is already resolved", async () => {
    await assertFails(setDoc(doc(asCustomer(), "supportTickets/t9"), ticket({ status: "resolved" })));
  });

  it("blocks unknown extra fields on a new ticket", async () => {
    await assertFails(setDoc(doc(asCustomer(), "supportTickets/t9"), ticket({ assignedTo: "admin1" })));
  });
});

describe("support tickets — updating", () => {
  it("blocks a customer from handing their ticket to another customer", async () => {
    await seedTicket();
    await assertFails(updateDoc(doc(asCustomer(), "supportTickets/t1"), { customerId: "cust2" }));
  });

  it("lets a customer resolve and reopen their own ticket", async () => {
    await seedTicket();
    await assertSucceeds(updateDoc(doc(asCustomer(), "supportTickets/t1"), { status: "resolved", updatedAt: new Date() }));
    await assertSucceeds(updateDoc(doc(asCustomer(), "supportTickets/t1"), { status: "open", updatedAt: new Date() }));
  });

  it("blocks a customer from setting admin-controlled statuses", async () => {
    await seedTicket();
    await assertFails(updateDoc(doc(asCustomer(), "supportTickets/t1"), { status: "closed" }));
    await assertFails(updateDoc(doc(asCustomer(), "supportTickets/t1"), { status: "in_progress" }));
  });

  it("blocks a customer from changing fields beyond conversation bookkeeping", async () => {
    await seedTicket();
    await assertFails(updateDoc(doc(asCustomer(), "supportTickets/t1"), { priority: "urgent" }));
    await assertFails(updateDoc(doc(asCustomer(), "supportTickets/t1"), { subject: "changed" }));
  });

  it("lets a customer bump lastMessage / unread counters (what sending a message does)", async () => {
    await seedTicket();
    await assertSucceeds(
      updateDoc(doc(asCustomer(), "supportTickets/t1"), {
        lastMessage: "more",
        updatedAt: new Date(),
        unreadAdminCount: 2,
      })
    );
  });

  it("blocks a different customer from touching the ticket", async () => {
    await seedTicket();
    await assertFails(updateDoc(doc(asOtherCustomer(), "supportTickets/t1"), { lastMessage: "x" }));
  });

  it("lets an admin change any field", async () => {
    await seedTicket();
    await assertSucceeds(updateDoc(doc(asAdmin(), "supportTickets/t1"), { status: "closed", priority: "urgent" }));
  });
});

describe("support messages", () => {
  it("lets a customer post as themselves in their own ticket", async () => {
    await seedTicket();
    await assertSucceeds(setDoc(doc(asCustomer(), "supportTickets/t1/messages/m1"), message()));
  });

  it("blocks a customer from posting as an admin (impersonation)", async () => {
    await seedTicket();
    await assertFails(
      setDoc(doc(asCustomer(), "supportTickets/t1/messages/m1"), message({ senderRole: "admin", senderId: "admin1" }))
    );
  });

  it("blocks a customer from posting under someone else's id", async () => {
    await seedTicket();
    await assertFails(setDoc(doc(asCustomer(), "supportTickets/t1/messages/m1"), message({ senderId: "cust2" })));
  });

  it("blocks oversized messages and unknown fields", async () => {
    await seedTicket();
    await assertFails(
      setDoc(doc(asCustomer(), "supportTickets/t1/messages/m1"), message({ message: "x".repeat(2001) }))
    );
    await assertFails(setDoc(doc(asCustomer(), "supportTickets/t1/messages/m2"), message({ isPinned: true })));
  });

  it("blocks a different customer from posting in, or reading, someone else's ticket", async () => {
    await seedTicket();
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "supportTickets/t1/messages/m0"), message());
    });
    await assertFails(
      setDoc(doc(asOtherCustomer(), "supportTickets/t1/messages/m1"), message({ senderId: "cust2" }))
    );
    await assertFails(getDoc(doc(asOtherCustomer(), "supportTickets/t1/messages/m0")));
  });

  it("lets an admin reply as admin, and blocks a customer from editing or deleting messages", async () => {
    await seedTicket();
    await assertSucceeds(
      setDoc(doc(asAdmin(), "supportTickets/t1/messages/a1"), message({ senderRole: "admin", senderId: "admin1" }))
    );
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "supportTickets/t1/messages/m0"), message());
    });
    await assertFails(updateDoc(doc(asCustomer(), "supportTickets/t1/messages/m0"), { message: "edited" }));
  });
});
