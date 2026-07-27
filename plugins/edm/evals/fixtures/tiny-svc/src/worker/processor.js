// processor.js -- tiny-svc background worker.
//
// Drains the queue and forwards each accepted job to a downstream billing
// system. This file intentionally has no config-driven behavior and no
// tests anywhere in the fixture (see ../../expected.json GAP-06).
//
// KNOWN GAP (see ../../expected.json GAP-03): a failed downstream call is
// dropped on the floor. There is no retry, no backoff, and no dead-letter
// path -- one transient failure on the billing side means the event is
// gone forever.
//
// KNOWN GAP (see ../../expected.json GAP-05): failures are neither logged
// nor counted anywhere. An operator has no way to notice this is happening.

const { dequeue } = require('./queue');
const { settings } = require('../../config/settings.json');

function callBillingSystem(job) {
  // Placeholder for an outbound call to the downstream billing provider.
  // Real implementation would use settings.billingApiKey below.
  return { ok: Math.random() > 0.1 };
}

function processOne() {
  const job = dequeue();
  if (!job) {
    return null;
  }

  const result = callBillingSystem(job);
  if (!result.ok) {
    // Swallowed: no retry, no dead-letter queue, no log line.
    return null;
  }

  return result;
}

module.exports = { processOne, settings };
