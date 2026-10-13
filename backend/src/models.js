const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 100 },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    phone: { type: String, default: '', trim: true, maxlength: 30 },
    city: { type: String, default: '', trim: true, maxlength: 60 },
    avatarUrl: { type: String, default: '' },
    avatarPublicId: { type: String, default: '' },
    wishlist: { type: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Event' }], default: [] },
    preferredCategories: { type: [String], default: ['Music', 'Festival'] },
    notificationsEnabled: { type: Boolean, default: true },
    stripeCustomerId: { type: String, default: null },
    role: { type: String, enum: ['user', 'admin'], default: 'user', index: true },
    isBlocked: { type: Boolean, default: false },
    blockedReason: { type: String, default: '', maxlength: 300 },
    tokenVersion: { type: Number, default: 0 },
    lastLoginAt: { type: Date, default: null },
  },
  { timestamps: true },
);

const ticketSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    name: { type: String, required: true, trim: true },
    price: { type: Number, required: true, min: 0 },
    description: { type: String, default: '' },
    remaining: { type: Number, required: true, min: 0 },
  },
  { _id: false },
);

const eventSchema = new mongoose.Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 120 },
    category: { type: String, required: true, trim: true, maxlength: 40 },
    startsAt: { type: Date, required: true, index: true },
    endsAt: { type: Date, required: true },
    time: { type: String, required: true, trim: true, maxlength: 60 },
    location: { type: String, required: true, trim: true, maxlength: 100 },
    venue: { type: String, required: true, trim: true, maxlength: 160 },
    priceStarting: { type: Number, required: true, min: 0 },
    imageUrl: { type: String, default: '' },
    imagePublicId: { type: String, default: '' },
    description: { type: String, required: true, trim: true, maxlength: 5000 },
    lineup: { type: [String], default: [] },
    ticketCategories: { type: [ticketSchema], default: [] },
    matchPercentage: { type: Number, default: 90, min: 0, max: 100 },
    aiReason: { type: String, default: '', maxlength: 300 },
    isGarbaSpecial: { type: Boolean, default: false },
    isTrending: { type: Boolean, default: false },
    attendeeCount: { type: Number, default: 0, min: 0 },
    ticketsSold: { type: Number, default: 0, min: 0 },
    hostId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    isHidden: { type: Boolean, default: false },
  },
  { timestamps: true },
);

const bookingLineSchema = new mongoose.Schema(
  {
    categoryId: { type: String, required: true },
    name: { type: String, default: '' },
    price: { type: Number, default: 0 },
    quantity: { type: Number, required: true, min: 1 },
  },
  { _id: false },
);

const bookingSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'Event', required: true, index: true },
    paymentIntentId: { type: String, unique: true, sparse: true },
    checkoutSessionId: { type: String, unique: true, sparse: true },
    tickets: { type: [bookingLineSchema], required: true },
    subtotal: { type: Number, required: true },
    discount: { type: Number, required: true, default: 0 },
    taxesAndFees: { type: Number, required: true },
    totalPaid: { type: Number, required: true },
    status: { type: String, enum: ['Confirmed', 'Free', 'Cancelled'], required: true },
    cancelledAt: { type: Date, default: null },
    cancelledBy: { type: String, enum: ['user', 'admin', null], default: null },
    cancelReason: { type: String, default: '', maxlength: 300 },
    refunded: { type: Boolean, default: false },
    promoCode: { type: String, default: '' },
    issuedByAdmin: { type: Boolean, default: false },
    testPayment: { type: Boolean, default: false },
    adminNote: { type: String, default: '', maxlength: 500 },
  },
  { timestamps: true },
);

const promoSchema = new mongoose.Schema(
  {
    code: { type: String, required: true, unique: true, uppercase: true, trim: true, maxlength: 40 },
    description: { type: String, default: '', maxlength: 200 },
    type: { type: String, enum: ['flat', 'percent'], default: 'flat' },
    value: { type: Number, required: true, min: 0 },
    maxDiscount: { type: Number, default: 0, min: 0 },
    minSubtotal: { type: Number, default: 0, min: 0 },
    maxUses: { type: Number, default: 0, min: 0 },
    uses: { type: Number, default: 0, min: 0 },
    active: { type: Boolean, default: true },
    expiresAt: { type: Date, default: null },
  },
  { timestamps: true },
);

const settingSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true },
    value: { type: mongoose.Schema.Types.Mixed },
  },
  { timestamps: true },
);

const adminLogSchema = new mongoose.Schema(
  {
    adminId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    adminName: { type: String, default: '' },
    action: { type: String, required: true, index: true },
    targetType: { type: String, default: '' },
    targetId: { type: String, default: '' },
    summary: { type: String, default: '' },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

module.exports = {
  User: mongoose.models.User || mongoose.model('User', userSchema),
  Event: mongoose.models.Event || mongoose.model('Event', eventSchema),
  Booking: mongoose.models.Booking || mongoose.model('Booking', bookingSchema),
  Promo: mongoose.models.Promo || mongoose.model('Promo', promoSchema),
  Setting: mongoose.models.Setting || mongoose.model('Setting', settingSchema),
  AdminLog: mongoose.models.AdminLog || mongoose.model('AdminLog', adminLogSchema),
};
