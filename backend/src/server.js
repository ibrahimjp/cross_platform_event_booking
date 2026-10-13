require('dotenv').config();

const crypto = require('node:crypto');
const bcrypt = require('bcryptjs');
const cors = require('cors');
const express = require('express');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const multer = require('multer');
const Stripe = require('stripe');
const { z } = require('zod');
const { Booking, Event, Promo, Setting, User } = require('./models');
const { calculateOrder, normalizePromoCode, DEFAULT_PROMOS } = require('./pricing');
const { validateConfiguration } = require('./config');
const { upload, uploadBuffer, deleteImage } = require('./cloudinary');
const { seedDatabase } = require('./seed');
const { registerAdminRoutes } = require('./admin');

const app = express();
const configuredStripeKey = process.env.STRIPE_SECRET_KEY?.trim();
const stripe = configuredStripeKey && /^sk_(test|live)_/.test(configuredStripeKey)
  ? new Stripe(configuredStripeKey)
  : null;

const CATEGORIES = ['Music', 'Festival', 'Networking', 'Food', 'Cultural', 'Sports', 'Comedy', 'Workshop'];
// Platform-wide switches managed from the admin app; cached in memory and persisted in MongoDB.
const DEFAULT_SETTINGS = { categories: CATEGORIES, salesPaused: false, registrationsOpen: true };
const settings = { ...DEFAULT_SETTINGS };

async function loadSettings() {
  const rows = await Setting.find({ key: { $in: Object.keys(DEFAULT_SETTINGS) } }).lean();
  for (const row of rows) settings[row.key] = row.value;
}

async function saveSettings(changes) {
  for (const [key, value] of Object.entries(changes)) {
    if (!(key in DEFAULT_SETTINGS) || value === undefined) continue;
    await Setting.updateOne({ key }, { value }, { upsert: true });
    settings[key] = value;
  }
  return { ...settings };
}
const emailSchema = z.string().trim().email().max(254);
const passwordSchema = z.string().min(8).max(128);
const ticketInputSchema = z.object({
  id: z.string().trim().min(1).max(80).optional(),
  name: z.string().trim().min(2).max(80),
  price: z.number().finite().min(0).max(10000000),
  description: z.string().trim().max(300).default(''),
  remaining: z.number().int().min(0).max(1000000),
});
const eventSchema = z.object({
  title: z.string().trim().min(3).max(120),
  category: z.string().trim().min(2).max(40),
  startsAt: z.coerce.date(),
  endsAt: z.coerce.date().optional().nullable(),
  time: z.string().trim().min(1).max(60),
  location: z.string().trim().min(2).max(100),
  venue: z.string().trim().min(2).max(160),
  description: z.string().trim().min(10).max(5000),
  lineup: z.array(z.string().trim().min(1).max(100)).max(30).default([]),
  ticketCategories: z.array(ticketInputSchema).min(1).max(20).superRefine((categories, context) => {
    const ids = new Set();
    categories.forEach((category, index) => {
      if (!category.id) return;
      if (ids.has(category.id)) {
        context.addIssue({
          code: 'custom',
          path: [index, 'id'],
          message: 'Ticket category IDs must be unique within an event.',
        });
      }
      ids.add(category.id);
    });
  }),
  removeImage: z.boolean().optional(),
}).refine((value) => !value.endsAt || value.endsAt >= value.startsAt, {
  message: 'The end date must be after the start date.',
  path: ['endsAt'],
});

app.disable('x-powered-by');
// Behind a hosting proxy (Render, Railway, Nginx) set TRUST_PROXY=1 so rate limits see real client IPs.
const trustProxyHops = Number(process.env.TRUST_PROXY || 0);
app.set('trust proxy', trustProxyHops > 0 ? trustProxyHops : false);
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
const allowedOrigins = (process.env.CLIENT_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
const LOCAL_ORIGIN = /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/i;
app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.includes(origin) || LOCAL_ORIGIN.test(origin)) {
      return callback(null, true);
    }
    const error = new Error('This client origin is not allowed.');
    error.statusCode = 403;
    return callback(error);
  },
}));

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function httpError(statusCode, message) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function publicUser(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone || '',
    city: user.city || '',
    avatarUrl: user.avatarUrl || '',
    wishlist: (user.wishlist || []).map(String),
    preferredCategories: user.preferredCategories || [],
    notificationsEnabled: user.notificationsEnabled !== false,
  };
}

function serializeEvent(event) {
  const data = typeof event.toObject === 'function' ? event.toObject() : event;
  const host = data.hostId && typeof data.hostId === 'object' && data.hostId.name
    ? { id: String(data.hostId._id), name: data.hostId.name, avatarUrl: data.hostId.avatarUrl || '' }
    : null;
  const { imagePublicId, __v, ...rest } = data;
  return {
    ...rest,
    _id: String(data._id),
    hostId: host ? host.id : String(data.hostId),
    host,
  };
}

function baseUrl(req) {
  const configured = process.env.PUBLIC_URL?.trim();
  if (configured) return configured.replace(/\/$/, '');
  return `${req.protocol}://${req.get('host')}`;
}

