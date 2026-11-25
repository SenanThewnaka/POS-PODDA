const crypto = require("crypto");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const {
  SUBSCRIPTION_CATALOG,
  getCheckoutTerms,
  assertPaymentMatchesCheckout,
} = require("./payment_validation");
const { verifyPaymentsSignature, parsePaymentsLkEvent } = require("./webhook_validation");

const paymentsApiSecret = defineSecret("PAYMENTS_LK_SECRET_KEY");
const paymentsWebhookSecret = defineSecret("PAYMENTS_LK_WEBHOOK_SECRET");

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const PAYMENTS_API_BASE = "https://api.payments.lk/v1";

function paymentApiKey() {
  return paymentsApiSecret.value() || process.env.PAYMENTS_LK_SECRET_KEY || process.env.PAYMENTS_LK_KEY || "";
}

async function requireActiveOwner(uid) {
  const snapshot = await db.collection("users").doc(uid).get();
  if (!snapshot.exists) throw new HttpsError("permission-denied", "An active shop owner profile is required.");
  const user = snapshot.data();
  if (user.role !== "owner" || user.shopId !== uid || user.isActive === false || user.isDeleted === true) {
    throw new HttpsError("permission-denied", "Only the active shop owner may manage this subscription.");
  }
  return { ref: snapshot.ref, data: user };
}

async function fetchGatewayPayment(paymentId, secretKey) {
  const response = await fetch(`${PAYMENTS_API_BASE}/payments/${encodeURIComponent(paymentId)}`, {
    headers: { Authorization: `Bearer ${secretKey}` },
  });
  if (!response.ok) {
    console.error("Payments.lk payment lookup failed with status", response.status);
    throw new HttpsError("failed-precondition", "The payment could not be verified with the payment provider.");
  }
  return response.json();
}

async function resolvePaymentId(checkoutId, checkoutData, requestedPaymentId, secretKey) {
  const storedPaymentId = typeof checkoutData.paymentId === "string" && checkoutData.paymentId.length
    ? checkoutData.paymentId
    : null;

  if (storedPaymentId && requestedPaymentId && storedPaymentId !== requestedPaymentId) {
    throw new HttpsError("permission-denied", "The payment ID does not match this checkout.");
  }
  if (storedPaymentId) return storedPaymentId;

  // A client-supplied payment ID is not trusted unless the provider links it to this checkout.
  const response = await fetch(`${PAYMENTS_API_BASE}/checkouts/${encodeURIComponent(checkoutId)}`, {
    headers: { Authorization: `Bearer ${secretKey}` },
  });
  if (!response.ok) {
    console.error("Payments.lk checkout lookup failed with status", response.status);
    throw new HttpsError("failed-precondition", "The checkout could not be verified with the payment provider.");
  }
  const gatewayCheckout = await response.json();
  if (gatewayCheckout.id !== checkoutId) {
    throw new HttpsError("permission-denied", "The provider checkout ID does not match the recorded checkout.");
  }
  const gatewayPaymentId = gatewayCheckout.payment?.id || gatewayCheckout.paymentId || null;
  if (!gatewayPaymentId) return null;
  if (requestedPaymentId && requestedPaymentId !== gatewayPaymentId) {
    throw new HttpsError("permission-denied", "The payment ID does not match this checkout.");
  }
  return gatewayPaymentId;
}

function validatePayment(paymentData, checkoutData, paymentId) {
  try {
    getCheckoutTerms(checkoutData);
    return assertPaymentMatchesCheckout(paymentData, checkoutData, paymentId);
  } catch (error) {
    console.error("Payment validation rejected a checkout:", error.message);
    throw new HttpsError("failed-precondition", "The payment does not match the recorded subscription checkout.");
  }
}

function expiryFromUserData(userData, durationDays) {
  const now = new Date();
  const existingExpiry = userData.expiryDate && typeof userData.expiryDate.toDate === "function"
    ? userData.expiryDate.toDate()
    : null;
  const baseDate = existingExpiry && existingExpiry > now ? existingExpiry : now;
  return new Date(baseDate.getTime() + durationDays * 24 * 60 * 60 * 1000);
}

