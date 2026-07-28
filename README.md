# Events Platform (Pakistan) — Monorepo

Events discovery app for Pakistan with a Couchsurfing-style hosting module, plus a
free/Premium subscription tier. Two clients share one Supabase backend so their data
is always in sync.

## Layout

| Path         | What it is                                                              |
|--------------|--------------------------------------------------------------------------|
| `app/`       | Flutter mobile app (Android first). Auth, events, premium, hosting.     |
| `website/`   | Next.js web app — public browsing, auth, premium, `/admin` moderation.  |
| `supabase/`  | Single source of truth backend: SQL migrations, RLS policies, storage.  |
| `workers/`   | Cloudflare Workers — currently just the FCM reminder-sender cron job.   |
| `docs/`      | Roadmap, architecture decisions, shared design system tokens.           |

Start with [`docs/ROADMAP.md`](docs/ROADMAP.md) for what's built vs. planned, and
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for why the stack looks the way it does.

## Status

Events, Premium, and Hosting are fully built and working against a real Supabase
project (schema + RLS applied, both clients verified end-to-end). Auth: email/
password works out of the box; **phone OTP needs an SMS provider connected**
(Authentication → Providers → Phone in the Supabase dashboard — Twilio is the usual
choice) before it'll send codes. Push notifications are fully wired — app-side
receiving plus a deployed Cloudflare Worker that sends "starting soon" reminders —
though the Worker needs one more secret (a Firebase service-account key) before it can
actually send; see `workers/reminder-notifications/README.md`.

## Getting started

### Backend (Supabase)

```
cd supabase
supabase start          # local dev stack
supabase db reset       # applies migrations/ in order (0001-0007)
```

Copy `supabase/.env.example` to `supabase/.env` and fill in project values once you've
created a hosted Supabase project (`supabase link`). To grant yourself admin access
(for `/admin/login` on the website), set `role = 'admin'` on your row in
`public.users` from the Supabase dashboard's table editor — see
`docs/ARCHITECTURE.md`.

### Mobile app

```
cd app
cp .env.example .env    # fill in SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY / WEBSITE_URL
flutter pub get
flutter run
```

**Push notifications (FCM)**: place your Firebase project's `google-services.json` at
`app/android/app/google-services.json` (gitignored — it's a per-project credential,
not committed). The Android app's package is `com.eventsplatform.events_app`; the
Firebase Android app you register must use that exact package name or the build fails
with "No matching client found." Token registration and foreground/background message
handling are wired up; the actual sender job lives in `workers/reminder-notifications`
— see that folder's README for the one remaining setup step.

### Website

```
cd website
cp .env.example .env.local   # fill in NEXT_PUBLIC_SUPABASE_URL / PUBLISHABLE_KEY
npm install
npm run dev
```

### Reminder notifications (Cloudflare Worker)

Already deployed and running on a 15-minute cron. See
[`workers/reminder-notifications/README.md`](workers/reminder-notifications/README.md)
for secrets/redeploy instructions.
