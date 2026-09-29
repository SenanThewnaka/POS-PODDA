const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Secret API key for Payments.lk (configured via Firebase Secret Manager or environment variable)
const PAYMENTS_LK_SECRET_KEY = process.env.PAYMENTS_LK_SECRET_KEY || "";

// Server-authoritative subscription catalog (prevents client-side price tampering)
const SUBSCRIPTION_CATALOG = {
  plus: {
    name: "POS Podda Plus (+)",
    options: {
      monthly: { months: 1, durationDays: 30, priceLkr: 1500, amountCents: 150000, label: "1 Month" },
      quarterly: { months: 3, durationDays: 90, priceLkr: 4200, amountCents: 420000, label: "3 Months" },
      semi_annual: { months: 6, durationDays: 180, priceLkr: 7900, amountCents: 790000, label: "6 Months" },
      yearly: { months: 12, durationDays: 365, priceLkr: 14900, amountCents: 1490000, label: "1 Year" },
    },
  },
  pro: {
    name: "POS Podda Pro",
    options: {
      monthly: { months: 1, durationDays: 30, priceLkr: 2900, amountCents: 290000, label: "1 Month" },
      quarterly: { months: 3, durationDays: 90, priceLkr: 7900, amountCents: 790000, label: "3 Months" },
      semi_annual: { months: 6, durationDays: 180, priceLkr: 14900, amountCents: 1490000, label: "6 Months" },
      yearly: { months: 12, durationDays: 365, priceLkr: 27900, amountCents: 2790000, label: "1 Year" },
    },
  },
};

/**
 * Callable Function: createCheckoutSession
 * Accessible from Web Browser, PWA, Android, and iOS.
 * Resolves CORS natively, keeps secret keys secure on the server.
 */