exports.createCheckoutSession = onCall({ cors: true, secrets: [paymentsApiSecret] }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "You must be logged in to start a subscription payment.");
  if (request.auth.token.email_verified !== true) {
    throw new HttpsError("permission-denied", "Verify the shop owner email before starting a subscription payment.");
  }

  const { tier, cycleKey } = request.data || {};
  if (typeof tier !== "string" || typeof cycleKey !== "string") {
    throw new HttpsError("invalid-argument", "A valid tier and billing cycle are required.");
  }
  const normalizedTier = tier.toLowerCase();
  const normalizedCycle = cycleKey.toLowerCase();
  const planOption = SUBSCRIPTION_CATALOG[normalizedTier]?.options[normalizedCycle];
  if (!planOption) throw new HttpsError("invalid-argument", "The selected subscription option is invalid.");

  const uid = request.auth.uid;
  const { data: userData } = await requireActiveOwner(uid);
  const customerName = userData.name || request.auth.token.name || "Valued Merchant";
  const customerEmail = userData.email || request.auth.token.email;
  const customerPhone = userData.mobile || "";
  const secretKey = paymentApiKey();
  if (!secretKey) throw new HttpsError("failed-precondition", "The payment provider is not configured on the server.");

  const reference = `sub_${uid.substring(0, 8)}_${Date.now()}_${crypto.randomBytes(6).toString("hex")}`;
  const planName = normalizedTier === "plus" ? "POS Podda Plus (+)" : "POS Podda Pro";
  const label = {
    monthly: "1 Month",
    quarterly: "3 Months",
    semi_annual: "6 Months",
    yearly: "1 Year",
  }[normalizedCycle];
  const response = await fetch(`${PAYMENTS_API_BASE}/checkouts`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/json",
      "Idempotency-Key": `chk_${crypto.randomUUID()}`,
    },
    body: JSON.stringify({
      amountCents: planOption.amountCents,
      description: `${planName} - ${label} Subscription`,
      reference,
      customer: { name: customerName, email: customerEmail, phone: customerPhone },
    }),
  });

  if (!response.ok) {
    console.error("Payments.lk checkout creation failed with status", response.status);
    throw new HttpsError("failed-precondition", "The payment provider could not create a checkout.");
  }
  const checkout = await response.json();
  if (typeof checkout.id !== "string" || !checkout.id || typeof checkout.url !== "string" || !checkout.url) {
    console.error("Payments.lk returned an incomplete checkout response.");
    throw new HttpsError("internal", "The payment provider returned an invalid checkout response.");
  }

  await db.collection("subscription_checkouts").doc(checkout.id).create({
    checkoutId: checkout.id,
    paymentId: checkout.payment?.id || null,
    userId: uid,
    tier: normalizedTier,
    cycleKey: normalizedCycle,
    durationDays: planOption.durationDays,
    amountCents: planOption.amountCents,
    currency: "LKR",
    reference,
    status: checkout.status || "open",
    checkoutUrl: checkout.url,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    checkoutId: checkout.id,
    paymentId: checkout.payment?.id || null,
    checkoutUrl: checkout.url,
    status: checkout.status || "open",
    amountCents: planOption.amountCents,
  };
});

