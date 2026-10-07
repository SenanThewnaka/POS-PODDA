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
  let checkoutData = null;

  let checkoutDoc;
  if (checkoutId) {
    checkoutDoc = await db.collection("subscription_checkouts").doc(checkoutId).get();
  }

  // If checkoutId is given, resolve paymentId from checkout session record or fetch directly from gateway
  if (!effectivePaymentId && checkoutDoc && checkoutDoc.exists) {
    effectivePaymentId = checkoutDoc.data().paymentId;
  }

  const secretKey = PAYMENTS_LK_SECRET_KEY || process.env.PAYMENTS_LK_KEY;
  if (!secretKey) {
    throw new HttpsError(
      "failed-precondition",
      "Payment gateway key is not configured on the server."
    );
  }

  // If effectivePaymentId is still missing, query Payments.lk checkout directly
  if (!effectivePaymentId && checkoutId) {
    try {
      const chkRes = await fetch(`https://api.payments.lk/v1/checkouts/${checkoutId}`, {
        headers: { Authorization: `Bearer ${secretKey}` },
      });
      if (chkRes.ok) {
        checkoutData = await chkRes.json();
        effectivePaymentId = checkoutData.payment?.id || checkoutData.paymentId || null;
        if (effectivePaymentId && checkoutDoc && checkoutDoc.exists) {
          await checkoutDoc.ref.update({ paymentId: effectivePaymentId });
        }
      }
    } catch (chkErr) {
      console.warn("Direct checkout check error:", chkErr.message);
    }
  }

  if (!effectivePaymentId && (!checkoutData || checkoutData.status !== "completed")) {
    throw new HttpsError("not-found", "Could not locate payment reference.");
  }

  let paymentStatus = "unknown";

  if (effectivePaymentId) {
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
    paymentStatus = paymentData.status;
  } else if (checkoutData && checkoutData.status === "completed") {
    paymentStatus = "succeeded";
  }

  if (paymentStatus === "succeeded") {
    const uid = request.auth.uid;
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.exists ? userDoc.data() : {};

    // Get subscription tier and duration from Firestore checkout session
    let metaTier;
    let metaCycle;
    let durationDays;

    if (!checkoutDoc && effectivePaymentId) {
      const snap = await db.collection("subscription_checkouts").where("paymentId", "==", effectivePaymentId).limit(1).get();
      if (!snap.empty) checkoutDoc = snap.docs[0];
    }

    if (checkoutDoc && checkoutDoc.exists) {
      const cData = checkoutDoc.data();
      if (cData.userId && cData.userId !== request.auth.uid) {
        throw new HttpsError("permission-denied", "Unauthorized: checkout session does not belong to the authenticated user.");
      }
      // IDEMPOTENCY GUARD: Do not allow re-activating an already completed checkout
      if (cData.status === "completed" || cData.activatedAt) {
        return {
          success: true,
          status: "succeeded",
          tier: cData.tier,
          cycleKey: cData.cycleKey,
          alreadyActivated: true,
          expiryDate: userData.expiryDate ? userData.expiryDate.toDate().toISOString() : null,
        };
      }
      metaTier = cData.tier;
      metaCycle = cData.cycleKey;
      durationDays = cData.durationDays;
    }

    metaTier = (metaTier || "plus").toLowerCase();
    metaCycle = (metaCycle || "monthly").toLowerCase();
    durationDays = durationDays || 30;

    const now = new Date();
    const existingExpiry = userData.expiryDate ? userData.expiryDate.toDate() : null;
    const baseDate = existingExpiry && existingExpiry > now ? existingExpiry : now;
    const newExpiry = new Date(baseDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

    // Atomically activate subscription and mark checkout completed
    await db.runTransaction(async (transaction) => {
      if (checkoutDoc && checkoutDoc.exists) {
        const freshCheckout = await transaction.get(checkoutDoc.ref);
        if (freshCheckout.exists && (freshCheckout.data().status === "completed" || freshCheckout.data().activatedAt)) {
          return; // Race guard: already processed by a concurrent call
        }
        transaction.update(checkoutDoc.ref, {
          status: "completed",
          paymentStatus: "succeeded",
          activatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      transaction.update(userRef, {
        plan: metaTier,
        currentPlan: metaTier,
        subscriptionStatus: "active",
        billingCycle: metaCycle,
        expiryDate: admin.firestore.Timestamp.fromDate(newExpiry),
      });
    });

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
    // 1. Webhook Signature / Secret Verification
    const secretKey = PAYMENTS_LK_SECRET_KEY || process.env.PAYMENTS_LK_KEY;
    const webhookSecret = process.env.PAYMENTS_LK_WEBHOOK_SECRET || secretKey;

    if (!webhookSecret) {
      console.error("Payments.lk webhook secret is not configured on the server.");
      res.status(500).json({ error: "Server configuration error" });
      return;
    }

    const authHeader = req.headers["authorization"] || req.headers["x-api-key"];
    const signature = req.headers["x-payments-signature"] || req.headers["x-signature"];

    if (!signature && !authHeader) {
      console.error("Unauthorized webhook: Missing authentication signature or authorization header");
      res.status(401).json({ error: "Authentication required" });
      return;
    }

    const crypto = require("crypto");
    if (signature) {
      const rawBody = typeof req.rawBody !== "undefined" ? req.rawBody : (typeof req.body === "string" ? req.body : JSON.stringify(req.body));
      const expectedSig = crypto.createHmac("sha256", webhookSecret).update(rawBody).digest("hex");
      const sigBuf = Buffer.from(signature, "utf8");
      const expBuf = Buffer.from(expectedSig, "utf8");
      if (sigBuf.length !== expBuf.length || !crypto.timingSafeEqual(sigBuf, expBuf)) {
        console.error("Unauthorized webhook: Signature mismatch");
        res.status(401).json({ error: "Invalid signature" });
        return;
      }
    } else if (authHeader) {
      const token = authHeader.replace(/^Bearer\s+/i, "").trim();
      const tokenBuf = Buffer.from(token, "utf8");
      const secBuf = Buffer.from(webhookSecret, "utf8");
      const keyBuf = Buffer.from(secretKey || "", "utf8");
      const matchSecret = tokenBuf.length === secBuf.length && crypto.timingSafeEqual(tokenBuf, secBuf);
      const matchKey = keyBuf.length > 0 && tokenBuf.length === keyBuf.length && crypto.timingSafeEqual(tokenBuf, keyBuf);
      if (!matchSecret && !matchKey) {
        console.error("Unauthorized webhook: Invalid authorization token");
        res.status(401).json({ error: "Unauthorized" });
        return;
      }
    }

    const event = req.body;
    console.log("Received Payments.lk webhook event:", event?.type || event?.object);

    if (event?.type === "payment.succeeded" || (event?.object === "payment" && event?.status === "succeeded")) {
      const payment = event.data?.object || event;
      const checkoutId = payment.checkoutId;
      const paymentId = payment.id;
      let uid = null;
      let durationDays = 30;
      let tier = "pro";
      let cycleKey = "monthly";

      let checkoutDoc;
      if (checkoutId) {
        checkoutDoc = await db.collection("subscription_checkouts").doc(checkoutId).get();
      } else if (paymentId) {
        const snap = await db.collection("subscription_checkouts").where("paymentId", "==", paymentId).limit(1).get();
        if (!snap.empty) checkoutDoc = snap.docs[0];
      }

      if (checkoutDoc && checkoutDoc.exists) {
        const cData = checkoutDoc.data();
        // IDEMPOTENCY GUARD: Do not re-process already activated checkouts
        if (cData.status === "completed" || cData.activatedAt) {
          console.log(`Checkout ${checkoutDoc.id} already completed. Skipping.`);
          res.status(200).json({ received: true, alreadyActivated: true });
          return;
        }
        uid = cData.userId;
        tier = cData.tier || "pro";
        cycleKey = cData.cycleKey || "monthly";
        durationDays = cData.durationDays || 30;
      }

      if (uid) {
        const userRef = db.collection("users").doc(uid);
        const userDoc = await userRef.get();
        const userData = userDoc.exists ? userDoc.data() : {};

        const now = new Date();
        const existingExpiry = userData.expiryDate ? userData.expiryDate.toDate() : null;
        const baseDate = existingExpiry && existingExpiry > now ? existingExpiry : now;
        const newExpiry = new Date(baseDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

        await db.runTransaction(async (transaction) => {
          if (checkoutDoc && checkoutDoc.exists) {
            transaction.update(checkoutDoc.ref, {
              status: "completed",
              paymentStatus: "succeeded",
              activatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          transaction.update(userRef, {
            plan: tier,
            currentPlan: tier,
            subscriptionStatus: "active",
            billingCycle: cycleKey,
            expiryDate: admin.firestore.Timestamp.fromDate(newExpiry),
          });
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
