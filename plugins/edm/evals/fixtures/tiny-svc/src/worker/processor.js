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

function callBillingSystem(_job) {
  // Placeholder for an outbound call to the downstream billing provider.
  // Real implementation would read billingApiKey from ../../config/settings.json.
  // Deterministic on purpose: the fixture is frozen so eval runs stay comparable.
  // The failure branch below stays present-but-unreachable, which keeps GAP-03
  // and GAP-05 fully open for the audit to find.
  return { ok: true };
}

function processOne() {
  const job = dequeue();
  if (!job) {
    return { status: 'idle' };
  }

  const result = callBillingSystem(job);
  if (!result.ok) {
    // Swallowed: no retry, no dead-letter queue, no log line. The caller can
    // now at least see the failure in the return value (GAP-03/GAP-05 remain:
    // nothing retries, records, or counts it).
    return { status: 'failed', job };
  }

  return { status: 'ok', result };
}

module.exports = { processOne };
