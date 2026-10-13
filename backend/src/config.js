function validateConfiguration(config) {
  const mongoUri = config.MONGODB_URI?.trim();
  if (!mongoUri || !/^mongodb(?:\+srv)?:\/\//i.test(mongoUri)) {
    throw new Error('Set MONGODB_URI in backend/.env to a valid MongoDB connection URI.');
  }

  const jwtSecret = config.JWT_SECRET?.trim();
  if (!jwtSecret || jwtSecret.length < 32) {
    throw new Error('Set JWT_SECRET in backend/.env to a random value at least 32 characters long.');
  }

  const stripeSecret = config.STRIPE_SECRET_KEY?.trim();
  if (stripeSecret && !/^sk_(test|live)_/.test(stripeSecret)) {
    throw new Error('STRIPE_SECRET_KEY must be a Stripe secret key beginning with sk_test_ or sk_live_.');
  }

  return { mongoUri, jwtSecret, stripeSecret: stripeSecret || null };
}

module.exports = { validateConfiguration };