exports.verifyPaymentSession = onCall({ cors: true, secrets: [paymentsApiSecret] }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "You must be logged in to verify a subscription payment.");
  const { checkoutId, paymentId: requestedPaymentId } = request.data || {};
  if (typeof checkoutId !== "string" || !checkoutId) {
    throw new HttpsError("invalid-argument", "A checkout ID created by this app is required.");
  }
  if (requestedPaymentId !== undefined && (typeof requestedPaymentId !== "string" || !requestedPaymentId)) {
    throw new HttpsError("invalid-argument", "The payment ID is invalid.");
  }

  const uid = request.auth.uid;
  if (request.auth.token.email_verified !== true) {
    throw new HttpsError("permission-denied", "Verify your account email before activating a subscription.");
  }
  await requireActiveOwner(uid);
  const checkoutRef = db.collection("subscription_checkouts").doc(checkoutId);
  const checkoutSnapshot = await checkoutRef.get();
  if (!checkoutSnapshot.exists) throw new HttpsError("not-found", "No recorded checkout was found.");
  const checkoutData = checkoutSnapshot.data();
  if (checkoutData.userId !== uid || checkoutData.checkoutId !== checkoutId) {
    throw new HttpsError("permission-denied", "This checkout does not belong to the authenticated shop owner.");
  }

  if (checkoutData.status === "completed" || checkoutData.activatedAt) {
    const ownerSnapshot = await db.collection("users").doc(uid).get();
    const expiry = ownerSnapshot.data()?.expiryDate;
    return {
      success: true,
      status: "succeeded",
      tier: checkoutData.tier,
      cycleKey: checkoutData.cycleKey,
      alreadyActivated: true,
      expiryDate: expiry && typeof expiry.toDate === "function" ? expiry.toDate().toISOString() : null,
    };
  }

  let terms;
  try {
    terms = getCheckoutTerms(checkoutData);
  } catch (error) {
    console.error("Recorded checkout failed validation:", error.message);
    throw new HttpsError("failed-precondition", "The recorded subscription checkout is invalid.");
  }

  const secretKey = paymentApiKey();
  if (!secretKey) throw new HttpsError("failed-precondition", "The payment provider is not configured on the server.");
  const effectivePaymentId = await resolvePaymentId(checkoutId, checkoutData, requestedPaymentId, secretKey);
  if (!effectivePaymentId) return { success: false, status: checkoutData.status || "pending" };

  const paymentData = await fetchGatewayPayment(effectivePaymentId, secretKey);
  if (!validatePayment(paymentData, checkoutData, effectivePaymentId)) {
    return { success: false, status: paymentData.status || "pending" };
  }

  const ownerRef = db.collection("users").doc(uid);
  const activation = await db.runTransaction(async (transaction) => {
    const freshCheckoutSnapshot = await transaction.get(checkoutRef);
    const ownerSnapshot = await transaction.get(ownerRef);
    if (!freshCheckoutSnapshot.exists || !ownerSnapshot.exists) {
      throw new HttpsError("failed-precondition", "The shop owner or recorded checkout is missing.");
    }
    const freshCheckout = freshCheckoutSnapshot.data();
    const owner = ownerSnapshot.data();
    if (freshCheckout.userId !== uid || freshCheckout.checkoutId !== checkoutId) {
      throw new HttpsError("permission-denied", "This checkout does not belong to the authenticated shop owner.");
    }
    if (freshCheckout.status === "completed" || freshCheckout.activatedAt) {
      return { alreadyActivated: true, expiryDate: owner.expiryDate || null };
    }
    if (owner.role !== "owner" || owner.shopId !== uid || owner.isActive === false || owner.isDeleted === true) {
      throw new HttpsError("permission-denied", "Only the active shop owner may receive this subscription.");
    }
    if (freshCheckout.paymentId && freshCheckout.paymentId !== effectivePaymentId) {
      throw new HttpsError("permission-denied", "The provider payment ID no longer matches this checkout.");
    }
    validatePayment(paymentData, freshCheckout, effectivePaymentId);
    const freshTerms = getCheckoutTerms(freshCheckout);
    const newExpiry = expiryFromUserData(owner, freshTerms.durationDays);

    transaction.update(checkoutRef, {
      paymentId: effectivePaymentId,
      status: "completed",
      paymentStatus: "succeeded",
      verifiedAmountCents: paymentData.amountCents,
      activatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    transaction.update(ownerRef, {
      plan: freshTerms.tier,
      currentPlan: freshTerms.tier,
      subscriptionStatus: "active",
      billingCycle: freshTerms.cycleKey,
      expiryDate: admin.firestore.Timestamp.fromDate(newExpiry),
    });
    return { alreadyActivated: false, expiryDate: newExpiry };
  });

  const expiryDate = activation.expiryDate && typeof activation.expiryDate.toDate === "function"
    ? activation.expiryDate.toDate().toISOString()
    : activation.expiryDate?.toISOString?.() || null;
  return {
    success: true,
    status: "succeeded",
    tier: terms.tier,
    cycleKey: terms.cycleKey,
    alreadyActivated: activation.alreadyActivated,
    expiryDate,
  };
});

