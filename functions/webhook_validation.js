const crypto = require("crypto");

function verifyPaymentsSignature(secret, signatureHeader, rawBody, nowMs = Date.now(), toleranceSeconds = 300) {
  if (typeof secret !== "string" || secret.length === 0) return false;
  if (typeof signatureHeader !== "string" || !Buffer.isBuffer(rawBody)) return false;

  let timestamp;
  const signatures = [];
  for (const part of signatureHeader.split(",")) {
    const [key, value] = part.trim().split("=", 2);
    if (key === "t" && /^[0-9]{1,12}$/.test(value || "")) timestamp = Number(value);
    if (key === "v1" && /^[0-9a-f]{64}$/i.test(value || "")) signatures.push(value);
  }
  if (timestamp === undefined || signatures.length === 0) return false;
  if (Math.abs(nowMs / 1000 - timestamp) > toleranceSeconds) return false;

  const expected = crypto
    .createHmac("sha256", secret)
    .update(`${timestamp}.`, "utf8")
    .update(rawBody)
    .digest();

  return signatures.some((signature) => {
    const candidate = Buffer.from(signature, "hex");
    return candidate.length === expected.length && crypto.timingSafeEqual(candidate, expected);
  });
}

function parsePaymentsLkEvent(event) {
  if (!event || typeof event !== "object" || Array.isArray(event)) {
    throw new Error("Webhook event must be an object.");
  }
  if (event.type !== "payment.succeeded") return null;

  const data = event.data;
  let payment = null;
  if (data && typeof data === "object" && !Array.isArray(data)) {
    if (data.object === "payment") payment = data;
    else if (data.object && typeof data.object === "object" && !Array.isArray(data.object)) {
      payment = data.object;
    }
  }
  if (!payment || payment.object !== "payment") {
    throw new Error("Payment success event is missing its documented payment object.");
  }
  if (typeof payment.id !== "string" || payment.id.length === 0) {
    throw new Error("Payment success event is missing the payment ID.");
  }
  if (payment.status !== "succeeded" || !Number.isSafeInteger(payment.amountCents)) {
    throw new Error("Payment success event has invalid status or amount.");
  }
  if (payment.currency !== "LKR" || typeof payment.reference !== "string" || !payment.reference) {
    throw new Error("Payment success event has invalid currency or reference.");
  }
  if (typeof payment.checkoutId !== "string" || payment.checkoutId.length === 0) {
    throw new Error("Payment success event is missing the checkout ID.");
  }
  return payment;
}

module.exports = { verifyPaymentsSignature, parsePaymentsLkEvent };
