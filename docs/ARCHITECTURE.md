# Architecture decisions

## Auth: phone OTP + email/password, and the 3-role model

Phone OTP (Phase 1) and email/password (added later, on explicit request) are two
independent ways into the same Supabase Auth identity — same `public.users` row, same
session, same everything downstream. A few decisions worth knowing about:

- **`public.users.role`** is `user` / `event_planner` / `admin` (see
  `0005_roles_and_email_auth.sql`), stored as a real column read via
  `current_user_role()`/`is_admin()`, not JWT `user_metadata`. JWT claims only refresh
  when the token does, which would leave a stale window after a role change; a column
  read on every check doesn't have that problem, at the cost of one extra query (fine
  at this scale).
- **`event_planner` is self-service, `admin` never is.** A user can request
  `event_planner` for themselves at signup (`requested_role` in the signup payload) or
  later from their profile — `request_event_planner_role()` only ever moves
  `'user' -> 'event_planner'`, and there's no client path that can reach `'admin'`.
  Becoming an admin is an out-of-band action (Supabase dashboard/Admin API) — see
  "Bootstrapping an admin/moderator account" below, which now governs the `admin` role
  specifically (the `moderator` value never really existed as a role and was dropped).
- **Event creation requires `event_planner` or `admin`** (`events_insert_own` in
  0005) — a change from Phase 1, where any signed-in user could organize. Editing/
  deleting an event stays organizer-only regardless of current role, so a later role
  change doesn't strand existing events.
- **Email login can't distinguish "no account" from "wrong password."** Supabase's
  `signInWithPassword` returns the identical error for both cases by design, to stop a
  login form from being usable to enumerate registered emails. The "sign in failed —
  new here? Sign up" prompt on both clients is built around that constraint rather
  than trying to detect "no account" specifically (which isn't detectable from the
  client without reintroducing the enumeration hole).