exports.setEmployeePassword = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "You must be logged in to reset an employee password.");
  if (request.auth.token.email_verified !== true) throw new HttpsError("permission-denied", "Verify your account email first.");
  const { employeeUid, newPassword } = request.data || {};
  if (typeof employeeUid !== "string" || !employeeUid || typeof newPassword !== "string" || newPassword.length < 6 || newPassword.length > 1024) {
    throw new HttpsError("invalid-argument", "A valid employee ID and password of at least 6 characters are required.");
  }

  const ownerUid = request.auth.uid;
  const { data: owner } = await requireActiveOwner(ownerUid);
  if (owner.shopId !== ownerUid) throw new HttpsError("permission-denied", "Only the shop owner may reset employee passwords.");

  const employeeSnapshot = await db.collection("users").doc(employeeUid).get();
  if (!employeeSnapshot.exists) throw new HttpsError("not-found", "Employee profile was not found.");
  const employee = employeeSnapshot.data();
  if (employee.shopId !== ownerUid || employee.role === "owner" || employee.isActive === false || employee.isDeleted === true) {
    throw new HttpsError("permission-denied", "The selected account is not an active employee of this shop.");
  }

  await admin.auth().updateUser(employeeUid, { password: newPassword });
  return { success: true };
});

exports.cleanupLegacyEmployeePasswords = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "You must be logged in to clean up employee credentials.");
  if (request.auth.token.email_verified !== true) throw new HttpsError("permission-denied", "Verify your account email first.");

  const ownerUid = request.auth.uid;
  await requireActiveOwner(ownerUid);
  const employees = await db.collection("users").where("shopId", "==", ownerUid).get();
  let batch = db.batch();
  let pendingWrites = 0;
  let removedCount = 0;

  for (const employeeDoc of employees.docs) {
    if (!Object.prototype.hasOwnProperty.call(employeeDoc.data(), "storedPassword")) continue;
    batch.update(employeeDoc.ref, { storedPassword: admin.firestore.FieldValue.delete() });
    pendingWrites += 1;
    removedCount += 1;
    if (pendingWrites === 450) {
      await batch.commit();
      batch = db.batch();
      pendingWrites = 0;
    }
  }
  if (pendingWrites > 0) await batch.commit();
  return { removedCount };
});

