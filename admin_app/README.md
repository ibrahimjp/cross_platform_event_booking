# EventBook Admin

A separate Flutter app for running the whole EventBook platform. It shares no code with `eventbook_app`; it talks only to the backend's `/api/admin/*` routes, and only accounts with the `admin` role can sign in.

## Run it

1. Start the backend (`cd ../backend && npm start`).
2. Create an admin login once:

   ```bash
   cd ../backend && npm run create-admin -- admin@eventbook.ai "choose-a-strong-password" "Your Name"
   ```

   Alternatively, set `ADMIN_EMAIL` and `ADMIN_PASSWORD` in `backend/.env` and the server creates the account on startup.

3. Run the admin app:

   ```bash
   flutter pub get
   flutter run -d chrome
   ```

The app defaults to `http://127.0.0.1:3000` (`http://10.0.2.2:3000` on the Android emulator). Change it on the sign-in screen under **Server**, or at build time with `--dart-define=API_BASE_URL=http://192.168.1.9:3000`.

## What admins can do

| Area | Capabilities |
| --- | --- |
| Dashboard | Revenue, tickets, users and cancellations; 30-day revenue/bookings chart; revenue by category; top events; low-inventory alerts; latest bookings and sign-ups; one-tap platform switches |
| Events | Search, filter (upcoming, past, hidden, trending, category) and sort every event from every host. Create, fully edit (dates, venue, ticket tiers, prices, inventory, image upload or URL, lineup), reassign host, hide/publish, mark trending or Garba special, duplicate as a hidden draft, delete (optionally cancelling and refunding all bookings) |
| Bookings | Search by customer, email, event, promo code, booking or Stripe payment ID; filter by paid/free/comp/cancelled/refunded. Inspect line items, totals and live Stripe payment status. Cancel with or without a Stripe refund, add internal notes, delete cancelled records, issue complimentary tickets to any user |
| Users | Search, filter (customers, admins, suspended) and sort. View spend, bookings, hosted events and wishlist. Create accounts, edit profiles, reset passwords, sign out of all devices, promote or demote admins, suspend or reinstate (with a reason), delete accounts (optionally cancelling and refunding their bookings and events) |
| Promo codes | Create flat or percentage codes with caps, minimum order, usage limits and expiry; pause, edit or delete; see uses, total discount and revenue per code |
| Activity log | An audit trail of every admin action, searchable and filterable |
| Platform & settings | Pause all ticket sales, close new sign-ups, manage event categories, check database/Stripe/Cloudinary/server status, change your own password |

## Safety rails

- Admin tokens are separate from customer tokens (`scope: admin`, 12-hour expiry), and the role is re-checked on every request.
- Suspending, demoting or resetting a password signs that user out everywhere immediately.
- You cannot suspend, demote or delete yourself, and the last active admin cannot be removed.
- Refund failures leave the booking untouched, so retrying never double-refunds.
