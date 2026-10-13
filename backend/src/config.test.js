const test = require('node:test');
const assert = require('node:assert/strict');
const { validateConfiguration } = require('./config');

const validConfig = {
  MONGODB_URI: 'mongodb+srv://cluster.example.test/eventbook',
  JWT_SECRET: 'a-random-secret-with-at-least-thirty-two-characters',
};

test('validates MongoDB and JWT configuration before the API starts', () => {
  assert.equal(validateConfiguration(validConfig).stripeSecret, null);
  assert.throws(
    () => validateConfiguration({ ...validConfig, MONGODB_URI: '' }),
    /MONGODB_URI/,
  );
  assert.throws(
    () => validateConfiguration({ ...validConfig, JWT_SECRET: 'short' }),
    /JWT_SECRET/,
  );
});

test('accepts only a Stripe secret key on the backend', () => {
  assert.equal(
    validateConfiguration({ ...validConfig, STRIPE_SECRET_KEY: 'sk_test_example' }).stripeSecret,
    'sk_test_example',
  );
  assert.throws(
    () => validateConfiguration({ ...validConfig, STRIPE_SECRET_KEY: 'pk_test_example' }),
    /STRIPE_SECRET_KEY/,
  );
});
