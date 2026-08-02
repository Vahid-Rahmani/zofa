# zova

**zova** is an independent, from-scratch language-learning app. It preserves the
educational flow of a classic language app — onboarding, a lesson roadmap,
interactive books, progress tracking and a subscription paywall — but is a
completely new codebase with its own brand, theme, payment gateway and backend.

- **Framework:** Flutter (Dart)
- **Branding:** dark theme, primary blue `#3D7BFF`, white text
- **Payments:** Stripe (native payment sheet)
- **Backend & auth:** Supabase (email/password auth + Postgres), replacing any
  prior Firebase/supplier stack
- **Scope:** core MVP (onboarding, auth, courses + lessons, book reader,
  profile, subscription)

---

## Features

| Area        | What's included                                                        |
| ----------- | ---------------------------------------------------------------------- |
| Onboarding  | Intro pages, language/level/goal selection                             |
| Auth        | Email + password sign-up and sign-in, profile stored on your Supabase  |
| Courses     | Roadmap of levels → lessons, lock/unlock, XP, streak                   |
| Lessons     | 4 exercise types: flashcards, multiple choice, typing, matching pairs  |
| Books       | Interactive reader — tap any word to see its translation               |
| Profile     | XP, streak, words learned, avatar picker, premium status, sign out     |
| Paywall     | Monthly / yearly plans via the Stripe payment sheet                    |

## Project structure

```
lib/
  core/
    config/       env configuration (Supabase + Stripe keys)
    state/        AppController (auth + progress state)
    theme/        colours + dark theme
    widgets/      shared widgets (logo, gradient button)
  data/
    models/       AppUser, Course, Lesson, Exercise, Book, Progress, Plan
    repositories/ AuthRepository, ProgressRepository
    services/     RemoteApi (Supabase), LocalStore, StripeService, seed content
  features/
    splash/       branded launch screen
    onboarding/   preference collection
    auth/         sign in / register
    home/         bottom navigation shell
    courses/      roadmap + lesson player + exercises
    books/        library + reader
    profile/      stats + settings
    subscription/ paywall
supabase/
  schema.sql                       profiles + RLS + subscriptions
  functions/stripe-checkout/       Stripe edge function (create session/webhook)
test/                              unit + widget tests
```

## Getting started

1. Install the Flutter SDK (>= 3.44, verified against 3.44.8) and add it to your `PATH`.
2. Clone this project and run:

   ```sh
   flutter pub get
   flutter run            # pick your device / emulator
   ```

3. Run the checks:

   ```sh
   flutter analyze
   flutter test
   ```

> **Demo mode:** with no environment configured the app runs on a fully local
> backend (SharedPreferences) and simulates Stripe payments. Everything is
> testable offline; enabling Supabase/Stripe is purely additive.

## Connecting your Supabase backend

1. Create a project at [supabase.com](https://supabase.com) (your account).
2. Open **SQL Editor** and run the contents of `supabase/schema.sql`.
   This creates the `profiles` and `subscriptions` tables, enables Row Level
   Security and wires the sign-up trigger.
3. Copy your project credentials: **Settings → API**
   (URL + anon key).
4. Run the app with your values:

   ```sh
   flutter run \
     --dart-define=ZOVA_SUPABASE_URL=https://xxxx.supabase.co \
     --dart-define=ZOVA_SUPABASE_ANON_KEY=eyJhbGci...
   ```

Auth, profile storage and progress sync now happen on *your* Supabase project.
The previous developer's Firebase is fully removed — no Firebase dependency
exists anywhere in this codebase.

## Connecting Stripe

1. Create an account at [stripe.com](https://stripe.com).
2. Create two **Price** objects (one monthly, one yearly) for the plans shown
   on the paywall, and note their `price_...` IDs.
3. Deploy the edge function from `supabase/functions/stripe-checkout`:

   ```sh
   cd supabase/functions/stripe-checkout
   supabase functions deploy stripe-checkout --no-verify-jwt
   supabase secrets set STRIPE_SECRET_KEY=sk_test_xxx
   supabase secrets set STRIPE_PRICE_MONTHLY=price_xxx
   supabase secrets set STRIPE_PRICE_YEARLY=price_yyy
   ```

   Add a webhook in the Stripe dashboard for `invoice.payment_succeeded` /
   `customer.subscription.updated` pointing at
   `https://<project>.functions.supabase.co/stripe-checkout/webhook`, then set
   `STRIPE_WEBHOOK_SECRET`.
4. Run the app with the publishable key and function URL:

   ```sh
   flutter run \
     --dart-define=ZOVA_STRIPE_PUBLISHABLE_KEY=pk_test_xxx \
     --dart-define=ZOVA_STRIPE_SESSION_FUNCTION_URL=https://<project>.functions.supabase.co/stripe-checkout
   ```

The secret key lives only on the server; the app holds the publishable key.

## Branding

All traces of the original app — names, logos, icons and package IDs — have
been replaced with **zova** (`com.zova.app`). To change the app icon and splash
images, replace the launcher assets in `android/app/src/main/res/mipmap-*` and
`ios/Runner/Assets.xcassets`.

## License

Private project. All code and bundled educational content is original and
written from scratch for zova.
