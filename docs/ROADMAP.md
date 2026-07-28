# Roadmap

Reconciles the lean phased spec with the larger platform vision (captured below so
it isn't lost, but not built). See `ARCHITECTURE.md` for the reasoning behind the
sequencing and for architectural decisions made along the way.

Phases 1–3 (Events, Premium, Hosting/Couchsurfing) were built together in one pass,
across both `app/` and `website/`, per an explicit request to build the full
architecture of both the events app and the hosting/Couchsurfing app before further
changes. Phase 4+ remains out of scope and stop-and-confirm applies again from here.

Auth was later expanded beyond original Phase 1 scope, on explicit request: email/
password as a second sign-in method alongside phone OTP (both clients), a working
forgot-password flow, and a real 3-role model (`user` / `event_planner` / `admin`)
replacing the informal admin/moderator flag — see "Auth: phone OTP + email/password,
and the 3-role model" in `ARCHITECTURE.md` for the details and the tradeoffs made.

## Phase 1 — Events, Standard tier — done

- [x] Step 1: monorepo scaffold — `app/`, `website/`, `supabase/`, theme/design system,
      Supabase wiring for both clients.
- [x] Step 2: Auth flow — phone OTP signup/login, profile creation (name, city, photo,
      bio) — `app/` and `website/`. Later expanded: email/password signup+login,
      forgot-password, and the 3-role model (see note above).
- [x] Step 3: Event schema CRUD — create event screen, event list (city/category/date
      filters), event detail screen.
- [x] Step 4: Map view of events (`flutter_map` + OSM), plus a tap-to-pick-location
      picker on the create/edit form.
- [x] Step 5: RSVP (going/interested) + save/bookmark (default collection).
- [x] Step 6: Push notifications (FCM) for RSVP'd event reminders — done. App-side
      token registration/receiving, plus a Cloudflare Worker
      (`workers/reminder-notifications`, cron every 15 min) that sends the actual
      "starting soon" pushes via the FCM HTTP v1 API. See `docs/ARCHITECTURE.md`.
- [x] Step 7: Reviews (post-event rating) + reporting (event/user, reason + submit).

## Phase 2 — Premium tier — done

- [x] Advanced filters (price range, distance radius via client-side haversine, "next
      N hours" time window) — gated behind `PremiumGate`/`isPremiumProvider`.
- [x] Unlimited saved-event collections/folders (Standard gets one auto-created
      default collection; Premium can create more).
- [x] Early RSVP access window on capacity-limited events (`events.premium_rsvp_opens_at`).
- [x] "Who else RSVP'd" visibility — gated at the RLS level, not just the UI (see
      `rsvps_select_own_organizer_or_premium_attendee` in `0002_premium_hosting.sql`).
- [x] Organizer tools: boosted/featured placement, basic analytics (view count, RSVP
      counts, views-by-day), recurring event templates (weekly recurrence, generates
      real `events` rows).
- [x] Single reusable `isPremium` gating pattern (`isPremiumProvider` + `PremiumGate`
      in the app; a plain `tier` read in the website) + paywall screen. Payment is
      stubbed — see `docs/ARCHITECTURE.md`.
- Ad-free browsing has no gate to build yet since there's no ad system in the app at
  all — this stays a no-op by design until ads exist.

## Phase 3 — Hosting / Couchsurfing module — done

- [x] Host profiles (headline/about/home type/max guests/house rules), photos,
      availability windows, browse/search by city, map-friendly lat/lng.
- [x] Booking request flow: guest requests dates → host accepts/declines from a
      dedicated inbox → guest sees status in "My trips".
- [x] Trust/verification: `host_profiles.verification_status`
      (unverified → pending → verified). A host can request review; only an
      admin/moderator can approve — enforced via column-level privilege revokes +
      `SECURITY DEFINER` RPCs, not just RLS row checks (see
      `0004_admin_rls.sql` — this took two iterations to get right, worth reading if
      touching verification logic).
- [x] Reviews reuse the existing polymorphic `reviews` table
      (`subject_type='user'`) exactly as planned when it was designed in Phase 1 —
      no migration needed to add host reviews.
- [x] Website: public host browse/detail pages (read-only — booking actions happen in
      the app) + an admin verification queue.

## Phase 4+ — From the "full platform" vision, explicitly future/unscoped

Nothing below this line is designed or built. Listed so the larger vision isn't lost.

- **Communities**: create/join/leave, posts, comments, likes, moderators, pinned
  posts, rules, events inside communities.
- **Messaging**: real-time chat, read receipts, typing indicators, image/location
  sharing (Socket.io or Supabase Realtime channels).
- **AI features**: search, recommendations, feed ranking, trip planner, event
  summary, spam detection, moderation assist, chat assistant.
- **Business accounts**: verified business profile, offers/coupons, sponsored
  listings, customer analytics — separate from Organizer.
- **Ticketing**: paid ticket sales, QR check-in, promo codes, attendance analytics,
  revenue dashboard, email/SMS campaigns.
- **Full admin panel**: expand `website/admin` beyond moderation into user/role
  management, audit logs, system-wide analytics.
- **Auth expansion**: email login, Google login, biometric login, device/session
  management (Phase 1 is phone OTP only, per the lean spec).
- **Infra swaps** if/when current choices hit real limits: Cloudflare R2 (if Supabase
  Storage costs/limits bite), Mapbox (if OSM tile rate limits or styling need bite),
  a dedicated NestJS service (once server-side-only logic exists — see
  `ARCHITECTURE.md`).
- Government ID / face verification, virus-scan hooks on uploads.