exports.createCheckoutSession = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be logged in to initiate a subscription payment."
    );
  }

  const { tier, cycleKey } = request.data || {};
  if (!tier || !cycleKey) {
    throw new HttpsError(
      "invalid-argument",
      "Missing required fields: 'tier' and 'cycleKey'."
    );
  }

  const tierCatalog = SUBSCRIPTION_CATALOG[tier.toLowerCase()];
  if (!tierCatalog) {
    throw new HttpsError("not-found", `Invalid tier selected: ${tier}`);
  }

  const planOption = tierCatalog.options[cycleKey.toLowerCase()];
  if (!planOption) {
    throw new HttpsError("not-found", `Invalid cycleKey selected: ${cycleKey}`);
  }

  const uid = request.auth.uid;
  const userDoc = await db.collection("users").doc(uid).get();
  const userData = userDoc.exists ? userDoc.data() : {};

  const customerName = userData.name || request.auth.token.name || "Valued Merchant";
  const customerEmail = userData.email || request.auth.token.email || "billing@pospodda.lk";
  const customerPhone = userData.mobile || "";

  const refId = `sub_${uid.substring(0, 8)}_${Date.now()}`;
  const description = `${tierCatalog.name} - ${planOption.label} Subscription`;

  const secretKey = PAYMENTS_LK_SECRET_KEY || process.env.PAYMENTS_LK_KEY;
  if (!secretKey) {
    console.error("PAYMENTS_LK_SECRET_KEY is not configured on the server.");
    throw new HttpsError(
      "failed-precondition",
      "Payment gateway key is not configured on the server. Please set PAYMENTS_LK_SECRET_KEY."
    );
  }

  // Call Payments.lk API server-to-server (No CORS restrictions!)
  const response = await fetch("https://api.payments.lk/v1/checkouts", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/json",
      "Idempotency-Key": `chk_${refId}_${Date.now()}`,
    },
    body: JSON.stringify({
      amountCents: planOption.amountCents,
      description: description,
      reference: refId,
      customer: {
        name: customerName,
        email: customerEmail,
        phone: customerPhone,
      },
      metadata: {
        userId: uid,
        tier: tier.toLowerCase(),
        cycleKey: cycleKey.toLowerCase(),
        durationDays: planOption.durationDays,
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error("Payments.lk create checkout failed:", response.status, errorText);
    throw new HttpsError(
      "internal",
      `Payment gateway error (${response.status}): ${errorText}`
    );
  }

  const checkoutData = await response.json();
  const checkoutId = checkoutData.id;
  const paymentId = checkoutData.payment?.id || null;
  const checkoutUrl = checkoutData.url;

  // Record pending checkout session in Firestore for auditing
  await db.collection("subscription_checkouts").doc(checkoutId).set({
    checkoutId,
    paymentId,
    userId: uid,
    tier: tier.toLowerCase(),
    cycleKey: cycleKey.toLowerCase(),
    durationDays: planOption.durationDays,
    amountCents: planOption.amountCents,
    status: checkoutData.status || "open",
    checkoutUrl,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    checkoutId,
    paymentId,
    checkoutUrl,
    status: checkoutData.status,
  };
});

/**
 * Callable Function: verifyPaymentSession
 * Verifies with Payments.lk whether payment succeeded and upgrades user account in Firestore.
 */
exports.verifyPaymentSession = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be logged in to verify subscription payment."
    );
  }

  const { paymentId, checkoutId } = request.data || {};
  if (!paymentId && !checkoutId) {
    throw new HttpsError(
      "invalid-argument",
      "Either 'paymentId' or 'checkoutId' must be provided."
    );
  }

  let effectivePaymentId = paymentId;

  // If checkoutId is given, resolve paymentId from checkout session record
  if (!effectivePaymentId && checkoutId) {
    const checkoutDoc = await db.collection("subscription_checkouts").doc(checkoutId).get();
    if (checkoutDoc.exists) {
      effectivePaymentId = checkoutDoc.data().paymentId;
    }
  }

  if (!effectivePaymentId) {
    throw new HttpsError("not-found", "Could not locate payment reference.");
  }

  const secretKey = PAYMENTS_LK_SECRET_KEY || process.env.PAYMENTS_LK_KEY;
  if (!secretKey) {
    throw new HttpsError(
      "failed-precondition",
      "Payment gateway key is not configured on the server."
    );
  }

  // Fetch status directly from Payments.lk
  const response = await fetch(`https://api.payments.lk/v1/payments/${effectivePaymentId}`, {
    headers: {
      Authorization: `Bearer ${secretKey}`,
    },
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error("Payments.lk fetch payment failed:", response.status, errorText);
    throw new HttpsError(
      "internal",
      `Payment gateway check failed (${response.status}): ${errorText}`
    );
  }

  const paymentData = await response.json();
  const paymentStatus = paymentData.status;

  if (paymentStatus === "succeeded") {
    const uid = request.auth.uid;
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.exists ? userDoc.data() : {};

    // Get metadata from payment or checkout
    let metaTier = paymentData.metadata?.tier;
    let metaCycle = paymentData.metadata?.cycleKey;
    let durationDays = paymentData.metadata?.durationDays ? parseInt(paymentData.metadata.durationDays) : null;

    if (!durationDays && checkoutId) {
      const checkoutDoc = await db.collection("subscription_checkouts").doc(checkoutId).get();
      if (checkoutDoc.exists) {
        const cData = checkoutDoc.data();
        metaTier = metaTier || cData.tier;
        metaCycle = metaCycle || cData.cycleKey;
        durationDays = durationDays || cData.durationDays;
      }
    }

    metaTier = metaTier || "pro";
    metaCycle = metaCycle || "monthly";
    durationDays = durationDays || 30;

    const now = new Date();
    const existingExpiry = userData.expiryDate ? userData.expiryDate.toDate() : null;
    const baseDate = existingExpiry && existingExpiry > now ? existingExpiry : now;
    const newExpiry = new Date(baseDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

    // Update user profile in Firestore
    await userRef.update({
      plan: metaTier,
      subscriptionStatus: "active",
      billingCycle: metaCycle,
      expiryDate: admin.firestore.Timestamp.fromDate(newExpiry),
    });

    // Update checkout audit record
    if (checkoutId) {
      await db.collection("subscription_checkouts").doc(checkoutId).update({
        status: "completed",
        paymentStatus: "succeeded",
        activatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      success: true,
      status: "succeeded",
      tier: metaTier,
      cycleKey: metaCycle,
      expiryDate: newExpiry.toISOString(),
    };
  }

  return {
    success: false,
    status: paymentStatus,
  };
});

/**
 * Webhook: paymentsWebhook
 * Asynchronous webhook called by Payments.lk when payment completes.
 */
exports.paymentsWebhook = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  try {
    const event = req.body;
    console.log("Received Payments.lk webhook event:", event?.type || event?.object);

    if (event?.type === "payment.succeeded" || (event?.object === "payment" && event?.status === "succeeded")) {
      const payment = event.data?.object || event;
      const uid = payment.metadata?.userId;
      const durationDays = payment.metadata?.durationDays ? parseInt(payment.metadata.durationDays) : 30;
      const tier = payment.metadata?.tier || "pro";
      const cycleKey = payment.metadata?.cycleKey || "monthly";

      if (uid) {
        const userRef = db.collection("users").doc(uid);
        const userDoc = await userRef.get();
        const userData = userDoc.exists ? userDoc.data() : {};

        const now = new Date();
        const existingExpiry = userData.expiryDate ? userData.expiryDate.toDate() : null;
        const baseDate = existingExpiry && existingExpiry > now ? existingExpiry : now;
        const newExpiry = new Date(baseDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

        await userRef.update({
          plan: tier,
          subscriptionStatus: "active",
          billingCycle: cycleKey,
          expiryDate: admin.firestore.Timestamp.fromDate(newExpiry),
        });

        console.log(`Successfully upgraded user ${uid} to ${tier} via webhook.`);
      }
    }

    res.status(200).json({ received: true });
  } catch (error) {
    console.error("Webhook processing error:", error);
    res.status(500).json({ error: error.message });
  }
});