exports.paymentsWebhook = onRequest({ secrets: [paymentsApiSecret, paymentsWebhookSecret] }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

  // Require a dedicated webhook secret; never reuse the Payments.lk API credential.
  const webhookSecret = paymentsWebhookSecret.value() || process.env.PAYMENTS_LK_WEBHOOK_SECRET || "";
  if (!webhookSecret) {
    console.error("Payments.lk webhook secret is not configured.");
    return res.status(500).json({ error: "Webhook configuration error" });
  }
  const signatureHeader = req.headers["payments-signature"];
  if (!verifyPaymentsSignature(webhookSecret, signatureHeader, req.rawBody)) {
    return res.status(401).json({ error: "Authentication required" });
  }

  let payment;
  try {
    payment = parsePaymentsLkEvent(req.body);
  } catch (error) {
    console.error("Payments.lk webhook payload is invalid:", error.message);
    return res.status(400).json({ error: "Invalid payment event" });
  }
  if (!payment) return res.status(200).json({ received: true });

  try {
    const checkoutId = payment.checkoutId;
    const paymentId = payment.id;
    const reference = payment.reference;
    if (!paymentId) return res.status(400).json({ error: "Payment ID is required" });

    let checkoutSnapshot = null;
    if (checkoutId) {
      checkoutSnapshot = await db.collection("subscription_checkouts").doc(checkoutId).get();
    }
    if (!checkoutSnapshot || !checkoutSnapshot.exists) {
      if (paymentId) {
        const matches = await db.collection("subscription_checkouts").where("paymentId", "==", paymentId).limit(2).get();
        if (matches.size === 1) checkoutSnapshot = matches.docs[0];
        if (matches.size > 1) return res.status(500).json({ error: "Ambiguous checkout mapping" });
      }
      if ((!checkoutSnapshot || !checkoutSnapshot.exists) && reference) {
        const matches = await db.collection("subscription_checkouts").where("reference", "==", reference).limit(2).get();
        if (matches.size === 1) checkoutSnapshot = matches.docs[0];
        if (matches.size > 1) return res.status(500).json({ error: "Ambiguous checkout mapping" });
      }
    }
    if (!checkoutSnapshot || !checkoutSnapshot.exists) {
      if (reference.startsWith("sub_")) {
        console.error("No recorded checkout maps to a POS Podda subscription payment.");
        return res.status(500).json({ error: "Subscription checkout mapping is unavailable" });
      }
      console.warn("Ignoring authenticated payment event without a recorded checkout.");
      return res.status(200).json({ received: true, ignored: true });
    }

    const checkoutData = checkoutSnapshot.data();
    if (checkoutData.checkoutId !== checkoutSnapshot.id || (checkoutId && checkoutId !== checkoutSnapshot.id)) {
      return res.status(500).json({ error: "Checkout mapping mismatch" });
    }
    if (checkoutData.paymentId && checkoutData.paymentId !== paymentId) {
      return res.status(500).json({ error: "Payment ID does not match checkout" });
    }
    if (reference && reference !== checkoutData.reference) {
      return res.status(500).json({ error: "Payment reference does not match checkout" });
    }
    if (payment.checkoutId && payment.checkoutId !== checkoutSnapshot.id) {
      return res.status(500).json({ error: "Provider checkout ID does not match" });
    }
    if (checkoutData.status === "completed" || checkoutData.activatedAt) {
      return res.status(200).json({ received: true, alreadyActivated: true });
    }

    getCheckoutTerms(checkoutData);
    const secretKey = paymentApiKey();
    if (!secretKey) {
      console.error("Payments.lk API credential is not configured.");
      return res.status(500).json({ error: "Payment verification configuration error" });
    }
    const paymentData = await fetchGatewayPayment(paymentId, secretKey);
    const isVerified = assertPaymentMatchesCheckout(paymentData, checkoutData, paymentId);
    if (!isVerified) return res.status(503).json({ error: "Payment verification is not yet consistent" });

    const uid = checkoutData.userId;
    const ownerRef = db.collection("users").doc(uid);
    const checkoutRef = checkoutSnapshot.ref;
    const result = await db.runTransaction(async (transaction) => {
      const freshCheckoutSnapshot = await transaction.get(checkoutRef);
      const ownerSnapshot = await transaction.get(ownerRef);
      if (!freshCheckoutSnapshot.exists || !ownerSnapshot.exists) return { ignored: true };
      const freshCheckout = freshCheckoutSnapshot.data();
      const owner = ownerSnapshot.data();
      if (freshCheckout.checkoutId !== checkoutSnapshot.id || freshCheckout.userId !== uid) return { ignored: true };
      if (freshCheckout.status === "completed" || freshCheckout.activatedAt) return { alreadyActivated: true };
      if (freshCheckout.paymentId && freshCheckout.paymentId !== paymentId) return { ignored: true };
      if (owner.role !== "owner" || owner.shopId !== uid || owner.isActive === false || owner.isDeleted === true) return { ignored: true };

      const terms = getCheckoutTerms(freshCheckout);
      if (!assertPaymentMatchesCheckout(paymentData, freshCheckout, paymentId)) return { pending: true };
      const newExpiry = expiryFromUserData(owner, terms.durationDays);
      transaction.update(checkoutRef, {
        paymentId,
        status: "completed",
        paymentStatus: "succeeded",
        verifiedAmountCents: paymentData.amountCents,
        activatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.update(ownerRef, {
        plan: terms.tier,
        currentPlan: terms.tier,
        subscriptionStatus: "active",
        billingCycle: terms.cycleKey,
        expiryDate: admin.firestore.Timestamp.fromDate(newExpiry),
      });
      return { activated: true };
    });

    if (result.ignored) {
      console.warn("Ignoring a paid checkout for a missing, inactive, or mismatched owner.");
      return res.status(200).json({ received: true, ignored: true });
    }
    return res.status(200).json({ received: true, alreadyActivated: result.alreadyActivated === true, pending: result.pending === true });
  } catch (error) {
    console.error("Payments webhook processing failed; allowing provider retry:", error.message);
    return res.status(500).json({ error: "Payment event processing failed" });
  }
});