- **Password reset always completes on the website**, even when requested from the
  app (`WEBSITE_URL` in `app/.env`, used as `resetPasswordForEmail`'s `redirectTo`).
  Handling the reset link natively in the Flutter app would need a custom URL scheme,
  a deep-link package (`app_links`), and Supabase redirect-URL allowlist entries — real
  work for a flow used rarely per user. The website already has the reset-password
  page building this once there was reasonable, so the app just sends users there.
- **`/admin/login` is a separate, dedicated flow** from consumer sign-in — a plain
  email+password form (`app/admin/login/page.tsx`, outside the
  `app/admin/(dashboard)/` route group so it doesn't render the admin sidebar) that
  checks `role === 'admin'` after signing in and immediately signs back out if not.
  `middleware.ts`/`proxy.ts` independently re-checks the same role on every `/admin/*`
  request from the DB (not the login flow's one-time check), so losing admin access
  takes effect on the next request either way.

## Push notifications (FCM) — both halves now built

App-side registration/receiving: requesting notification permission, getting/
refreshing the FCM token, storing it in `public.push_tokens` (0006_push_tokens.sql,
RLS-scoped to its owner), and displaying foreground messages via a SnackBar
(`main.dart`'s `_ForegroundNotificationBanner` — FCM only puts up a system tray
notification automatically when the app is backgrounded/terminated).

The sending half is `workers/reminder-notifications` — a **Cloudflare Worker**
(not a Supabase Edge Function, per explicit direction) on a 15-minute cron:

- `get_pending_reminders()`/`mark_reminder_sent()` (0007_reminder_tracking.sql) are
  `SECURITY DEFINER` functions with no grant to `authenticated`/`anon` — they're only
  reachable via the Supabase **service role** key, which the Worker holds as a secret
  and which bypasses RLS entirely. That's deliberate: this job reads every user's
  RSVPs and device tokens at once, which no regular authenticated session should ever
  be able to do.
- FCM auth uses the **HTTP v1 API**, not the deprecated legacy server-key API — the
  Worker self-signs a JWT with a Firebase service-account private key (Web Crypto
  `RSASSA-PKCS1-v1_5`/SHA-256, no Node `googleapis` package available in the Workers
  runtime) and exchanges it for a Google OAuth2 access token per invocation.
- `reminder_sent_at` is set once per **event** after all of that event's pushes are
  attempted, not per token — so one stale/invalid device token failing doesn't cause
  a resend storm to the rest of that event's attendees on the next sweep.
- Two credentials are required, and they're different things: `google-services.json`
  configures the client SDK (already in `app/`); the service-account JSON
  (Project Settings → Service Accounts → Generate new private key) authorizes
  server-to-server sends and is what the Worker needs. See
  `workers/reminder-notifications/README.md` for the exact setup steps.

**Setup**: this app's Android package is `com.eventsplatform.events_app` — the
Firebase Android app must be registered with that exact package name, or the Gradle
build fails with "No matching client found for package name." Place the downloaded
`google-services.json` at `app/android/app/google-services.json` (gitignored — a
per-project credential like the Supabase keys, not committed; every developer/
environment provides their own). No `firebase_options.dart`/`flutterfire configure`
step is needed since the app is Android-only for now — `Firebase.initializeApp()`
with no explicit options reads configuration from `google-services.json` via the
Gradle plugin automatically.

## Why Supabase instead of a custom NestJS/Prisma backend

Two specs were given for this product: a lean phased Events+Hosting app (Flutter +
Supabase + Riverpod) and a much larger "everything platform" (Flutter + NestJS/Prisma +
Next.js admin, communities, real-time chat, AI, ticketing). Both can't be built at once
without producing an unfinished, untestable pile of code.

Decision: **start on Supabase**, add a custom backend service (NestJS or otherwise)
**only when something genuinely needs to run off the client** — payment webhooks,
ID/face verification review, admin actions that must not be forgeable by a client with
a valid JWT. This mirrors what the lean spec itself asked for, and it means:

- One Postgres schema is the single source of truth for both `app/` and `website/` —
  they're different clients of the same backend, not two systems to keep in sync.
- Row Level Security policies are the permission system, not hand-rolled middleware.
  Fewer places for an authorization bug to hide.
- Auth, storage, and realtime are already solved; no custom API surface to design,
  version, and secure before a single feature screen exists.

Revisit this when: payments need server-side webhook handling (JazzCash/Easypaisa),
verification review needs a human-in-the-loop workflow with audit logs, or query
patterns emerge that RLS + Postgres full-text search genuinely can't express
efficiently (at which point add a narrow service for *that* concern, not a full
API rewrite).

## Why `website/` exists, and what it does vs. what `app/` does

The mega-spec's Next.js admin panel is real value, but a full admin panel before any
mobile feature worked would have inverted priorities. `website/` stayed scoped to a
deliberately smaller slice than `app/`, even once Phases 1–3 were built out fully:

- **Public, SEO-indexable browsing** — events and hosting listings, read-only. Events
  discovery apps live and die by shareable links; a WhatsApp-shared event link should
  open a real page, not require an app install.
- **Phone-OTP auth**, mainly so a moderator/admin has a session to act with — the same
  Supabase Auth flow as the app, not a separate identity system.
- **Premium upgrade** — functional (same stubbed-payment insert as the app), since a
  web checkout is a real, common entry point even for a mobile-first product.
- **`/admin`** — reports moderation and host verification, working end-to-end.

What it deliberately does **not** do: create/edit events, RSVP, bookmark, or send
booking requests. Those stay app-only. Duplicating every write path across two clients
buys little (this is a mobile-first product) and doubles the surface area to keep
correct. If a future need (e.g. organizer web dashboard) justifies more write paths on
web, add them then rather than pre-building them speculatively.

## Pragmatic Clean Architecture (Flutter)

`app/` uses a two-layer split per feature — `data/` (models + a repository class
talking to Supabase) and `presentation/` (Riverpod providers/controllers + screens) —
rather than a full four-layer Clean Architecture with abstract repository interfaces
and dedicated use-case classes per action. Reasoning: this app has exactly one backend
(Supabase) for its lifetime horizon; the main value of a repository *interface* is
swappable implementations, which don't exist here. `presentation/` still never touches
`data/`'s Supabase calls directly — it goes through the repository class — so the
boundary that actually matters (screens don't know about Postgrest/Supabase) is
intact. Cross-cutting concerns used by 3+ features (`users`, `reviews`, `saved`,
`reports`) live in `core/` rather than being owned by one feature and imported
sideways.

`core/utils/result.dart` gives every repository method a `Result<T>` return instead of
throwing — `AppFailure` subtypes carry a user-facing message, translated once in
`AppFailure.fromException`, so no screen ever pattern-matches on `PostgrestException`.

## A real RLS trap worth knowing about before touching verification/tier logic

While building host verification, a genuine bug surfaced and is worth documenting so
it isn't reintroduced: **Postgres combines multiple permissive RLS policies for the
same command with OR, and column-level privileges are role-wide, not scoped to a
specific policy.** Concretely: `host_profiles` already has an owner policy
(`id = auth.uid()`) with no column restriction. Adding a *second* "admin can update"
policy and granting the `verification_status` column to `authenticated` does **not**
mean only admins can set it — an owner's update still satisfies the *owner* policy
regardless of which policy the column grant was "meant" for, so the owner could
self-verify. Same trap existed for `users.tier` vs. Premium status, and again for
`users.role` when the 3-role model was added (0005) — `users_update_own`'s column
grant deliberately never includes `role`, exactly like `tier`/`is_verified`.

The fix used throughout `0002_premium_hosting.sql`, `0004_admin_rls.sql`, and
`0005_roles_and_email_auth.sql`: privileged column writes (`tier`, `is_verified`,
`verification_status`, `role`) go through `SECURITY DEFINER` functions that check
authorization in code (`is_admin()`, or "this must be the caller's own subscription"
or "this may only ever set 'event_planner', never 'admin'") and are
never reachable via a plain column grant + RLS policy combination. Any new
privileged/derived column should follow the same pattern, not a fresh RLS policy.

## Bootstrapping an admin account

There's no self-serve UI to become an admin — deliberately, since that's not
something a client should be able to grant itself, and no other admin exists yet to
use `set_user_role()` (0005) the normal way. For the very first admin, set
`role = 'admin'` directly on their row in `public.users` via the Supabase dashboard's
SQL editor or table editor. Every admin after that can be promoted the same way, or
via `select set_user_role('<user-id>', 'admin')` run by an existing admin's session.

## Monetization notes (from the mega-spec's "Deliverables" ask)

- Premium subscription (already scoped) is the primary near-term lever.
- Organizer-side monetization (ticketing fees, boosted placement, promo tools) is
  larger revenue potential than consumer Premium alone in an events marketplace, but
  depends on payment gateway integration — sequence after Premium ships and payments
  are wired to a real gateway.
- Business accounts (Phase 4+) open a second revenue line (sponsored listings,
  verified business badges) independent of consumer subscriptions.
- Avoid stacking too many monetization surfaces before there's organic usage to
  monetize — Premium first, validate willingness to pay, then expand.

## Scalability / security risks flagged early

- **RLS correctness is the whole security model** — every new table needs an explicit
  policy; a missing policy silently defaults to "no access" (safe-but-broken) while a
  wrong policy can leak data (unsafe). Every migration touching a table must be
  reviewed for RLS coverage before merge.
- **Phone OTP abuse**: rate-limit OTP requests per phone number/IP at the Supabase Auth
  level from day one — SMS costs money and is a common abuse vector in growth-stage
  apps targeting Pakistan's SMS pricing.
- **Postgres full-text search** is fine at current scale; revisit only if p95 query
  latency or index size becomes a real, measured problem — don't pre-optimize into
  Elasticsearch.
- **Storage**: image upload policies must validate file type/size at the bucket policy
  level, not just client-side, before Phase 1 ships event cover images.

## Repo/tooling

Single repo, three independently-deployable units (`app/`, `website/`, `supabase/`)
that share one Postgres schema as their integration point. No shared code package
between Flutter and Next.js (different languages) — the shared contract is the
database schema + RLS policies + `docs/DESIGN_SYSTEM.md`, not a shared library.