function parseEventBody(req) {
  let body = req.body;
  if (typeof body?.data === 'string') {
    try {
      body = JSON.parse(body.data);
    } catch {
      throw httpError(400, 'Event details could not be read.');
    }
  }
  const input = eventSchema.safeParse(body);
  if (!input.success) {
    const issue = input.error.issues[0];
    const field = issue?.path?.join('.') || 'details';
    throw httpError(400, `Check the event ${field}: ${issue?.message || 'invalid value'}.`);
  }
  const ticketCategories = input.data.ticketCategories.map((ticket) => ({
    ...ticket,
    id: ticket.id || `tc-${crypto.randomUUID().slice(0, 8)}`,
  }));
  return {
    ...input.data,
    endsAt: input.data.endsAt || new Date(input.data.startsAt.getTime() + 3 * 60 * 60 * 1000),
    ticketCategories,
    priceStarting: Math.min(...ticketCategories.map((ticket) => ticket.price)),
  };
}

function createToken(user) {
  return jwt.sign({ sub: user.id, tv: user.tokenVersion || 0 }, process.env.JWT_SECRET, { expiresIn: '7d' });
}

// Verifies the bearer token and that the account still exists, is not suspended, and has
// not been signed out everywhere by an admin (tokenVersion bump).
async function authenticate(req) {
  const token = req.get('authorization')?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) throw httpError(401, 'Sign in to continue.');
  let payload;
  try {
    payload = jwt.verify(token, process.env.JWT_SECRET);
  } catch {
    throw httpError(401, 'Your session has expired. Sign in again.');
  }
  const account = await User.findById(payload.sub).select('role isBlocked tokenVersion').lean();
  if (!account) throw httpError(401, 'Your session has expired. Sign in again.');
  if (account.isBlocked) throw httpError(403, 'Your account has been suspended. Contact support.');
  if ((payload.tv || 0) !== (account.tokenVersion || 0)) {
    throw httpError(401, 'Your session has expired. Sign in again.');
  }
  return { payload, account };
}

async function requireAuth(req, _res, next) {
  const { payload } = await authenticate(req);
  req.userId = payload.sub;
  return next();
}

async function loadUser(req) {
  const user = await User.findById(req.userId);
  if (!user) throw httpError(401, 'Your account could not be found. Sign in again.');
  return user;
}

function requireStripe() {
  if (!stripe) throw httpError(503, 'Stripe is not configured on the server.');
}

async function getStripeCustomer(user) {
  if (user.stripeCustomerId) {
    try {
      const existing = await stripe.customers.retrieve(user.stripeCustomerId);
      if (!existing.deleted) return user.stripeCustomerId;
    } catch (error) {
      if (error?.code !== 'resource_missing') throw error;
    }
  }
  const customer = await stripe.customers.create({
    email: user.email,
    name: user.name,
    metadata: { userId: user.id },
  });
  user.stripeCustomerId = customer.id;
  await user.save();
  return customer.id;
}

async function releaseInventory(eventId, lines) {
  for (const line of lines) {
    await Event.updateOne(
      { _id: eventId, 'ticketCategories.id': line.categoryId },
      { $inc: { 'ticketCategories.$.remaining': line.quantity, ticketsSold: -line.quantity } },
    );
  }
}

// Reserves tickets with conditional atomic updates (works on a standalone MongoDB, no
// replica-set transactions required) and rolls back if any step fails.
async function resolvePromo(code, { lenient = false } = {}) {
  const normalized = normalizePromoCode(code);
  if (!normalized) return null;
  const promo = await Promo.findOne({ code: normalized }).lean();
  if (!promo) return null;
  // Lenient lookups reconcile already-paid checkouts, so later edits to the code's
  // availability do not cause a mismatch with what the customer agreed to pay.
  if (lenient) return promo;
  if (!promo.active) return null;
  if (promo.expiresAt && promo.expiresAt < new Date()) return null;
  if (promo.maxUses > 0 && promo.uses >= promo.maxUses) return null;
  return promo;
}

async function reserveInventoryAndCreateBooking({
  userId, event, order, paymentIntentId, checkoutSessionId, promoCode, issuedByAdmin = false, adminNote = '',
  testPayment = false,
}) {
  const reserved = [];
  try {
    for (const line of order.lines) {
      const result = await Event.updateOne(
        {
          _id: event._id,
          ticketCategories: { $elemMatch: { id: line.categoryId, remaining: { $gte: line.quantity } } },
        },
        { $inc: { 'ticketCategories.$.remaining': -line.quantity, ticketsSold: line.quantity } },
      );
      if (result.modifiedCount !== 1) {
        throw httpError(409, 'A selected ticket just sold out. Please choose another ticket.');
      }
      reserved.push(line);
    }
    const appliedPromo = order.discount > 0 && !issuedByAdmin ? normalizePromoCode(promoCode) : '';
    const booking = await Booking.create({
      userId,
      eventId: event._id,
      paymentIntentId: paymentIntentId || undefined,
      checkoutSessionId: checkoutSessionId || undefined,
      tickets: order.lines,
      subtotal: order.subtotal,
      discount: order.discount,
      taxesAndFees: order.taxesAndFees,
      totalPaid: order.total,
      status: order.total === 0 ? 'Free' : 'Confirmed',
      promoCode: appliedPromo,
      issuedByAdmin,
      adminNote,
      testPayment,
    });
    if (appliedPromo) await Promo.updateOne({ code: appliedPromo }, { $inc: { uses: 1 } });
    return booking;
  } catch (error) {
    await releaseInventory(event._id, reserved);
    if (error.code === 11000 && checkoutSessionId) {
      const existing = await Booking.findOne({ checkoutSessionId });
      if (existing) return existing;
    }
    throw error;
  }
}

