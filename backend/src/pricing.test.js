const test = require('node:test');
const assert = require('node:assert/strict');
const { calculateOrder } = require('./pricing');

const event = {
  ticketCategories: [
    { id: 'standard', name: 'Standard', price: 1000, remaining: 3 },
    { id: 'free', name: 'Free', price: 0, remaining: 5 },
  ],
};

test('calculates subtotal, discount, and tax using server-side ticket prices', () => {
  assert.deepEqual(calculateOrder(event, { standard: 2 }, 'EVEAI200'), {
    lines: [{ categoryId: 'standard', name: 'Standard', price: 1000, quantity: 2 }],
    subtotal: 2000,
    discount: 200,
    taxesAndFees: 324,
    total: 2124,
  });
});

test('rejects invalid categories, quantities, and unavailable inventory', () => {
  assert.throws(() => calculateOrder(event, { missing: 1 }), /invalid/);
  assert.throws(() => calculateOrder(event, { standard: 0 }), /invalid/);
  assert.throws(() => calculateOrder(event, { standard: 4 }), /remain/);
  assert.throws(() => calculateOrder(event, {}), /Select/);
});

test('supports free tickets without inventing a payment amount', () => {
  assert.equal(calculateOrder(event, { free: 2 }).total, 0);
});

test('rejects totals outside the supported Stripe payment limit', () => {
  assert.throws(
    () => calculateOrder(
      { ticketCategories: [{ id: 'premium', name: 'Premium', price: 1000000, remaining: 10 }] },
      { premium: 1 },
    ),
    /supported payment limit/,
  );
});

test('applies managed flat and percentage promo codes with caps and minimums', () => {
  const flat = { type: 'flat', value: 300, maxDiscount: 0, minSubtotal: 0 };
  assert.equal(calculateOrder(event, { standard: 1 }, 'X', flat).discount, 300);
  const percent = { type: 'percent', value: 25, maxDiscount: 400, minSubtotal: 0 };
  assert.equal(calculateOrder(event, { standard: 1 }, 'X', percent).discount, 250);
  assert.equal(calculateOrder(event, { standard: 3 }, 'X', percent).discount, 400);
  const minimum = { type: 'flat', value: 100, maxDiscount: 0, minSubtotal: 5000 };
  assert.equal(calculateOrder(event, { standard: 1 }, 'X', minimum).discount, 0);
  assert.equal(calculateOrder(event, { standard: 1 }, 'EVEAI200', null).discount, 0);
});
