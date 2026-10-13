const bcrypt = require('bcryptjs');
const express = require('express');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const rateLimit = require('express-rate-limit');
const { z } = require('zod');
const { AdminLog, Booking, Event, Promo, User } = require('./models');
const { calculateOrder } = require('./pricing');
const { upload, uploadBuffer, deleteImage, isCloudinaryConfigured } = require('./cloudinary');

// Everything under /api/admin. Admin tokens carry `scope: 'admin'`, so tokens issued to the
// customer app can never call these routes, and the role is re-checked on every request.
function registerAdminRoutes(app, deps) {
  const {
    authenticate,
    httpError,
    serializeEvent,
    parseEventBody,
    cancelBooking,
    reserveInventoryAndCreateBooking,
    settings,
    saveSettings,
    getStripe,
    isWebhookConfigured,
  } = deps;

  const router = express.Router();
  const startedAt = new Date();

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  function createAdminToken(user) {
    return jwt.sign(
      { sub: user.id, tv: user.tokenVersion || 0, scope: 'admin' },
      process.env.JWT_SECRET,
      { expiresIn: '12h' },
    );
  }

  async function requireAdmin(req, _res, next) {
    const { payload, account } = await authenticate(req);
    if (payload.scope !== 'admin' || account.role !== 'admin') {
      throw httpError(403, 'Admin access is required.');
    }
    req.admin = await User.findById(payload.sub).select('name email').lean();
    return next();
  }

  function adminUser(user) {
    return {
      id: String(user._id),
      name: user.name,
      email: user.email,
      phone: user.phone || '',
      city: user.city || '',
      avatarUrl: user.avatarUrl || '',
      role: user.role || 'user',
      isBlocked: Boolean(user.isBlocked),
      blockedReason: user.blockedReason || '',
      preferredCategories: user.preferredCategories || [],
      notificationsEnabled: user.notificationsEnabled !== false,
      wishlistCount: (user.wishlist || []).length,
      hasStripeCustomer: Boolean(user.stripeCustomerId),
      lastLoginAt: user.lastLoginAt || null,
      createdAt: user.createdAt,
    };
  }

  function serializeBooking(booking) {
    const user = booking.userId && typeof booking.userId === 'object' && booking.userId.email !== undefined
      ? booking.userId
      : null;
    const event = booking.eventId && typeof booking.eventId === 'object' && booking.eventId.title !== undefined
      ? booking.eventId
      : null;
    return {
      _id: String(booking._id),
      status: booking.status,
      tickets: booking.tickets,
      ticketCount: (booking.tickets || []).reduce((sum, line) => sum + line.quantity, 0),
      subtotal: booking.subtotal,
      discount: booking.discount,
      taxesAndFees: booking.taxesAndFees,
      totalPaid: booking.totalPaid,
      promoCode: booking.promoCode || '',
      paymentIntentId: booking.paymentIntentId || '',
      checkoutSessionId: booking.checkoutSessionId || '',
      refunded: Boolean(booking.refunded),
      cancelledAt: booking.cancelledAt,
      cancelledBy: booking.cancelledBy || null,
      cancelReason: booking.cancelReason || '',
      issuedByAdmin: Boolean(booking.issuedByAdmin),
      adminNote: booking.adminNote || '',
      createdAt: booking.createdAt,
      user: user
        ? { id: String(user._id), name: user.name, email: user.email, avatarUrl: user.avatarUrl || '' }
        : null,
      userId: user ? String(user._id) : String(booking.userId || ''),
      event: event
        ? {
          id: String(event._id),
          title: event.title,
          startsAt: event.startsAt,
          venue: event.venue,
          imageUrl: event.imageUrl || '',
        }
        : null,
      eventId: event ? String(event._id) : String(booking.eventId || ''),
    };
  }

  async function audit(req, action, targetType, targetId, summary) {
    try {
      await AdminLog.create({
        adminId: req.admin?._id,
        adminName: req.admin?.name || '',
        action,
        targetType,
        targetId: String(targetId || ''),
        summary,
      });
    } catch (error) {
      console.error('Could not write admin log:', error.message);
    }
  }

  function escapeRegex(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function paging(req, defaultLimit = 25) {
    const page = Math.max(1, Number.parseInt(req.query.page, 10) || 1);
    const limit = Math.min(200, Math.max(1, Number.parseInt(req.query.limit, 10) || defaultLimit));
    return { page, limit, skip: (page - 1) * limit };
  }

  function pageResult(key, items, total, { page, limit }) {
    return { [key]: items, total, page, pages: Math.max(1, Math.ceil(total / limit)) };
  }

  function validId(id) {
    return mongoose.isValidObjectId(id);
  }

  function parse(schema, body, message) {
    const result = schema.safeParse(body);
    if (!result.success) {
      const issue = result.error.issues[0];
      const field = issue?.path?.join('.');
      throw httpError(400, message || `Check ${field || 'the details'}: ${issue?.message || 'invalid value'}.`);
    }
    return result.data;
  }

  async function eventStats(eventIds) {
    const rows = await Booking.aggregate([
      { $match: { eventId: { $in: eventIds }, status: { $ne: 'Cancelled' } } },
      {
        $group: {
          _id: '$eventId',
          bookings: { $sum: 1 },
          revenue: { $sum: '$totalPaid' },
          tickets: { $sum: { $sum: '$tickets.quantity' } },
        },
      },
    ]);
    return new Map(rows.map((row) => [String(row._id), {
      bookings: row.bookings,
      ticketsSold: row.tickets,
      revenue: Math.round(row.revenue * 100) / 100,
    }]));
  }

  async function userStats(userIds) {
    const [bookingRows, hostRows] = await Promise.all([
      Booking.aggregate([
        { $match: { userId: { $in: userIds } } },
        {
          $group: {
            _id: '$userId',
            bookings: { $sum: 1 },
            spent: { $sum: { $cond: [{ $ne: ['$status', 'Cancelled'] }, '$totalPaid', 0] } },
          },
        },
      ]),
      Event.aggregate([
        { $match: { hostId: { $in: userIds } } },
        { $group: { _id: '$hostId', events: { $sum: 1 } } },
      ]),
    ]);
    const bookings = new Map(bookingRows.map((row) => [String(row._id), row]));
    const hosted = new Map(hostRows.map((row) => [String(row._id), row.events]));
    return (id) => ({
      bookings: bookings.get(String(id))?.bookings || 0,
      totalSpent: Math.round((bookings.get(String(id))?.spent || 0) * 100) / 100,
      eventsHosted: hosted.get(String(id)) || 0,
    });
  }

  // Cancels every active booking on an event (refunding paid ones). Stops at the first
  // refund failure so the admin can retry without double refunds.
  async function cancelAllForEvent(eventId, reason) {
    const active = await Booking.find({ eventId, status: { $ne: 'Cancelled' } });
    for (const booking of active) {
      await cancelBooking(booking, { refund: true, by: 'admin', reason });
    }
    return active.length;
  }

  // Admin-only event fields that the shared event schema does not accept.
  const eventExtrasSchema = z.object({
    hostId: z.string().optional(),
    imageUrl: z.string().trim().max(2000).optional(),
    isHidden: z.boolean().optional(),
    isTrending: z.boolean().optional(),
    isGarbaSpecial: z.boolean().optional(),
    matchPercentage: z.number().int().min(0).max(100).optional(),
    aiReason: z.string().trim().max(300).optional(),
    attendeeCount: z.number().int().min(0).max(10000000).optional(),
  });

  function readEventExtras(req) {
    let body = req.body;
    if (typeof body?.data === 'string') {
      try {
        body = JSON.parse(body.data);
      } catch {
        throw httpError(400, 'Event details could not be read.');
      }
    }
    const extras = parse(eventExtrasSchema, body || {});
    if (extras.imageUrl && !/^https?:\/\//i.test(extras.imageUrl)) {
      throw httpError(400, 'The image URL must start with http:// or https://.');
    }
    return extras;
  }

  async function resolveHost(hostId, fallback) {
    if (!hostId) return fallback;
    if (!validId(hostId) || !(await User.exists({ _id: hostId }))) {
      throw httpError(400, 'The selected host account does not exist.');
    }
    return hostId;
  }

  // -------------------------------------------------------------------------
  // Auth
  // -------------------------------------------------------------------------

  router.post('/auth/login', rateLimit({ windowMs: 15 * 60_000, limit: 20 }), async (req, res) => {
    const input = parse(
      z.object({ email: z.string().trim().email().max(254), password: z.string().min(1).max(128) }),
      req.body,
      'Enter a valid email and password.',
    );
    const user = await User.findOne({ email: input.email.toLowerCase() });
    const valid = user && (await bcrypt.compare(input.password, user.passwordHash));
    if (!valid || user.role !== 'admin') {
      return res.status(401).json({ error: 'These credentials do not belong to an admin account.' });
    }
    if (user.isBlocked) return res.status(403).json({ error: 'This admin account is suspended.' });
    user.lastLoginAt = new Date();
    await user.save();
    req.admin = { _id: user._id, name: user.name };
    await audit(req, 'admin.login', 'user', user.id, `${user.email} signed in to the admin panel`);
    return res.json({ token: createAdminToken(user), admin: adminUser(user.toObject()) });
  });

  router.use(requireAdmin);

  router.get('/auth/me', async (req, res) => {
    const user = await User.findById(req.admin._id).lean();
    return res.json({ admin: adminUser(user) });
  });

  router.post('/auth/password', async (req, res) => {
    const input = parse(
      z.object({ currentPassword: z.string().min(1).max(128), newPassword: z.string().min(8).max(128) }),
      req.body,
      'The new password must have at least 8 characters.',
    );
    const user = await User.findById(req.admin._id);
    if (!(await bcrypt.compare(input.currentPassword, user.passwordHash))) {
      throw httpError(400, 'Your current password is incorrect.');
    }
    user.passwordHash = await bcrypt.hash(input.newPassword, 12);
    user.tokenVersion = (user.tokenVersion || 0) + 1;
    await user.save();
    await audit(req, 'admin.password', 'user', user.id, 'Changed own admin password');
    return res.json({ token: createAdminToken(user) });
  });

  // -------------------------------------------------------------------------
  // Overview dashboard
  // -------------------------------------------------------------------------

  router.get('/overview', async (_req, res) => {
    const now = new Date();
    // Days are bucketed in UTC so the series keys match MongoDB's $dateToString output.
    const since = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - 29));

    const [
      users, admins, blockedUsers, newUsers30d,
      events, upcomingEvents, hiddenEvents,
      bookingTotals, daily, categories, topEvents,
      recentBookings, recentUsers, lowInventory,
    ] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ role: 'admin' }),
      User.countDocuments({ isBlocked: true }),
      User.countDocuments({ createdAt: { $gte: since } }),
      Event.countDocuments(),
      Event.countDocuments({ endsAt: { $gte: now } }),
      Event.countDocuments({ isHidden: true }),
      Booking.aggregate([
        {
          $group: {
            _id: null,
            total: { $sum: 1 },
            active: { $sum: { $cond: [{ $ne: ['$status', 'Cancelled'] }, 1, 0] } },
            cancelled: { $sum: { $cond: [{ $eq: ['$status', 'Cancelled'] }, 1, 0] } },
            revenue: { $sum: { $cond: [{ $ne: ['$status', 'Cancelled'] }, '$totalPaid', 0] } },
            refunded: { $sum: { $cond: ['$refunded', '$totalPaid', 0] } },
            tickets: {
              $sum: { $cond: [{ $ne: ['$status', 'Cancelled'] }, { $sum: '$tickets.quantity' }, 0] },
            },
          },
        },
      ]),
      Booking.aggregate([
        { $match: { createdAt: { $gte: since }, status: { $ne: 'Cancelled' } } },
        {
          $group: {
            _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
            revenue: { $sum: '$totalPaid' },
            bookings: { $sum: 1 },
          },
        },
      ]),
      Booking.aggregate([
        { $match: { status: { $ne: 'Cancelled' } } },
        { $lookup: { from: 'events', localField: 'eventId', foreignField: '_id', as: 'event' } },
        { $unwind: '$event' },
        {
          $group: {
            _id: '$event.category',
            revenue: { $sum: '$totalPaid' },
            tickets: { $sum: { $sum: '$tickets.quantity' } },
          },
        },
        { $sort: { revenue: -1 } },
      ]),
      Booking.aggregate([
        { $match: { status: { $ne: 'Cancelled' } } },
        {
          $group: {
            _id: '$eventId',
            revenue: { $sum: '$totalPaid' },
            tickets: { $sum: { $sum: '$tickets.quantity' } },
          },
        },
        { $sort: { revenue: -1, tickets: -1 } },
        { $limit: 5 },
        { $lookup: { from: 'events', localField: '_id', foreignField: '_id', as: 'event' } },
        { $unwind: '$event' },
      ]),
      Booking.find().populate('userId', 'name email avatarUrl').populate('eventId', 'title startsAt venue imageUrl')
        .sort({ createdAt: -1 }).limit(8).lean(),
      User.find().sort({ createdAt: -1 }).limit(6).lean(),
      Event.find({ endsAt: { $gte: now }, 'ticketCategories.remaining': { $lte: 10 } })
        .select('title startsAt ticketCategories').sort({ startsAt: 1 }).limit(8).lean(),
    ]);

    const dailyById = new Map(daily.map((row) => [row._id, row]));
    const series = [];
    for (let i = 0; i < 30; i += 1) {
      const day = new Date(since.getTime() + i * 86_400_000);
      const key = day.toISOString().slice(0, 10);
      const row = dailyById.get(key);
      series.push({ date: key, revenue: Math.round((row?.revenue || 0) * 100) / 100, bookings: row?.bookings || 0 });
    }
    const totals = bookingTotals[0] || {};
    const round = (value) => Math.round((value || 0) * 100) / 100;

    return res.json({
      totals: {
        users,
        admins,
        blockedUsers,
        newUsers30d,
        events,
        upcomingEvents,
        pastEvents: events - upcomingEvents,
        hiddenEvents,
        bookings: totals.total || 0,
        activeBookings: totals.active || 0,
        cancelledBookings: totals.cancelled || 0,
        ticketsSold: totals.tickets || 0,
        revenue: round(totals.revenue),
        refunded: round(totals.refunded),
        revenue30d: round(series.reduce((sum, row) => sum + row.revenue, 0)),
      },
      daily: series,
      categories: categories.map((row) => ({ category: row._id, revenue: round(row.revenue), tickets: row.tickets })),
      topEvents: topEvents.map((row) => ({
        id: String(row._id),
        title: row.event.title,
        imageUrl: row.event.imageUrl || '',
        revenue: round(row.revenue),
        tickets: row.tickets,
      })),
      recentBookings: recentBookings.map(serializeBooking),
      recentUsers: recentUsers.map(adminUser),
      lowInventory: lowInventory.map((event) => ({
        id: String(event._id),
        title: event.title,
        startsAt: event.startsAt,
        tickets: event.ticketCategories
          .filter((ticket) => ticket.remaining <= 10)
          .map((ticket) => ({ name: ticket.name, remaining: ticket.remaining })),
      })),
      settings: { ...settings },
    });
  });

  // -------------------------------------------------------------------------
  // Users
  // -------------------------------------------------------------------------

  router.get('/users', async (req, res) => {
    const filter = {};
    const q = String(req.query.q || '').trim();
    if (q) {
      const pattern = new RegExp(escapeRegex(q), 'i');
      filter.$or = [{ name: pattern }, { email: pattern }, { phone: pattern }, { city: pattern }];
    }
    if (req.query.role === 'admin' || req.query.role === 'user') filter.role = req.query.role;
    if (req.query.status === 'blocked') filter.isBlocked = true;
    if (req.query.status === 'active') filter.isBlocked = { $ne: true };
    const sorts = { newest: { createdAt: -1 }, oldest: { createdAt: 1 }, name: { name: 1 }, lastLogin: { lastLoginAt: -1 } };
    const sort = sorts[req.query.sort] || sorts.newest;
    const pageInfo = paging(req);
    const [users, total] = await Promise.all([
      User.find(filter).sort(sort).skip(pageInfo.skip).limit(pageInfo.limit).lean(),
      User.countDocuments(filter),
    ]);
    const stats = await userStats(users.map((user) => user._id));
    return res.json(pageResult('users', users.map((user) => ({ ...adminUser(user), stats: stats(user._id) })), total, pageInfo));
  });

  router.get('/users/:id', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'User not found.');
    const user = await User.findById(req.params.id).populate('wishlist', 'title startsAt').lean();
    if (!user) throw httpError(404, 'User not found.');
    const [bookings, events, stats] = await Promise.all([
      Booking.find({ userId: user._id }).populate('eventId', 'title startsAt venue imageUrl').sort({ createdAt: -1 }).limit(200).lean(),
      Event.find({ hostId: user._id }).sort({ startsAt: -1 }).lean(),
      userStats([user._id]),
    ]);
    const statsByEvent = await eventStats(events.map((event) => event._id));
    return res.json({
      user: { ...adminUser(user), stats: stats(user._id) },
      wishlist: (user.wishlist || []).filter(Boolean).map((event) => ({
        id: String(event._id), title: event.title, startsAt: event.startsAt,
      })),
      bookings: bookings.map((booking) => serializeBooking({ ...booking, userId: user })),
      events: events.map((event) => ({
        ...serializeEvent(event),
        stats: statsByEvent.get(String(event._id)) || { bookings: 0, ticketsSold: 0, revenue: 0 },
      })),
    });
  });

  router.post('/users', async (req, res) => {
    const input = parse(z.object({
      name: z.string().trim().min(2).max(100),
      email: z.string().trim().email().max(254),
      password: z.string().min(8).max(128),
      role: z.enum(['user', 'admin']).default('user'),
      phone: z.string().trim().max(30).default(''),
      city: z.string().trim().max(60).default(''),
    }), req.body);
    const email = input.email.toLowerCase();
    if (await User.exists({ email })) throw httpError(409, 'An account with this email already exists.');
    const user = await User.create({
      name: input.name,
      email,
      phone: input.phone,
      city: input.city,
      role: input.role,
      passwordHash: await bcrypt.hash(input.password, 12),
    });
    await audit(req, 'user.create', 'user', user.id, `Created ${input.role} ${email}`);
    return res.status(201).json({ user: adminUser(user.toObject()) });
  });

  router.patch('/users/:id', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'User not found.');
    const input = parse(z.object({
      name: z.string().trim().min(2).max(100).optional(),
      email: z.string().trim().email().max(254).optional(),
      phone: z.string().trim().max(30).optional(),
      city: z.string().trim().max(60).optional(),
      role: z.enum(['user', 'admin']).optional(),
      isBlocked: z.boolean().optional(),
      blockedReason: z.string().trim().max(300).optional(),
      notificationsEnabled: z.boolean().optional(),
      preferredCategories: z.array(z.string().trim().min(1).max(40)).max(20).optional(),
    }), req.body);
    const user = await User.findById(req.params.id);
    if (!user) throw httpError(404, 'User not found.');
    const isSelf = String(user._id) === String(req.admin._id);
    if (isSelf && (input.isBlocked === true || input.role === 'user')) {
      throw httpError(400, 'You cannot suspend or demote your own admin account.');
    }
    if (user.role === 'admin' && (input.role === 'user' || input.isBlocked === true)) {
      const otherAdmins = await User.countDocuments({ role: 'admin', isBlocked: { $ne: true }, _id: { $ne: user._id } });
      if (otherAdmins === 0) throw httpError(400, 'At least one active admin must remain.');
    }
    if (input.email) {
      const email = input.email.toLowerCase();
      if (await User.exists({ email, _id: { $ne: user._id } })) {
        throw httpError(409, 'An account with this email already exists.');
      }
      user.email = email;
    }
    const changes = [];
    for (const key of ['name', 'phone', 'city', 'role', 'isBlocked', 'blockedReason', 'notificationsEnabled', 'preferredCategories']) {
      if (input[key] !== undefined && JSON.stringify(user[key]) !== JSON.stringify(input[key])) {
        user[key] = input[key];
        changes.push(key);
      }
    }
    if (input.isBlocked === false) user.blockedReason = '';
    // Suspending or changing role ends existing sessions immediately.
    if (changes.includes('isBlocked') || changes.includes('role')) user.tokenVersion = (user.tokenVersion || 0) + 1;
    await user.save();
    const action = changes.includes('isBlocked')
      ? (user.isBlocked ? 'user.suspend' : 'user.reinstate')
      : changes.includes('role') ? 'user.role' : 'user.update';
    await audit(req, action, 'user', user.id, `${user.email}: ${changes.join(', ') || 'no changes'}${user.isBlocked && user.blockedReason ? ` (${user.blockedReason})` : ''}`);
    return res.json({ user: adminUser(user.toObject()) });
  });

  router.post('/users/:id/password', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'User not found.');
    const input = parse(z.object({ password: z.string().min(8).max(128) }), req.body, 'Passwords need at least 8 characters.');
    const user = await User.findById(req.params.id);
    if (!user) throw httpError(404, 'User not found.');
    user.passwordHash = await bcrypt.hash(input.password, 12);
    user.tokenVersion = (user.tokenVersion || 0) + 1;
    await user.save();
    await audit(req, 'user.password', 'user', user.id, `Reset password for ${user.email}`);
    return res.json({ ok: true });
  });

  router.post('/users/:id/sign-out', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'User not found.');
    const user = await User.findByIdAndUpdate(req.params.id, { $inc: { tokenVersion: 1 } }, { new: true });
    if (!user) throw httpError(404, 'User not found.');
    await audit(req, 'user.signout', 'user', user.id, `Signed ${user.email} out of all devices`);
    return res.json({ ok: true });
  });

  router.delete('/users/:id', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'User not found.');
    const user = await User.findById(req.params.id);
    if (!user) throw httpError(404, 'User not found.');
    if (String(user._id) === String(req.admin._id)) throw httpError(400, 'You cannot delete your own account.');
    if (user.role === 'admin' && (await User.countDocuments({ role: 'admin', _id: { $ne: user._id } })) === 0) {
      throw httpError(400, 'At least one admin must remain.');
    }
    const force = req.query.force === 'true';
    const hostedEvents = await Event.find({ hostId: user._id });
    const activeBookings = await Booking.find({ userId: user._id, status: { $ne: 'Cancelled' } })
      .populate('eventId', 'endsAt');
    const upcomingBookings = activeBookings.filter((booking) => booking.eventId && booking.eventId.endsAt >= new Date());
    if (!force && (hostedEvents.length || upcomingBookings.length)) {
      throw httpError(409, `${user.name} hosts ${hostedEvents.length} event(s) and holds ${upcomingBookings.length} upcoming booking(s). Delete with "force" to cancel and refund them.`);
    }
    for (const booking of upcomingBookings) {
      booking.eventId = booking.eventId._id;
      await cancelBooking(booking, { refund: true, by: 'admin', reason: 'Account deleted by admin' });
    }
    for (const event of hostedEvents) {
      await cancelAllForEvent(event._id, 'Event removed because the host account was deleted');
      await User.updateMany({ wishlist: event._id }, { $pull: { wishlist: event._id } });
      await event.deleteOne();
      await deleteImage(event.imagePublicId);
    }
    await user.deleteOne();
    await deleteImage(user.avatarPublicId);
    await audit(req, 'user.delete', 'user', user.id, `Deleted ${user.email} (${hostedEvents.length} hosted event(s), ${upcomingBookings.length} booking(s) cancelled)`);
    return res.status(204).end();
  });

  // -------------------------------------------------------------------------
  // Events
  // -------------------------------------------------------------------------

  router.get('/events', async (req, res) => {
    const now = new Date();
    const filter = {};
    const q = String(req.query.q || '').trim();
    if (q) {
      const pattern = new RegExp(escapeRegex(q), 'i');
      filter.$or = [{ title: pattern }, { venue: pattern }, { location: pattern }];
    }
    if (req.query.status === 'upcoming') filter.endsAt = { $gte: now };
    if (req.query.status === 'past') filter.endsAt = { $lt: now };
    if (req.query.status === 'hidden') filter.isHidden = true;
    if (req.query.status === 'trending') filter.isTrending = true;
    if (req.query.category) filter.category = String(req.query.category);
    if (req.query.hostId && validId(req.query.hostId)) filter.hostId = req.query.hostId;
    const sorts = { soonest: { startsAt: 1 }, latest: { startsAt: -1 }, newest: { createdAt: -1 }, title: { title: 1 } };
    const sort = sorts[req.query.sort] || sorts.latest;
    const pageInfo = paging(req);
    const [events, total] = await Promise.all([
      Event.find(filter).populate('hostId', 'name avatarUrl').sort(sort).skip(pageInfo.skip).limit(pageInfo.limit).lean(),
      Event.countDocuments(filter),
    ]);
    const stats = await eventStats(events.map((event) => event._id));
    return res.json(pageResult('events', events.map((event) => ({
      ...serializeEvent(event),
      stats: stats.get(String(event._id)) || { bookings: 0, ticketsSold: 0, revenue: 0 },
    })), total, pageInfo));
  });

  router.get('/events/:id', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'Event not found.');
    const event = await Event.findById(req.params.id).populate('hostId', 'name avatarUrl').lean();
    if (!event) throw httpError(404, 'Event not found.');
    const [bookings, stats, wishlisted] = await Promise.all([
      Booking.find({ eventId: event._id }).populate('userId', 'name email avatarUrl').sort({ createdAt: -1 }).lean(),
      eventStats([event._id]),
      User.countDocuments({ wishlist: event._id }),
    ]);
    return res.json({
      event: {
        ...serializeEvent(event),
        stats: { ...(stats.get(String(event._id)) || { bookings: 0, ticketsSold: 0, revenue: 0 }), wishlisted },
      },
      bookings: bookings.map((booking) => serializeBooking({ ...booking, eventId: event })),
    });
  });

  router.post('/events', upload.single('image'), async (req, res) => {
    const data = parseEventBody(req);
    delete data.removeImage;
    const extras = readEventExtras(req);
    const hostId = await resolveHost(extras.hostId, req.admin._id);
    delete extras.hostId;
    let image = { url: extras.imageUrl || '', publicId: '' };
    if (req.file) image = await uploadBuffer(req.file.buffer, 'eventbook/events');
    try {
      const event = await Event.create({
        aiReason: `Hosted on EventBook in ${data.location}.`,
        ...data,
        ...extras,
        imageUrl: image.url,
        imagePublicId: image.publicId,
        hostId,
      });
      await event.populate('hostId', 'name avatarUrl');
      await audit(req, 'event.create', 'event', event.id, `Created "${event.title}"`);
      return res.status(201).json({ event: serializeEvent(event) });
    } catch (error) {
      await deleteImage(image.publicId);
      throw error;
    }
  });

  router.patch('/events/:id', upload.single('image'), async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'Event not found.');
    const event = await Event.findById(req.params.id);
    if (!event) throw httpError(404, 'Event not found.');
    const { removeImage, ...data } = parseEventBody(req);
    const extras = readEventExtras(req);
    if (extras.hostId) event.hostId = await resolveHost(extras.hostId);
    delete extras.hostId;
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
    } else if (extras.imageUrl !== undefined && extras.imageUrl !== event.imageUrl) {
      event.imageUrl = extras.imageUrl;
      event.imagePublicId = '';
      replacedImage = true;
    }
    delete extras.imageUrl;
    Object.assign(event, data, extras);
    await event.save();
    if (replacedImage) await deleteImage(previousPublicId);
    await event.populate('hostId', 'name avatarUrl');
    await audit(req, 'event.update', 'event', event.id, `Edited "${event.title}"`);
    return res.json({ event: serializeEvent(event) });
  });

  // Quick toggles from list views: visibility, trending, garba special.
  router.patch('/events/:id/flags', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'Event not found.');
    const input = parse(z.object({
      isHidden: z.boolean().optional(),
      isTrending: z.boolean().optional(),
      isGarbaSpecial: z.boolean().optional(),
    }), req.body);
    const event = await Event.findByIdAndUpdate(req.params.id, input, { new: true }).populate('hostId', 'name avatarUrl');
    if (!event) throw httpError(404, 'Event not found.');
    const summary = Object.entries(input).map(([key, value]) => `${key}=${value}`).join(', ');
    await audit(req, 'event.flags', 'event', event.id, `"${event.title}": ${summary}`);
    return res.json({ event: serializeEvent(event) });
  });

  router.post('/events/:id/duplicate', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'Event not found.');
    const source = await Event.findById(req.params.id).lean();
    if (!source) throw httpError(404, 'Event not found.');
    const { _id, createdAt, updatedAt, __v, imagePublicId, ...rest } = source;
    const event = await Event.create({
      ...rest,
      title: `${source.title} (copy)`.slice(0, 120),
      ticketsSold: 0,
      isHidden: true,
    });
    await event.populate('hostId', 'name avatarUrl');
    await audit(req, 'event.duplicate', 'event', event.id, `Duplicated "${source.title}" as a hidden draft`);
    return res.status(201).json({ event: serializeEvent(event) });
  });

  router.delete('/events/:id', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'Event not found.');
    const event = await Event.findById(req.params.id);
    if (!event) throw httpError(404, 'Event not found.');
    const active = await Booking.countDocuments({ eventId: event._id, status: { $ne: 'Cancelled' } });
    if (active > 0 && req.query.force !== 'true') {
      throw httpError(409, `This event has ${active} active booking(s). Delete with "force" to cancel and refund them.`);
    }
    const cancelled = await cancelAllForEvent(event._id, 'Event cancelled by EventBook');
    await User.updateMany({ wishlist: event._id }, { $pull: { wishlist: event._id } });
    await event.deleteOne();
    await deleteImage(event.imagePublicId);
    await audit(req, 'event.delete', 'event', event.id, `Deleted "${event.title}" (${cancelled} booking(s) cancelled)`);
    return res.status(204).end();
  });

  // -------------------------------------------------------------------------
  // Bookings
  // -------------------------------------------------------------------------

  router.get('/bookings', async (req, res) => {
    const filter = {};
    if (['Confirmed', 'Free', 'Cancelled'].includes(req.query.status)) filter.status = req.query.status;
    if (req.query.status === 'active') filter.status = { $ne: 'Cancelled' };
    if (req.query.status === 'refunded') filter.refunded = true;
    if (req.query.status === 'comp') filter.issuedByAdmin = true;
    if (req.query.eventId && validId(req.query.eventId)) filter.eventId = req.query.eventId;
    if (req.query.userId && validId(req.query.userId)) filter.userId = req.query.userId;
    const q = String(req.query.q || '').trim();
    if (q) {
      const pattern = new RegExp(escapeRegex(q), 'i');
      const [users, events] = await Promise.all([
        User.find({ $or: [{ name: pattern }, { email: pattern }] }).select('_id').limit(500).lean(),
        Event.find({ title: pattern }).select('_id').limit(500).lean(),
      ]);
      filter.$or = [
        { userId: { $in: users.map((user) => user._id) } },
        { eventId: { $in: events.map((event) => event._id) } },
        { promoCode: q.toUpperCase() },
        { paymentIntentId: q },
        ...(validId(q) ? [{ _id: q }] : []),
      ];
    }
    const pageInfo = paging(req, 30);
    const [bookings, total, summary] = await Promise.all([
      Booking.find(filter)
        .populate('userId', 'name email avatarUrl')
        .populate('eventId', 'title startsAt venue imageUrl')
        .sort({ createdAt: -1 })
        .skip(pageInfo.skip)
        .limit(pageInfo.limit)
        .lean(),
      Booking.countDocuments(filter),
      Booking.aggregate([
        { $match: filter },
        {
          $group: {
            _id: null,
            revenue: { $sum: { $cond: [{ $ne: ['$status', 'Cancelled'] }, '$totalPaid', 0] } },
            tickets: { $sum: { $sum: '$tickets.quantity' } },
          },
        },
      ]),
    ]);
    return res.json({
      ...pageResult('bookings', bookings.map(serializeBooking), total, pageInfo),
      summary: {
        revenue: Math.round((summary[0]?.revenue || 0) * 100) / 100,
        tickets: summary[0]?.tickets || 0,
      },
    });
  });

  router.get('/bookings/:id', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'Booking not found.');
    const booking = await Booking.findById(req.params.id)
      .populate('userId', 'name email avatarUrl')
      .populate('eventId', 'title startsAt venue imageUrl')
      .lean();
    if (!booking) throw httpError(404, 'Booking not found.');
    let payment = null;
    const stripe = getStripe();
    if (stripe && booking.paymentIntentId) {
      try {
        const intent = await stripe.paymentIntents.retrieve(booking.paymentIntentId, { expand: ['latest_charge'] });
        const charge = intent.latest_charge && typeof intent.latest_charge === 'object' ? intent.latest_charge : null;
        payment = {
          status: intent.status,
          amount: intent.amount / 100,
          currency: intent.currency,
          amountRefunded: charge ? charge.amount_refunded / 100 : 0,
          cardBrand: charge?.payment_method_details?.card?.brand || '',
          cardLast4: charge?.payment_method_details?.card?.last4 || '',
          receiptUrl: charge?.receipt_url || '',
          livemode: intent.livemode,
        };
      } catch (error) {
        payment = { error: error.message };
      }
    }
    return res.json({ booking: serializeBooking(booking), payment });
  });

  router.post('/bookings/:id/cancel', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'Booking not found.');
    const input = parse(z.object({
      refund: z.boolean().default(true),
      reason: z.string().trim().max(300).default(''),
    }), req.body || {});
    const booking = await Booking.findById(req.params.id);
    if (!booking) throw httpError(404, 'Booking not found.');
    if (booking.status === 'Cancelled') throw httpError(409, 'This booking is already cancelled.');
    const cancelled = await cancelBooking(booking, { refund: input.refund, by: 'admin', reason: input.reason });
    await audit(req, 'booking.cancel', 'booking', booking.id, `Cancelled booking ${booking.id}${cancelled.refunded ? ` and refunded ₹${booking.totalPaid}` : input.refund ? '' : ' without refund'}`);
    const populated = await Booking.findById(booking._id)
      .populate('userId', 'name email avatarUrl')
      .populate('eventId', 'title startsAt venue imageUrl')
      .lean();
    return res.json({ booking: serializeBooking(populated) });
  });

  // Complimentary tickets issued by an admin; they reserve real inventory and cost nothing.
  router.post('/bookings', async (req, res) => {
    const input = parse(z.object({
      userId: z.string().min(1),
      eventId: z.string().min(1),
      quantities: z.record(z.string(), z.number().int().min(1).max(50)),
      note: z.string().trim().max(500).default(''),
    }), req.body);
    if (!validId(input.userId) || !validId(input.eventId)) throw httpError(400, 'Choose a valid user and event.');
    const [user, event] = await Promise.all([User.findById(input.userId), Event.findById(input.eventId)]);
    if (!user) throw httpError(404, 'User not found.');
    if (!event) throw httpError(404, 'Event not found.');
    const lines = [];
    let subtotal = 0;
    for (const [categoryId, quantity] of Object.entries(input.quantities)) {
      const category = event.ticketCategories.find((ticket) => ticket.id === categoryId);
      if (!category) throw httpError(400, 'One or more ticket categories are invalid.');
      if (quantity > category.remaining) throw httpError(409, `Only ${category.remaining} ${category.name} tickets remain.`);
      lines.push({ categoryId, name: category.name, price: category.price, quantity });
      subtotal += category.price * quantity;
    }
    if (!lines.length) throw httpError(400, 'Select at least one ticket.');
    const order = { lines, subtotal, discount: subtotal, taxesAndFees: 0, total: 0 };
    const booking = await reserveInventoryAndCreateBooking({
      userId: user._id,
      event,
      order,
      issuedByAdmin: true,
      adminNote: input.note,
    });
    const count = lines.reduce((sum, line) => sum + line.quantity, 0);
    await audit(req, 'booking.comp', 'booking', booking.id, `Issued ${count} complimentary ticket(s) for "${event.title}" to ${user.email}`);
    const populated = await Booking.findById(booking._id)
      .populate('userId', 'name email avatarUrl')
      .populate('eventId', 'title startsAt venue imageUrl')
      .lean();
    return res.status(201).json({ booking: serializeBooking(populated) });
  });

  router.patch('/bookings/:id', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'Booking not found.');
    const input = parse(z.object({ adminNote: z.string().trim().max(500) }), req.body);
    const booking = await Booking.findByIdAndUpdate(req.params.id, { adminNote: input.adminNote }, { new: true })
      .populate('userId', 'name email avatarUrl')
      .populate('eventId', 'title startsAt venue imageUrl')
      .lean();
    if (!booking) throw httpError(404, 'Booking not found.');
    await audit(req, 'booking.note', 'booking', booking._id, 'Updated admin note');
    return res.json({ booking: serializeBooking(booking) });
  });

  router.delete('/bookings/:id', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'Booking not found.');
    const booking = await Booking.findById(req.params.id);
    if (!booking) throw httpError(404, 'Booking not found.');
    if (booking.status !== 'Cancelled') throw httpError(409, 'Cancel the booking before deleting its record.');
    await booking.deleteOne();
    await audit(req, 'booking.delete', 'booking', booking.id, `Deleted cancelled booking record ${booking.id}`);
    return res.status(204).end();
  });

  // -------------------------------------------------------------------------
  // Promo codes
  // -------------------------------------------------------------------------

  const promoSchema = z.object({
    code: z.string().trim().min(3).max(40).regex(/^[A-Za-z0-9_-]+$/, 'Use letters, numbers, - or _ only'),
    description: z.string().trim().max(200).default(''),
    type: z.enum(['flat', 'percent']),
    value: z.number().finite().positive().max(1000000),
    maxDiscount: z.number().finite().min(0).max(1000000).default(0),
    minSubtotal: z.number().finite().min(0).max(10000000).default(0),
    maxUses: z.number().int().min(0).max(10000000).default(0),
    active: z.boolean().default(true),
    expiresAt: z.coerce.date().nullable().optional(),
  }).refine((promo) => promo.type !== 'percent' || promo.value <= 100, {
    message: 'A percentage discount cannot exceed 100',
    path: ['value'],
  });

  function serializePromo(promo) {
    const { _id, __v, ...rest } = promo;
    return { ...rest, id: String(_id) };
  }

  router.get('/promos', async (_req, res) => {
    const promos = await Promo.find().sort({ createdAt: -1 }).lean();
    const revenue = await Booking.aggregate([
      { $match: { promoCode: { $ne: '' }, status: { $ne: 'Cancelled' } } },
      { $group: { _id: '$promoCode', discount: { $sum: '$discount' }, revenue: { $sum: '$totalPaid' } } },
    ]);
    const byCode = new Map(revenue.map((row) => [row._id, row]));
    return res.json({
      promos: promos.map((promo) => ({
        ...serializePromo(promo),
        totalDiscount: Math.round((byCode.get(promo.code)?.discount || 0) * 100) / 100,
        revenue: Math.round((byCode.get(promo.code)?.revenue || 0) * 100) / 100,
      })),
    });
  });

  router.post('/promos', async (req, res) => {
    const input = parse(promoSchema, req.body);
    input.code = input.code.toUpperCase();
    if (await Promo.exists({ code: input.code })) throw httpError(409, 'A promo code with this name already exists.');
    const promo = await Promo.create(input);
    await audit(req, 'promo.create', 'promo', promo.id, `Created promo ${promo.code}`);
    return res.status(201).json({ promo: serializePromo(promo.toObject()) });
  });

  router.patch('/promos/:id', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'Promo code not found.');
    const input = parse(promoSchema, req.body);
    input.code = input.code.toUpperCase();
    if (await Promo.exists({ code: input.code, _id: { $ne: req.params.id } })) {
      throw httpError(409, 'A promo code with this name already exists.');
    }
    const promo = await Promo.findByIdAndUpdate(req.params.id, { ...input, expiresAt: input.expiresAt || null }, { new: true }).lean();
    if (!promo) throw httpError(404, 'Promo code not found.');
    await audit(req, 'promo.update', 'promo', promo._id, `Updated promo ${promo.code}`);
    return res.json({ promo: serializePromo(promo) });
  });

  router.delete('/promos/:id', async (req, res) => {
    if (!validId(req.params.id)) throw httpError(404, 'Promo code not found.');
    const promo = await Promo.findByIdAndDelete(req.params.id).lean();
    if (!promo) throw httpError(404, 'Promo code not found.');
    await audit(req, 'promo.delete', 'promo', promo._id, `Deleted promo ${promo.code}`);
    return res.status(204).end();
  });

  // -------------------------------------------------------------------------
  // Platform settings, system status, audit log
  // -------------------------------------------------------------------------

  router.get('/settings', (_req, res) => res.json({ settings: { ...settings } }));

  router.patch('/settings', async (req, res) => {
    const input = parse(z.object({
      categories: z.array(z.string().trim().min(2).max(40)).min(1).max(40).optional(),
      salesPaused: z.boolean().optional(),
      registrationsOpen: z.boolean().optional(),
    }), req.body);
    if (input.categories) input.categories = [...new Set(input.categories)];
    const updated = await saveSettings(input);
    await audit(req, 'settings.update', 'settings', '', Object.entries(input)
      .map(([key, value]) => `${key}=${Array.isArray(value) ? value.join('/') : value}`).join(', '));
    return res.json({ settings: updated });
  });

  router.get('/system', async (_req, res) => {
    const stripe = getStripe();
    const key = process.env.STRIPE_SECRET_KEY?.trim() || '';
    const [users, events, bookings, promos, logs] = await Promise.all([
      User.estimatedDocumentCount(),
      Event.estimatedDocumentCount(),
      Booking.estimatedDocumentCount(),
      Promo.estimatedDocumentCount(),
      AdminLog.estimatedDocumentCount(),
    ]);
    return res.json({
      database: {
        connected: mongoose.connection.readyState === 1,
        name: mongoose.connection.name,
        counts: { users, events, bookings, promos, logs },
      },
      stripe: { configured: Boolean(stripe), mode: key.startsWith('sk_live_') ? 'live' : key ? 'test' : 'off', webhook: isWebhookConfigured() },
      cloudinary: { configured: isCloudinaryConfigured },
      server: { node: process.version, startedAt, uptimeSeconds: Math.round(process.uptime()) },
    });
  });

  router.get('/logs', async (req, res) => {
    const filter = {};
    if (req.query.action) filter.action = new RegExp(`^${escapeRegex(String(req.query.action))}`);
    const q = String(req.query.q || '').trim();
    if (q) {
      const pattern = new RegExp(escapeRegex(q), 'i');
      filter.$or = [{ summary: pattern }, { adminName: pattern }];
    }
    const pageInfo = paging(req, 40);
    const [logs, total] = await Promise.all([
      AdminLog.find(filter).sort({ createdAt: -1 }).skip(pageInfo.skip).limit(pageInfo.limit).lean(),
      AdminLog.countDocuments(filter),
    ]);
    return res.json(pageResult('logs', logs.map((log) => ({
      id: String(log._id),
      adminName: log.adminName,
      action: log.action,
      targetType: log.targetType,
      targetId: log.targetId,
      summary: log.summary,
      createdAt: log.createdAt,
    })), total, pageInfo));
  });

  app.use('/api/admin', router);
}

module.exports = { registerAdminRoutes };