async function populateBooking(booking) {
  return Booking.findById(booking._id).populate('eventId').lean();
}

function orderMetadata(event, userId, quantities, order, promoCode) {
  return {
    eventId: event.id,
    userId,
    quantities: JSON.stringify(quantities),
    subtotal: String(order.subtotal),
    discount: String(order.discount),
    taxesAndFees: String(order.taxesAndFees),
    total: String(order.total),
    promoCode: normalizePromoCode(promoCode),
  };
}

// Recomputes the order from the database and checks Stripe charged exactly that amount.
function readOrderFromCheckoutSession(session, event, promo) {
  const metadata = session.metadata || {};
  const quantities = z.record(z.string(), z.number().int().min(1).max(10)).parse(
    JSON.parse(metadata.quantities || '{}'),
  );
  const order = calculateOrder(event, quantities, metadata.promoCode, promo);
  const expectedAmount = Math.round(order.total * 100);
  if (
    session.payment_status !== 'paid' ||
    session.currency !== 'inr' ||
    session.amount_total !== expectedAmount ||
    Number(metadata.subtotal) !== order.subtotal ||
    Number(metadata.discount) !== order.discount ||
    Number(metadata.taxesAndFees) !== order.taxesAndFees ||
    Number(metadata.total) !== order.total
  ) {
    throw new Error('Payment details do not match the event ticket order.');
  }
  return order;
}

async function refundPaymentIntent(paymentIntentId) {
  if (!paymentIntentId) return;
  await stripe.refunds.create({ payment_intent: paymentIntentId });
}

// Cancels a booking, refunds paid bookings through Stripe (unless refund is false), and
// returns the tickets to inventory. The status flip is claimed atomically first so
// concurrent cancellations cannot double-refund.
async function cancelBooking(booking, { refund = true, by = 'user', reason = '' } = {}) {
  const claimed = await Booking.findOneAndUpdate(
    { _id: booking._id, status: { $ne: 'Cancelled' } },
    { status: 'Cancelled', cancelledAt: new Date(), cancelledBy: by, cancelReason: reason },
    { new: true },
  );
  if (!claimed) throw httpError(409, 'This booking is already cancelled.');
  const shouldRefund = refund && booking.paymentIntentId && booking.totalPaid > 0;
  if (shouldRefund) {
    try {
      requireStripe();
      await refundPaymentIntent(booking.paymentIntentId);
    } catch (error) {
      await Booking.updateOne(
        { _id: booking._id },
        { status: booking.status, cancelledAt: null, cancelledBy: null, cancelReason: '' },
      );
      console.error('Refund failed during cancellation:', error.message);
      throw httpError(502, 'The refund could not be processed, so the booking was not cancelled. Try again.');
    }
    claimed.refunded = true;
    await Booking.updateOne({ _id: booking._id }, { refunded: true });
  }
  if (await Event.exists({ _id: booking.eventId })) await releaseInventory(booking.eventId, booking.tickets);
  return claimed;
}

const inflightCheckouts = new Map();

function finalizeCheckoutSession(sessionId) {
  if (!inflightCheckouts.has(sessionId)) {
    const work = doFinalizeCheckoutSession(sessionId).finally(() => inflightCheckouts.delete(sessionId));
    inflightCheckouts.set(sessionId, work);
  }
  return inflightCheckouts.get(sessionId);
}

async function doFinalizeCheckoutSession(sessionId) {
  const session = await stripe.checkout.sessions.retrieve(sessionId);
  const existing = await Booking.findOne({ checkoutSessionId: session.id });
  if (existing) return { status: 'paid', session, booking: existing };
  if (session.mode !== 'payment') return { status: 'invalid', session };
  if (session.status === 'expired') return { status: 'expired', session };
  if (session.payment_status !== 'paid') return { status: 'pending', session };

  const paymentIntentId = typeof session.payment_intent === 'string'
    ? session.payment_intent
    : session.payment_intent?.id;
  const event = await Event.findById(session.metadata?.eventId);
  try {
    if (!event) throw new Error('The event could not be found.');
    const promo = await resolvePromo(session.metadata?.promoCode, { lenient: true });
    const order = readOrderFromCheckoutSession(session, event, promo);
    const booking = await reserveInventoryAndCreateBooking({
      userId: session.metadata.userId,
      event,
      order,
      paymentIntentId,
      checkoutSessionId: session.id,
      promoCode: session.metadata?.promoCode,
    });
    return { status: 'paid', session, booking };
  } catch (error) {
    const alreadyBooked = await Booking.findOne({ checkoutSessionId: session.id });
    if (alreadyBooked) return { status: 'paid', session, booking: alreadyBooked };
    console.error('Paid checkout could not be booked; refunding:', error.message);
    try {
      await refundPaymentIntent(paymentIntentId);
    } catch (refundError) {
      console.error('Automatic refund failed:', refundError.message);
      return {
        status: 'failed',
        session,
        message: 'Payment succeeded but the ticket could not be reserved. Contact support with your receipt.',
      };
    }
    return {
      status: 'refunded',
      session,
      message: `${error.message.startsWith('A selected ticket') ? error.message : 'Booking could not be completed.'} Your payment has been refunded.`,
    };
  }
}

