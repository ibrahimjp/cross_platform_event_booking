# EventBook API

Node.js/Express API for account registration, hosted events, ticket inventory, bookings, and Stripe payments.

## Run locally

1. Start MongoDB (a plain local `mongod` is fine — no replica set needed).
2. Fill in `backend/.env` (see `.env.example`): MongoDB URI, `JWT_SECRET` (32+ chars), Stripe **test** secret key, and Cloudinary cloud name / API key / secret. The Cloudinary API key must have upload permission.
3. Install and run:

   ```bash
   npm install
   npm test
   npm start          # seeds demo users + the 6 sample events on first start
   npm run seed:reset # wipe events/bookings and re-seed with fresh dates
   ```

Demo accounts (password `password123`): `alex.morgan@eventbook.ai`, `host@eventbook.ai`.

On start the server prints the LAN address phones should use, e.g. `http://192.168.1.9:3000`.

### Payments

Checkout uses **Stripe Checkout** (hosted page) so it works on Android, Windows, macOS and web. The app opens the
payment page in the browser and polls `GET /api/payments/checkout/:sessionId`; the server verifies the amount with
Stripe before issuing tickets. Test card: `4242 4242 4242 4242`, any future expiry, any CVC. Promo codes:
`EVEAI200`, `EVENTBOOK20`. Cancelling a paid booking refunds it through Stripe.

### Images

Event cover images and profile photos are uploaded with multer (in memory) and stored on Cloudinary; replacing or
removing an image also deletes the old file from Cloudinary.

## Flutter client

```bash
cd ../eventbook_app
flutter run -d chrome                                   # web, talks to http://localhost:3000
flutter run -d windows                                  # Windows desktop (on a Windows PC)
flutter build windows                                   # -> build/windows/x64/runner/Release/eventbook_app.exe
flutter build apk --release --dart-define=API_BASE_URL=http://<your-LAN-IP>:3000
```

The server address can also be changed inside the app (server icon on the login screen, or Profile → Server Address).
Phones must be on the same Wi-Fi as the computer running the backend.

## Admin API

The separate admin app in `../admin_app` uses `/api/admin/*`. Create an admin login with:

```bash
npm run create-admin -- admin@eventbook.ai "choose-a-strong-password" "Your Name"
```

or set `ADMIN_EMAIL` / `ADMIN_PASSWORD` in `.env` so the server creates it on startup. Admin tokens are scoped separately from customer tokens. Suspended users get `403` on sign-in and on every authenticated call; suspending, demoting or resetting a password ends their sessions. Hidden events disappear from the public listing and cannot be booked. When sales are paused, checkout returns `503`; when sign-ups are closed, registration returns `403`. Promo codes live in MongoDB (the two original codes are seeded on first start), and every admin action is written to an audit log.

## Security notes

- Do not commit `.env`, MongoDB credentials, JWT signing secrets, Stripe secret keys, or real customer data.
- The API calculates ticket prices, taxes, and discounts from MongoDB, checks inventory, and verifies Stripe payment status before recording a paid booking.
- Stripe customer/payment method details are managed by Stripe. Card data is not stored by EventBook.
- Configure production HTTPS, a restricted CORS origin list, strong environment secrets, database network access, backups, and monitoring before deployment.
