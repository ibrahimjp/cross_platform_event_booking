const test = require('node:test');
const assert = require('node:assert/strict');
const { app, eventSchema, readOrderFromCheckoutSession } = require('./server');

const event = {
  ticketCategories: [
    { id: 'general', name: 'General Admission', price: 1000, remaining: 10 },
  ],
};

function checkoutSession(overrides = {}) {
  return {
    payment_status: 'paid',
    currency: 'inr',
    amount_total: 118000,
    metadata: {
      quantities: '{"general":1}',
      promoCode: '',
      subtotal: '1000',
      discount: '0',
      taxesAndFees: '180',
      total: '1180',
    },
    ...overrides,
  };
}

test('reconciles a paid Stripe Checkout session against server-side pricing', () => {
  const order = readOrderFromCheckoutSession(checkoutSession(), event);
  assert.equal(order.total, 1180);
  assert.deepEqual(order.lines, [{ categoryId: 'general', name: 'General Admission', price: 1000, quantity: 1 }]);
});

test('rejects sessions whose amount, currency, status, or metadata do not match', () => {
  assert.throws(() => readOrderFromCheckoutSession(checkoutSession({ amount_total: 100 }), event), /do not match/);
  assert.throws(() => readOrderFromCheckoutSession(checkoutSession({ currency: 'usd' }), event), /do not match/);
  assert.throws(() => readOrderFromCheckoutSession(checkoutSession({ payment_status: 'unpaid' }), event), /do not match/);
  assert.throws(
    () => readOrderFromCheckoutSession(checkoutSession({ metadata: { ...checkoutSession().metadata, total: '1' } }), event),
    /do not match/,
  );
});

test('rejects sessions for tickets that are no longer available', () => {
  assert.throws(
    () => readOrderFromCheckoutSession(checkoutSession(), {
      ticketCategories: [{ id: 'general', name: 'General Admission', price: 1000, remaining: 0 }],
    }),
    /tickets remain/,
  );
});

test('rejects duplicate ticket IDs and end dates before the start date', () => {
  const base = {
    title: 'Community Showcase',
    category: 'Cultural',
    startsAt: '2026-11-01T18:00:00.000Z',
    time: '6:00 PM',
    location: 'Toronto',
    venue: 'City Hall',
    description: 'A community arts and culture event.',
    ticketCategories: [{ id: 'general', name: 'General', price: 10, remaining: 10 }],
  };
  assert.equal(eventSchema.safeParse(base).success, true);
  assert.equal(eventSchema.safeParse({
    ...base,
    ticketCategories: [
      { id: 'general', name: 'General', price: 10, remaining: 10 },
      { id: 'general', name: 'VIP', price: 20, remaining: 10 },
    ],
  }).success, false);
  assert.equal(eventSchema.safeParse({ ...base, endsAt: '2026-10-01T18:00:00.000Z' }).success, false);
});

test('health endpoint responds and protected routes require authentication', async () => {
  const server = app.listen(0, '127.0.0.1');
  try {
    await new Promise((resolve) => server.once('listening', resolve));
    const baseUrl = `http://127.0.0.1:${server.address().port}`;
    const health = await fetch(`${baseUrl}/health`);
    assert.deepEqual(await health.json(), { status: 'ok' });

    for (const [method, path] of [['POST', '/api/events'], ['GET', '/api/auth/me'], ['POST', '/api/payments/checkout']]) {
      const response = await fetch(`${baseUrl}${path}`, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: method === 'GET' ? undefined : '{}',
      });
      assert.equal(response.status, 401, `${method} ${path}`);
    }
  } finally {
    await new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
  }
});