// ---------------------------------------------------------------------------
// Stripe webhook (optional – the app also confirms directly with Stripe)
// ---------------------------------------------------------------------------

app.post('/api/stripe/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  if (!stripe || !process.env.STRIPE_WEBHOOK_SECRET) {
    return res.status(503).send('Stripe webhook is not configured.');
  }
  let event;
  try {
    event = stripe.webhooks.constructEvent(req.body, req.get('stripe-signature'), process.env.STRIPE_WEBHOOK_SECRET);
  } catch {
    return res.status(400).send('Invalid webhook signature.');
  }
  if (event.type === 'checkout.session.completed' && event.data.object.mode === 'payment') {
    const result = await finalizeCheckoutSession(event.data.object.id);
    if (result.status === 'failed') return res.status(500).send('Booking reconciliation is pending.');
  }
  return res.json({ received: true });
});

app.use(express.json({ limit: '64kb' }));
app.use('/api', rateLimit({ windowMs: 60_000, limit: 300 }));

// ---------------------------------------------------------------------------
// Health + Stripe return pages
// ---------------------------------------------------------------------------

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

function resultPage(title, message, ok) {
  const color = ok ? '#16a34a' : '#dc2626';
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title}</title><style>body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#f8f9ff;margin:0;display:flex;min-height:100vh;align-items:center;justify-content:center;padding:16px}
.card{background:#fff;border-radius:20px;padding:32px;max-width:420px;text-align:center;box-shadow:0 8px 24px rgba(31,41,55,.08)}
h1{color:${color};font-size:24px;margin:0 0 12px}p{color:#494454;line-height:1.5}
a{display:inline-block;margin-top:16px;background:#6b38d4;color:#fff;padding:12px 22px;border-radius:12px;text-decoration:none;font-weight:600}</style></head>
<body><div class="card"><h1>${title}</h1><p>${message}</p><a href="eventbook://stripe-redirect">Return to EventBook</a></div></body></html>`;
}

app.get('/payment/success', async (req, res) => {
  const sessionId = String(req.query.session_id || '');
  if (!stripe || !sessionId) return res.send(resultPage('Payment received', 'You can return to the EventBook app.', true));
  try {
    const result = await finalizeCheckoutSession(sessionId);
    if (result.status === 'paid') {
      return res.send(resultPage('Payment successful 🎉', 'Your tickets are confirmed. Return to the EventBook app to see your digital ticket.', true));
    }
    return res.send(resultPage('Payment not completed', result.message || 'Your payment is still processing. Return to the app to check its status.', false));
  } catch (error) {
    console.error('Success page could not finalize checkout:', error.message);
    return res.send(resultPage('Payment received', 'Return to the EventBook app to finish your booking.', true));
  }
});

app.get('/payment/cancel', (_req, res) => {
  res.send(resultPage('Payment cancelled', 'No money was taken. Return to the EventBook app to try again.', false));
});

app.get('/payment/card-saved', (_req, res) => {
  res.send(resultPage('Card saved', 'Your card was saved securely with Stripe. Return to the EventBook app.', true));
});

// ---------------------------------------------------------------------------
// Auth + profile
// ---------------------------------------------------------------------------

app.post('/api/auth/register', rateLimit({ windowMs: 15 * 60_000, limit: 30 }), async (req, res) => {
  const input = z.object({
    name: z.string().trim().min(2).max(100),
    email: emailSchema,
    password: passwordSchema,
  }).safeParse(req.body);
  if (!input.success) {
    return res.status(400).json({ error: 'Enter your name, a valid email, and a password with at least 8 characters.' });
  }
  if (settings.registrationsOpen === false) {
    return res.status(403).json({ error: 'New sign-ups are temporarily closed.' });
  }
  const email = input.data.email.toLowerCase();
  if (await User.exists({ email })) return res.status(409).json({ error: 'An account with this email already exists.' });
  const user = await User.create({
    name: input.data.name,
    email,
    passwordHash: await bcrypt.hash(input.data.password, 12),
  });
  return res.status(201).json({ token: createToken(user), user: publicUser(user) });
});

app.post('/api/auth/login', rateLimit({ windowMs: 15 * 60_000, limit: 50 }), async (req, res) => {
  const input = z.object({ email: emailSchema, password: z.string().min(1).max(128) }).safeParse(req.body);
  if (!input.success) return res.status(400).json({ error: 'Enter a valid email and password.' });
  const user = await User.findOne({ email: input.data.email.toLowerCase() });
  if (!user || !(await bcrypt.compare(input.data.password, user.passwordHash))) {
    return res.status(401).json({ error: 'Email or password is incorrect.' });
  }
  if (user.isBlocked) return res.status(403).json({ error: 'Your account has been suspended. Contact support.' });
  user.lastLoginAt = new Date();
  await user.save();
  return res.json({ token: createToken(user), user: publicUser(user) });
});

app.get('/api/auth/me', requireAuth, async (req, res) => {
  const user = await loadUser(req);
  return res.json({ user: publicUser(user) });
});

app.patch('/api/auth/profile', requireAuth, async (req, res) => {
  const input = z.object({
    name: z.string().trim().min(2).max(100).optional(),
    email: emailSchema.optional(),
    phone: z.string().trim().max(30).optional(),
    city: z.string().trim().max(60).optional(),
    preferredCategories: z.array(z.string().trim().min(1).max(40)).max(20).optional(),
    notificationsEnabled: z.boolean().optional(),
  }).safeParse(req.body);
  if (!input.success) return res.status(400).json({ error: 'Enter a valid name (2+ characters) and email.' });
  const user = await loadUser(req);
  if (input.data.email) {
    const email = input.data.email.toLowerCase();
    if (await User.exists({ email, _id: { $ne: user._id } })) {
      return res.status(409).json({ error: 'An account with this email already exists.' });
    }
    user.email = email;
  }
  for (const key of ['name', 'phone', 'city', 'preferredCategories', 'notificationsEnabled']) {
    if (input.data[key] !== undefined) user[key] = input.data[key];
  }
  await user.save();
  return res.json({ user: publicUser(user) });
});

app.post('/api/auth/password', requireAuth, async (req, res) => {
  const input = z.object({ currentPassword: z.string().min(1).max(128), newPassword: passwordSchema }).safeParse(req.body);
  if (!input.success) return res.status(400).json({ error: 'The new password must have at least 8 characters.' });
  const user = await loadUser(req);
  if (!(await bcrypt.compare(input.data.currentPassword, user.passwordHash))) {
    return res.status(400).json({ error: 'Your current password is incorrect.' });
  }
  user.passwordHash = await bcrypt.hash(input.data.newPassword, 12);
  await user.save();
  return res.json({ ok: true });
});

app.post('/api/auth/avatar', requireAuth, upload.single('avatar'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Choose an image to upload.' });
  const user = await loadUser(req);
  const uploaded = await uploadBuffer(req.file.buffer, 'eventbook/avatars');
  const previous = user.avatarPublicId;
  user.avatarUrl = uploaded.url;
  user.avatarPublicId = uploaded.publicId;
  await user.save();
  await deleteImage(previous);
  return res.json({ user: publicUser(user) });
});

app.delete('/api/auth/avatar', requireAuth, async (req, res) => {
  const user = await loadUser(req);
  const previous = user.avatarPublicId;
  user.avatarUrl = '';
  user.avatarPublicId = '';
  await user.save();
  await deleteImage(previous);
  return res.json({ user: publicUser(user) });
});

app.post('/api/auth/wishlist/:eventId', requireAuth, async (req, res) => {
  const user = await loadUser(req);
  if (!(await Event.exists({ _id: req.params.eventId }))) throw httpError(404, 'Event not found.');
  const index = user.wishlist.findIndex((id) => String(id) === req.params.eventId);
  if (index === -1) user.wishlist.push(req.params.eventId);
  else user.wishlist.splice(index, 1);
  await user.save();
  return res.json({ user: publicUser(user) });
});

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

app.get('/api/events/categories', (_req, res) => res.json({ categories: settings.categories }));

app.get('/api/events', async (req, res) => {
  const filter = req.query.includePast === 'true'
    ? { isHidden: { $ne: true } }
    : { endsAt: { $gte: new Date() }, isHidden: { $ne: true } };
  const events = await Event.find(filter)
    .populate('hostId', 'name avatarUrl')
    .sort({ startsAt: 1 })
    .limit(300)
    .lean();
  return res.json({ events: events.map(serializeEvent) });
});

app.get('/api/events/:id', async (req, res) => {
  const event = await Event.findById(req.params.id).populate('hostId', 'name avatarUrl').lean();
  if (!event || event.isHidden) throw httpError(404, 'Event not found.');
  return res.json({ event: serializeEvent(event) });
});

app.post('/api/events', requireAuth, upload.single('image'), async (req, res) => {
  const data = parseEventBody(req);
  delete data.removeImage;
  await loadUser(req);
  let image = { url: '', publicId: '' };
  if (req.file) image = await uploadBuffer(req.file.buffer, 'eventbook/events');
  try {
    const event = await Event.create({
      ...data,
      imageUrl: image.url,
      imagePublicId: image.publicId,
      hostId: req.userId,
      aiReason: `Hosted on EventBook in ${data.location}.`,
    });
    await event.populate('hostId', 'name avatarUrl');
    return res.status(201).json({ event: serializeEvent(event) });
  } catch (error) {
    await deleteImage(image.publicId);
    throw error;
  }
});

async function loadHostedEvent(req) {
  const event = await Event.findById(req.params.id);
  if (!event) throw httpError(404, 'Event not found.');
  if (String(event.hostId) !== req.userId) throw httpError(403, 'Only the host can manage this event.');
  return event;
}

app.patch('/api/events/:id', requireAuth, upload.single('image'), async (req, res) => {
  const event = await loadHostedEvent(req);
  const { removeImage, ...data } = parseEventBody(req);
  const previousPublicId = event.imagePublicId;
  let replacedImage = false;
  if (req.file) {
    const image = await uploadBuffer(req.file.buffer, 'eventbook/events');
    event.imageUrl = image.url;
    event.imagePublicId = image.publicId;
    replacedImage = true;
  } else if (removeImage) {
    event.imageUrl = '';
    event.imagePublicId = '';
    replacedImage = true;
  }
  Object.assign(event, data);
  await event.save();
  if (replacedImage) await deleteImage(previousPublicId);
  await event.populate('hostId', 'name avatarUrl');
  return res.json({ event: serializeEvent(event) });
});

app.delete('/api/events/:id', requireAuth, async (req, res) => {
  const event = await loadHostedEvent(req);
  const activeBookings = await Booking.countDocuments({ eventId: event._id, status: { $ne: 'Cancelled' } });
  if (activeBookings > 0) {
    throw httpError(409, `This event has ${activeBookings} active booking(s). Cancel them before deleting the event.`);
  }
  await Booking.deleteMany({ eventId: event._id });
  await User.updateMany({ wishlist: event._id }, { $pull: { wishlist: event._id } });
  await event.deleteOne();
  await deleteImage(event.imagePublicId);
  return res.status(204).end();
});

app.get('/api/host/events', requireAuth, async (req, res) => {
  const events = await Event.find({ hostId: req.userId })
    .populate('hostId', 'name avatarUrl')
    .sort({ startsAt: -1 })
    .lean();
  const stats = await Booking.aggregate([
    { $match: { eventId: { $in: events.map((event) => event._id) }, status: { $ne: 'Cancelled' } } },
    { $unwind: '$tickets' },
    {
      $group: {
        _id: '$eventId',
        tickets: { $sum: '$tickets.quantity' },
        bookings: { $addToSet: '$_id' },
      },
    },
  ]);
  const revenue = await Booking.aggregate([
    { $match: { eventId: { $in: events.map((event) => event._id) }, status: { $ne: 'Cancelled' } } },
    { $group: { _id: '$eventId', revenue: { $sum: '$totalPaid' } } },
  ]);
  const statsById = new Map(stats.map((row) => [String(row._id), row]));
  const revenueById = new Map(revenue.map((row) => [String(row._id), row.revenue]));
  return res.json({
    events: events.map((event) => ({
      ...serializeEvent(event),
      stats: {
        ticketsSold: statsById.get(String(event._id))?.tickets || 0,
        bookings: statsById.get(String(event._id))?.bookings.length || 0,
        revenue: Math.round((revenueById.get(String(event._id)) || 0) * 100) / 100,
      },
    })),
  });
});

app.get('/api/host/events/:id/bookings', requireAuth, async (req, res) => {
  const event = await loadHostedEvent(req);
  const bookings = await Booking.find({ eventId: event._id })
    .populate('userId', 'name email avatarUrl')
    .sort({ createdAt: -1 })
    .lean();
  return res.json({
    bookings: bookings.map((booking) => ({
      _id: String(booking._id),
      status: booking.status,
      totalPaid: booking.totalPaid,
      tickets: booking.tickets,
      createdAt: booking.createdAt,
      attendee: booking.userId
        ? { name: booking.userId.name, email: booking.userId.email, avatarUrl: booking.userId.avatarUrl || '' }
        : { name: 'Deleted user', email: '', avatarUrl: '' },
    })),
  });
});

// ---------------------------------------------------------------------------
// Checkout + bookings
// ---------------------------------------------------------------------------

const checkoutInputSchema = z.object({
  eventId: z.string().min(1),
  quantities: z.record(z.string(), z.number().int().min(1).max(10)),
  promoCode: z.string().max(40).optional(),
});

app.post('/api/payments/quote', requireAuth, async (req, res) => {
  const input = checkoutInputSchema.safeParse(req.body);
  if (!input.success) return res.status(400).json({ error: 'Invalid checkout details.' });
  const event = await Event.findById(input.data.eventId);
  if (!event || event.isHidden) throw httpError(404, 'This event is no longer available.');
  const promo = await resolvePromo(input.data.promoCode);
  try {
    return res.json({ order: calculateOrder(event, input.data.quantities, input.data.promoCode, promo) });
  } catch (error) {
    throw httpError(400, error.message);
  }
});

app.post('/api/payments/checkout', requireAuth, async (req, res) => {
  const input = checkoutInputSchema.safeParse(req.body);
  if (!input.success) return res.status(400).json({ error: 'Invalid checkout details.' });
  if (settings.salesPaused) throw httpError(503, 'Ticket sales are temporarily paused. Please try again later.');
  const event = await Event.findById(input.data.eventId);
  if (!event || event.isHidden) throw httpError(404, 'This event is no longer available.');
  if (event.endsAt < new Date()) throw httpError(400, 'This event has already ended.');
  const promo = await resolvePromo(input.data.promoCode);
  let order;
  try {
    order = calculateOrder(event, input.data.quantities, input.data.promoCode, promo);
  } catch (error) {
    throw httpError(400, error.message);
  }
  const user = await loadUser(req);

  if (order.total === 0) {
    const booking = await reserveInventoryAndCreateBooking({
      userId: user.id, event, order, promoCode: input.data.promoCode,
    });
    return res.status(201).json({ requiresPayment: false, booking: await populateBooking(booking) });
  }

  requireStripe();
  const metadata = orderMetadata(event, user.id, input.data.quantities, order, input.data.promoCode);
  if (metadata.quantities.length > 450) throw httpError(400, 'Select fewer ticket types in one checkout.');
  const customer = await getStripeCustomer(user);
  const ticketSummary = order.lines.map((line) => `${line.quantity} × ${line.name}`).join(', ');
  const root = baseUrl(req);
  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    customer,
    client_reference_id: user.id,
    line_items: [{
      quantity: 1,
      price_data: {
        currency: 'inr',
        unit_amount: Math.round(order.total * 100),
        product_data: {
          name: event.title,
          description: `${ticketSummary}. Includes 18% GST${order.discount ? ` and ₹${order.discount} promo discount` : ''}.`,
          ...(event.imageUrl ? { images: [event.imageUrl] } : {}),
        },
      },
    }],
    metadata,
    payment_intent_data: { metadata },
    saved_payment_method_options: { payment_method_save: 'enabled' },
    success_url: `${root}/payment/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${root}/payment/cancel`,
    expires_at: Math.floor(Date.now() / 1000) + 30 * 60,
  });
  return res.json({ requiresPayment: true, sessionId: session.id, url: session.url, order });
});

// Demo-only checkout: books tickets without charging a card (for presentations). The booking is
// flagged `testPayment` and the route is disabled unless ALLOW_TEST_PAYMENTS=true.
const testPaymentsEnabled = () => process.env.ALLOW_TEST_PAYMENTS?.trim().toLowerCase() === 'true';

app.get('/api/payments/config', (_req, res) => res.json({ testPaymentsEnabled: testPaymentsEnabled() }));

app.post('/api/payments/test-checkout', requireAuth, async (req, res) => {
  if (!testPaymentsEnabled()) throw httpError(403, 'Test payments are disabled on this server.');
  const input = checkoutInputSchema.safeParse(req.body);
  if (!input.success) return res.status(400).json({ error: 'Invalid checkout details.' });
  if (settings.salesPaused) throw httpError(503, 'Ticket sales are temporarily paused. Please try again later.');
  const event = await Event.findById(input.data.eventId);
  if (!event || event.isHidden) throw httpError(404, 'This event is no longer available.');
  if (event.endsAt < new Date()) throw httpError(400, 'This event has already ended.');
  const promo = await resolvePromo(input.data.promoCode);
  let order;
  try {
    order = calculateOrder(event, input.data.quantities, input.data.promoCode, promo);
  } catch (error) {
    throw httpError(400, error.message);
  }
  const user = await loadUser(req);
  const booking = await reserveInventoryAndCreateBooking({
    userId: user.id, event, order, promoCode: input.data.promoCode, testPayment: order.total > 0,
  });
  return res.status(201).json({ booking: await populateBooking(booking) });
});

app.get('/api/payments/checkout/:sessionId', requireAuth, async (req, res) => {
  requireStripe();
  const result = await finalizeCheckoutSession(req.params.sessionId);
  if (result.session.metadata?.userId !== req.userId) throw httpError(404, 'Checkout not found.');
  return res.json({
    status: result.status,
    message: result.message,
    booking: result.booking ? await populateBooking(result.booking) : null,
  });
});

app.get('/api/bookings', requireAuth, async (req, res) => {
  const bookings = await Booking.find({ userId: req.userId })
    .populate('eventId')
    .sort({ createdAt: -1 })
    .limit(200)
    .lean();
  return res.json({ bookings: bookings.filter((booking) => booking.eventId) });
});

app.post('/api/bookings/:id/cancel', requireAuth, async (req, res) => {
  const booking = await Booking.findOne({ _id: req.params.id, userId: req.userId });
  if (!booking) throw httpError(404, 'Booking not found.');
  if (booking.status === 'Cancelled') throw httpError(409, 'This booking is already cancelled.');
  const event = await Event.findById(booking.eventId);
  if (event && event.startsAt < new Date() && event.endsAt < new Date()) {
    throw httpError(400, 'Bookings for past events cannot be cancelled.');
  }
  const claimed = await cancelBooking(booking, { by: 'user' });
  return res.json({ booking: await populateBooking(claimed) });
});

// ---------------------------------------------------------------------------
// Saved payment methods (managed entirely by Stripe)
// ---------------------------------------------------------------------------

app.post('/api/payments/setup', requireAuth, async (req, res) => {
  requireStripe();
  const user = await loadUser(req);
  const customer = await getStripeCustomer(user);
  const root = baseUrl(req);
  const session = await stripe.checkout.sessions.create({
    mode: 'setup',
    currency: 'inr',
    customer,
    payment_method_types: ['card'],
    success_url: `${root}/payment/card-saved`,
    cancel_url: `${root}/payment/cancel`,
  });
  return res.json({ url: session.url, sessionId: session.id });
});

app.get('/api/payments/methods', requireAuth, async (req, res) => {
  requireStripe();
  const user = await loadUser(req);
  if (!user.stripeCustomerId) return res.json({ methods: [] });
  const methods = await stripe.customers.listPaymentMethods(user.stripeCustomerId, { type: 'card', limit: 20 });
  return res.json({
    methods: methods.data.map(({ id, card }) => ({
      id,
      brand: card.brand,
      last4: card.last4,
      expMonth: card.exp_month,
      expYear: card.exp_year,
    })),
  });
});

app.delete('/api/payments/methods/:id', requireAuth, async (req, res) => {
  requireStripe();
  const user = await loadUser(req);
  if (!user.stripeCustomerId) throw httpError(404, 'Payment method not found.');
  const method = await stripe.paymentMethods.retrieve(req.params.id);
  if (method.customer !== user.stripeCustomerId) throw httpError(404, 'Payment method not found.');
  await stripe.paymentMethods.detach(method.id);
  return res.status(204).end();
});

// ---------------------------------------------------------------------------
// Admin API (separate app; see src/admin.js)
// ---------------------------------------------------------------------------

registerAdminRoutes(app, {
  authenticate,
  httpError,
  serializeEvent,
  parseEventBody,
  cancelBooking,
  reserveInventoryAndCreateBooking,
  settings,
  saveSettings,
  getStripe: () => stripe,
  isWebhookConfigured: () => Boolean(stripe && process.env.STRIPE_WEBHOOK_SECRET),
});

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

app.use((_req, res) => res.status(404).json({ error: 'Route not found.' }));

app.use((error, _req, res, _next) => {
  if (error instanceof multer.MulterError) {
    const message = error.code === 'LIMIT_FILE_SIZE' ? 'Images must be 8 MB or smaller.' : 'The image upload was invalid.';
    return res.status(400).json({ error: message });
  }
  if (error instanceof z.ZodError) return res.status(400).json({ error: 'Invalid request.' });
  if (error.code === 11000) return res.status(409).json({ error: 'This record already exists.' });
  if (error.name === 'CastError') return res.status(404).json({ error: 'The requested record was not found.' });
  if (error.name === 'ValidationError') return res.status(400).json({ error: error.message });
  if (error.type === 'StripeInvalidRequestError' || error.type === 'StripeCardError') {
    console.error('Stripe error:', error.message);
    return res.status(400).json({ error: `Payment provider error: ${error.message}` });
  }
  const status = error.statusCode || error.status || 500;
  if (status >= 500) console.error('Request failed:', error);
  return res.status(status).json({
    error: status >= 500 && !error.statusCode ? 'The request could not be completed.' : error.message,
  });
});

// Creates (or promotes) the admin named by ADMIN_EMAIL / ADMIN_PASSWORD in backend/.env.
async function ensureAdminFromEnv() {
  const email = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD || '';
  if (!email) return;
  const existing = await User.findOne({ email });
  if (existing) {
    if (existing.role !== 'admin' || existing.isBlocked) {
      existing.role = 'admin';
      existing.isBlocked = false;
      await existing.save();
      console.log(`[admin] Promoted ${email} to admin.`);
    }
    return;
  }
  if (password.length < 8) {
    console.warn('[admin] ADMIN_PASSWORD must have at least 8 characters; admin account not created.');
    return;
  }
  await User.create({
    name: process.env.ADMIN_NAME?.trim() || 'EventBook Admin',
    email,
    passwordHash: await bcrypt.hash(password, 12),
    role: 'admin',
  });
  console.log(`[admin] Created admin account ${email}.`);
}

async function start() {
  const config = validateConfiguration(process.env);
  await mongoose.connect(config.mongoUri);
  await seedDatabase({ log: (message) => console.log(`[seed] ${message}`) });
  await loadSettings();
  if (await Promo.estimatedDocumentCount() === 0) await Promo.insertMany(DEFAULT_PROMOS);
  await ensureAdminFromEnv();
  const port = Number(process.env.PORT || 3000);
  app.listen(port, '0.0.0.0', () => {
    console.log(`EventBook API listening on http://0.0.0.0:${port}`);
    const nets = require('node:os').networkInterfaces();
    for (const addresses of Object.values(nets)) {
      for (const address of addresses || []) {
        if (address.family === 'IPv4' && !address.internal) {
          console.log(`  Phones on the same Wi-Fi can use: http://${address.address}:${port}`);
        }
      }
    }
  });
}

if (require.main === module) {
  start().catch((error) => {
    console.error('Unable to start EventBook API:', error.message);
    process.exitCode = 1;
  });
}

module.exports = { app, calculateOrder, eventSchema, readOrderFromCheckoutSession };
