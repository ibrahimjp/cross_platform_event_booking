// Legacy built-in codes; also seeded into the Promo collection so admins can manage them.
const PROMO_CODES = ['EVEAI200', 'EVENTBOOK20'];
const DEFAULT_PROMOS = PROMO_CODES.map((code) => ({
  code,
  description: 'Flat ₹200 off',
  type: 'flat',
  value: 200,
}));

function normalizePromoCode(promoCode) {
  return String(promoCode || '').trim().toUpperCase();
}

function promoDiscount(promo, subtotal) {
  if (!promo || subtotal <= 0 || subtotal < (promo.minSubtotal || 0)) return 0;
  let discount = promo.type === 'percent'
    ? Math.round(subtotal * Math.min(promo.value, 100)) / 100
    : promo.value;
  if (promo.maxDiscount > 0) discount = Math.min(discount, promo.maxDiscount);
  return Math.round(Math.min(discount, subtotal) * 100) / 100;
}

// `promo` is the resolved promo record (or null when the code is unknown). When it is
// omitted entirely, the legacy built-in codes are used.
function calculateOrder(event, quantities, promoCode, promo) {
  if (!quantities || typeof quantities !== 'object' || Array.isArray(quantities)) {
    throw new Error('Select at least one valid ticket.');
  }

  const lines = [];
  let subtotal = 0;
  for (const [categoryId, quantity] of Object.entries(quantities)) {
    const category = event.ticketCategories.find((ticket) => ticket.id === categoryId);
    if (!category || !Number.isInteger(quantity) || quantity < 1 || quantity > 10) {
      throw new Error('One or more ticket selections are invalid.');
    }
    if (quantity > category.remaining) {
      throw new Error(`Only ${category.remaining} ${category.name} tickets remain.`);
    }
    subtotal += category.price * quantity;
    lines.push({ categoryId, name: category.name, price: category.price, quantity });
  }

  if (lines.length === 0) {
    throw new Error('Select at least one ticket.');
  }

  const discount = promo === undefined
    ? (PROMO_CODES.includes(normalizePromoCode(promoCode)) ? Math.min(200, subtotal) : 0)
    : promoDiscount(promo, subtotal);
  const taxesAndFees = Math.round((subtotal - discount) * 0.18 * 100) / 100;
  const total = Math.round((subtotal - discount + taxesAndFees) * 100) / 100;
  if (total > 999999.99) {
    throw new Error('The order total exceeds the supported payment limit.');
  }
  return { lines, subtotal, discount, taxesAndFees, total };
}

module.exports = { calculateOrder, normalizePromoCode, promoDiscount, PROMO_CODES, DEFAULT_PROMOS };
