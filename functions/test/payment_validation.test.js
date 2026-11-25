const test = require("node:test");
const assert = require("node:assert/strict");
const { getCheckoutTerms, assertPaymentMatchesCheckout } = require("../payment_validation");

function checkout(overrides = {}) {
  return {
    checkoutId: "checkout-123",
    paymentId: "payment-456",
    userId: "owner-789",
    tier: "pro",
    cycleKey: "quarterly",
    durationDays: 90,
    amountCents: 790000,
    currency: "LKR",
    reference: "sub_owner_123",
    ...overrides,
  };
}

function payment(overrides = {}) {
  return {
    object: "payment",
    id: "payment-456",
    status: "succeeded",
    amountCents: 790000,
    currency: "LKR",
    reference: "sub_owner_123",
    checkoutId: "checkout-123",
    ...overrides,
  };
}

test("resolves the exact server catalog terms for a recorded checkout", () => {
  assert.deepEqual(getCheckoutTerms(checkout()), {
    tier: "pro",
    cycleKey: "quarterly",
    durationDays: 90,
    amountCents: 790000,
  });
});

test("rejects missing checkout metadata and unknown plan options", () => {
  assert.throws(() => getCheckoutTerms(null), /recorded checkout/);
  assert.throws(() => getCheckoutTerms(checkout({ tier: "enterprise" })), /tier or billing cycle/);
  assert.throws(() => getCheckoutTerms(checkout({ cycleKey: "lifetime" })), /tier or billing cycle/);
});

test("rejects checkout amounts or durations that diverge from the server catalog", () => {
  assert.throws(() => getCheckoutTerms(checkout({ amountCents: 1 })), /amount/);
  assert.throws(() => getCheckoutTerms(checkout({ durationDays: 365 })), /duration/);
  assert.throws(() => getCheckoutTerms(checkout({ reference: null })), /reference/);
});

test("accepts only a succeeded payment matching the checkout ID, amount, reference, and currency", () => {
  assert.equal(assertPaymentMatchesCheckout(payment(), checkout(), "payment-456"), true);
  assert.equal(assertPaymentMatchesCheckout(payment({ status: "pending" }), checkout(), "payment-456"), false);
  assert.throws(() => assertPaymentMatchesCheckout(payment(), checkout(), "other-payment"), /ID/);
  assert.throws(() => assertPaymentMatchesCheckout(payment({ amountCents: 1 }), checkout(), "payment-456"), /amount/);
  assert.throws(() => assertPaymentMatchesCheckout(payment({ reference: "another-order" }), checkout(), "payment-456"), /reference/);
  assert.throws(() => assertPaymentMatchesCheckout(payment({ currency: "USD" }), checkout(), "payment-456"), /currency/);
  assert.throws(() => assertPaymentMatchesCheckout(payment({ reference: undefined }), checkout(), "payment-456"), /reference/);
  assert.throws(() => assertPaymentMatchesCheckout(payment({ checkoutId: "other-checkout" }), checkout(), "payment-456"), /checkout ID/);
  assert.throws(() => assertPaymentMatchesCheckout(payment({ object: "checkout" }), checkout(), "payment-456"), /payment object/);
});
