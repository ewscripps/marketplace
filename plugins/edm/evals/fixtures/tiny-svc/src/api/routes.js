// routes.js -- tiny-svc route table.
//
// A minimal static route table. Real services in this product line usually
// add auth middleware per route; tiny-svc's table has no middleware column
// at all, which is part of GAP-01 in ../../expected.json -- there is no
// mechanism to attach one even if someone wanted to.

const routes = [
  { method: 'POST', path: '/webhooks/payment', handler: 'handleWebhook' },
  { method: 'GET', path: '/health', handler: 'handleHealth' },
];

function handleHealth() {
  return { status: 200, body: 'ok' };
}

module.exports = { routes, handleHealth };
