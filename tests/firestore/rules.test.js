const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
  Timestamp,
} = require("firebase/firestore");

const projectId = "demo-pos-podda-rules";
const rules = fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8");
let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({ projectId, firestore: { rules } });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

function profile(uid, overrides = {}) {
  return {
    uid,
    email: `${uid}@example.com`,
    name: uid,
    mobile: "",
    role: "cashier",
    shopId: "owner-1",
    isActive: true,
    isDeleted: false,
    permissions: {},
    ...overrides,
  };
}

async function seed(pathName, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), pathName), data);
  });
}

async function seedShopMembers(overrides = {}) {
  await seed("users/owner-1", profile("owner-1", {
    role: "owner",
    shopId: "owner-1",
    isActive: true,
    permissions: {},
    ...overrides.owner,
  }));
  if (overrides.cashier !== false) {
    await seed("users/cashier-1", profile("cashier-1", {
      email: "cashier@shop.sme",
      role: "cashier",
      shopId: "owner-1",
      permissions: { CAN_CHECKOUT: true },
      ...overrides.cashier,
    }));
  }
  if (overrides.stockkeeper !== false) {
    await seed("users/stockkeeper-1", profile("stockkeeper-1", {
      email: "stockkeeper@shop.sme",
      role: "stockkeeper",
      shopId: "owner-1",
      permissions: { CAN_MANAGE_INVENTORY: true, CAN_CHECKOUT: false },
      ...overrides.stockkeeper,
    }));
  }
}

function sale(uid, id = "sale-1") {
  return {
    id,
    timestamp: Timestamp.fromDate(new Date()),
    totalAmount: 100,
    paymentMethod: "CASH",
    amountPaid: 100,
    isFullyPaid: true,
    items: [],
    productIds: [],
    userId: uid,
  };
}

test("a cashier with CAN_CHECKOUT may create a sale but cannot read history without report/credit permission", async () => {
  await seedShopMembers();
  const db = testEnv.authenticatedContext("cashier-1", {
    email: "cashier@shop.sme",
    email_verified: false,
  }).firestore();

  await assertSucceeds(setDoc(doc(db, "shops/owner-1/sales/sale-1"), sale("cashier-1")));
  await assertFails(getDoc(doc(db, "shops/owner-1/sales/sale-1")));
});

test("a stockkeeper without CAN_CHECKOUT cannot create a sale", async () => {
  await seedShopMembers();
  const db = testEnv.authenticatedContext("stockkeeper-1", {
    email: "stockkeeper@shop.sme",
    email_verified: false,
  }).firestore();

  await assertFails(setDoc(doc(db, "shops/owner-1/sales/sale-1"), sale("stockkeeper-1")));
});

test("manager access follows the stored permission map rather than role", async () => {
  await seedShopMembers({ cashier: false, stockkeeper: false });
  await seed("users/manager-1", profile("manager-1", {
    email: "manager@shop.sme",
    role: "manager",
    permissions: { CAN_CHECKOUT: false },
  }));
  const db = testEnv.authenticatedContext("manager-1", {
    email: "manager@shop.sme",
    email_verified: false,
  }).firestore();

  await assertFails(setDoc(doc(db, "shops/owner-1/sales/manager-sale-1"), sale("manager-1", "manager-sale-1")));
  await seed("users/manager-1", profile("manager-1", {
    email: "manager@shop.sme",
    role: "manager",
    permissions: { CAN_CHECKOUT: true },
  }));
  await assertSucceeds(setDoc(doc(db, "shops/owner-1/sales/manager-sale-2"), sale("manager-1", "manager-sale-2")));
});

test("inactive shop members cannot access the shop root", async () => {
  await seedShopMembers({ cashier: { isActive: false } });
  const db = testEnv.authenticatedContext("cashier-1", {
    email: "cashier@shop.sme",
    email_verified: false,
  }).firestore();

  await assertFails(getDoc(doc(db, "shops/owner-1")));
});

test("clients cannot update their own subscription entitlement", async () => {
  await seedShopMembers({ cashier: false, stockkeeper: false });
  const db = testEnv.authenticatedContext("owner-1", {
    email: "owner-1@example.com",
    email_verified: true,
  }).firestore();

  await assertFails(updateDoc(doc(db, "users/owner-1"), {
    plan: "pro",
    currentPlan: "pro",
    subscriptionStatus: "active",
    billingCycle: "yearly",
    expiryDate: Timestamp.fromDate(new Date(Date.now() + 365 * 86400000)),
  }));
  await assertSucceeds(updateDoc(doc(db, "users/owner-1"), { name: "Owner Renamed" }));
});

