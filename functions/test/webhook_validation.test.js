const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { verifyPaymentsSignature, parsePaymentsLkEvent } = require("../webhook_validation");

function signedHeader(secret, rawBody, timestamp) {
  const digest = crypto.createHmac("sha256", secret).update(`${timestamp}.`).update(rawBody).digest("hex");
  return `t=${timestamp},v1=${digest}`;
}

test("accepts a valid Payments.lk timestamped raw-body signature", () => {
  const secret = "dedicated-webhook-secret";
  const body = Buffer.from('{"type":"payment.succeeded","data":{"id":"pay_test"}}');
  const now = 1_800_000_000_000;
  const timestamp = Math.floor(now / 1000);
  assert.equal(verifyPaymentsSignature(secret, signedHeader(secret, body, timestamp), body, now), true);
});

test("rejects modified bytes and signatures outside the five-minute window", () => {
  const secret = "dedicated-webhook-secret";
  const body = Buffer.from('{"type":"payment.succeeded"}');
  const now = 1_800_000_000_000;
  const timestamp = Math.floor(now / 1000);
  const header = signedHeader(secret, body, timestamp);
  assert.equal(verifyPaymentsSignature(secret, header, Buffer.from(`${body} `), now), false);
  assert.equal(verifyPaymentsSignature(secret, signedHeader(secret, body, timestamp - 301), body, now), false);
});

test("rejects missing secrets, malformed headers, and non-raw bodies", () => {
  const body = Buffer.from("{}");
  assert.equal(verifyPaymentsSignature("", "t=1,v1=00", body), false);
  assert.equal(verifyPaymentsSignature("secret", "sha256=abcd", body), false);
  assert.equal(verifyPaymentsSignature("secret", "t=1,v1=00", "{}"), false);
});

test("accepts any valid v1 signature included during secret rotation", () => {
  const secret = "current-secret";
  const body = Buffer.from("{}\n");
  const now = 1_800_000_000_000;
  const timestamp = Math.floor(now / 1000);
  const valid = signedHeader(secret, body, timestamp).split(",")[1];
  assert.equal(verifyPaymentsSignature(secret, `t=${timestamp},v1=${"0".repeat(64)},${valid}`, body, now), true);
});

test("parses the documented Payments.lk event.data payment object", () => {
  const payment = {
    object: "payment",
    id: "pay_x1n31wnp8nkbjkkhymtqd6zs",
    status: "succeeded",
    amountCents: 350000,
    currency: "LKR",
    reference: "sub_owner_123",
    checkoutId: "chk_z6zf7gkx4fcwy3402kmwrm3w",
  };
  const event = {
    id: "evt_ev85ebwj9yqjq81vwf5qwz9m",
    object: "event",
    type: "payment.succeeded",
    data: payment,
  };

  assert.deepEqual(parsePaymentsLkEvent(event), payment);
  assert.equal(parsePaymentsLkEvent({ type: "payment.failed", data: payment }), null);
});

test("rejects malformed signed success events rather than reading the object label as payment data", () => {
  assert.throws(() => parsePaymentsLkEvent({
    type: "payment.succeeded",
    data: { object: "payment" },
  }), /payment ID/);
  assert.throws(() => parsePaymentsLkEvent({
    type: "payment.succeeded",
    data: { object: "payment", id: "pay_1", status: "succeeded", amountCents: 1000, currency: "LKR", reference: "sub_1" },
  }), /checkout ID/);
});
