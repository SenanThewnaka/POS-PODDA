const SUBSCRIPTION_CATALOG = Object.freeze({
  plus: Object.freeze({
    options: Object.freeze({
      monthly: Object.freeze({ durationDays: 30, amountCents: 150000 }),
      quarterly: Object.freeze({ durationDays: 90, amountCents: 420000 }),
      semi_annual: Object.freeze({ durationDays: 180, amountCents: 790000 }),
      yearly: Object.freeze({ durationDays: 365, amountCents: 1490000 }),
    }),
  }),
  pro: Object.freeze({
    options: Object.freeze({
      monthly: Object.freeze({ durationDays: 30, amountCents: 290000 }),
      quarterly: Object.freeze({ durationDays: 90, amountCents: 790000 }),
      semi_annual: Object.freeze({ durationDays: 180, amountCents: 1490000 }),
      yearly: Object.freeze({ durationDays: 365, amountCents: 2790000 }),
    }),
  }),
});

function getCheckoutTerms(checkout) {
  if (!checkout || typeof checkout !== "object") {
    throw new Error("A recorded checkout is required.");
  }

  const tier = typeof checkout.tier === "string" ? checkout.tier.toLowerCase() : "";
  const cycleKey = typeof checkout.cycleKey === "string" ? checkout.cycleKey.toLowerCase() : "";
  const option = SUBSCRIPTION_CATALOG[tier]?.options[cycleKey];
  if (!option) throw new Error("Checkout tier or billing cycle is invalid.");
  if (!Number.isSafeInteger(checkout.amountCents) || checkout.amountCents !== option.amountCents) {
    throw new Error("Checkout amount does not match the server catalog.");
  }
  if (!Number.isSafeInteger(checkout.durationDays) || checkout.durationDays !== option.durationDays) {
    throw new Error("Checkout duration does not match the server catalog.");
  }
  if (typeof checkout.userId !== "string" || checkout.userId.length === 0) {
    throw new Error("Checkout owner is missing.");
  }
  if (typeof checkout.checkoutId !== "string" || checkout.checkoutId.length === 0) {
    throw new Error("Checkout identifier is missing.");
  }
  if (typeof checkout.reference !== "string" || checkout.reference.length === 0) {
    throw new Error("Checkout reference is missing.");
  }
  if (checkout.currency !== "LKR") throw new Error("Checkout currency is invalid.");

  return { tier, cycleKey, ...option };
}

function assertPaymentMatchesCheckout(payment, checkout, expectedPaymentId) {
  if (!payment || typeof payment !== "object") throw new Error("Gateway payment response is missing.");
  if (payment.object !== "payment") throw new Error("Gateway response is not a payment object.");
  if (typeof expectedPaymentId !== "string" || expectedPaymentId.length === 0) {
    throw new Error("A payment ID linked to the checkout is required.");
  }
  if (payment.id !== expectedPaymentId) throw new Error("Gateway payment ID does not match the checkout.");
  if (payment.checkoutId !== checkout.checkoutId) throw new Error("Gateway checkout ID does not match the recorded checkout.");
  if (payment.status !== "succeeded") return false;
  if (!Number.isSafeInteger(payment.amountCents) || payment.amountCents !== checkout.amountCents) {
    throw new Error("Gateway payment amount does not match the checkout.");
  }
  if (payment.reference !== checkout.reference) {
    throw new Error("Gateway payment reference does not match the checkout.");
  }
  if (payment.currency !== checkout.currency) {
    throw new Error("Gateway payment currency does not match the checkout.");
  }

  return true;
}

module.exports = { SUBSCRIPTION_CATALOG, getCheckoutTerms, assertPaymentMatchesCheckout };
