# EventBook Flutter app

Event discovery, event hosting, account settings, ticket booking, and Stripe PaymentSheet checkout.

## Run with the backend

Start the API using the instructions in [the backend README](../backend/README.md). Android emulators automatically use `http://10.0.2.2:3000`; iOS simulators, desktop builds, and Flutter Web use `http://127.0.0.1:3000`. For a physical phone or a hosted API, supply its reachable address and Stripe publishable key at run time:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_replace_me
```

Use your computer's LAN address for a physical phone. The Stripe publishable key is public; **never** pass a Stripe secret key or MongoDB URI to Flutter. Keep those only in the backend's untracked `.env`.

Start the backend and configure its `.env` before signing in. Register an account in the app before using hosted events, bookings, or saved payment methods. Paid checkouts also require the matching Stripe test secret in the backend `.env` and publishable key at Flutter run time.

## Checks

From `eventbook_app`, run:

```powershell
flutter analyze
flutter test
```
