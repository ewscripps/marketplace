// server.js -- tiny-svc HTTP entry point.
//
// Receives inbound webhook POSTs from a payment provider and hands each
// accepted payload straight to the worker queue for asynchronous processing.
//
// KNOWN GAP (see ../../expected.json GAP-01): this handler does not verify
// any request signature, shared secret, or auth header before accepting a
// payload. Any caller who can reach this endpoint can enqueue a job.
//
// KNOWN GAP (see ../../expected.json GAP-04): the payload is forwarded to
// the queue without validating that required fields are present or of the
// expected type. An absent or non-object body throws right here in the
// handler; a well-formed body carrying wrong values fails later, inside
// the worker, where the original request context is gone.

const { routes } = require('./routes');
const { enqueue } = require('../worker/queue');

function handleWebhook(request) {
  // request: { method, path, body }
  const route = routes.find((r) => r.path === request.path && r.method === request.method);
  if (!route || route.handler !== 'handleWebhook') {
    return { status: 404, body: 'not found' };
  }

  // No signature check, no shared-secret check, no allow-list check here.
  const payload = request.body;

  // No shape validation: payload.eventType, payload.amount, payload.accountId
  // are all assumed present and correctly typed.
  enqueue({ type: payload.eventType, data: payload });

  return { status: 202, body: 'accepted' };
}

module.exports = { handleWebhook };