test("owner cannot downgrade their role or change the profile email away from Firebase Auth", async () => {
  await seedShopMembers({ cashier: false, stockkeeper: false });
  const db = testEnv.authenticatedContext("owner-1", {
    email: "new-owner@example.com",
    email_verified: false,
  }).firestore();

  await assertFails(getDoc(doc(db, "shops/owner-1")));
  await assertSucceeds(getDoc(doc(db, "users/owner-1")));
  await assertFails(updateDoc(doc(db, "users/owner-1"), { role: "cashier" }));
  await assertFails(updateDoc(doc(db, "users/owner-1"), { email: "other@example.com" }));
  await assertFails(updateDoc(doc(db, "users/owner-1"), { name: "Changed while unverified" }));
  await assertSucceeds(updateDoc(doc(db, "users/owner-1"), {
    email: "new-owner@example.com",
    isVerified: false,
  }));
});

test("employee cannot change their profile email and break the synthetic login identity", async () => {
  await seedShopMembers({ stockkeeper: false });
  const db = testEnv.authenticatedContext("cashier-1", {
    email: "cashier@shop.sme",
    email_verified: false,
  }).firestore();

  await assertFails(updateDoc(doc(db, "users/cashier-1"), { email: "new-address@example.com" }));
});

test("verified first-time owner claims a trial atomically with profile creation", async () => {
  const email = "new-owner@example.com";
  const uid = "new-owner-1";
  const expiry = Timestamp.fromDate(new Date(Date.now() + 14 * 86400000));
  const db = testEnv.authenticatedContext(uid, { email, email_verified: true }).firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, `users/${uid}`), {
    uid,
    email,
    name: "New Owner",
    mobile: "",
    role: "owner",
    shopId: uid,
    isActive: true,
    isDeleted: false,
    isVerified: true,
    plan: "trial",
    currentPlan: "trial",
    subscriptionStatus: "active",
    billingCycle: "trial",
    expiryDate: expiry,
    permissions: {},
  });
  batch.set(doc(db, `trial_history/${email}`), {
    email,
    uid,
    hasUsedTrial: true,
    accountDeleted: false,
    trialGrantedAt: Timestamp.now(),
    trialExpiryDate: expiry,
  });

  await assertSucceeds(batch.commit());
});

test("verified account deletion can create permanent email history without granting a trial", async () => {
  const email = "deletion@example.com";
  const uid = "owner-to-delete";
  const db = testEnv.authenticatedContext(uid, { email, email_verified: true }).firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, `users/${uid}`), {
    uid,
    email,
    name: "Deleting Owner",
    mobile: "",
    role: "owner",
    shopId: uid,
    isActive: false,
    isDeleted: true,
    isVerified: true,
    plan: "free",
    subscriptionStatus: "inactive",
    permissions: {},
  });
  batch.set(doc(db, `trial_history/${email}`), {
    email,
    uid,
    hasUsedTrial: true,
    accountDeleted: true,
    deletedAt: Timestamp.now(),
  });

  await assertSucceeds(batch.commit());
});

test("an email with prior trial history cannot claim another active trial", async () => {
  const email = "reused@example.com";
  await seed(`trial_history/${email}`, {
    email,
    uid: "previous-owner",
    hasUsedTrial: true,
    accountDeleted: false,
    trialExpiryDate: Timestamp.fromDate(new Date(Date.now() - 86400000)),
  });
  const uid = "new-owner-2";
  const expiry = Timestamp.fromDate(new Date(Date.now() + 14 * 86400000));
  const db = testEnv.authenticatedContext(uid, { email, email_verified: true }).firestore();
  await assertFails(setDoc(doc(db, `users/${uid}`), {
    uid,
    email,
    name: "Returning Owner",
    mobile: "",
    role: "owner",
    shopId: uid,
    isActive: true,
    isVerified: true,
    plan: "trial",
    currentPlan: "trial",
    subscriptionStatus: "active",
    billingCycle: "trial",
    expiryDate: expiry,
    permissions: {},
  }));
});
