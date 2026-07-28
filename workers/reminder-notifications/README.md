# reminder-notifications

Cloudflare Worker that sends "your event starts soon" push notifications — the piece
explicitly deferred when FCM was first wired into the app (see
[`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md)).

Runs on a cron (every 15 minutes), calls `get_pending_reminders()` in Supabase
(events starting within the next hour, RSVP'd "going", not yet reminded — see
`supabase/migrations/0007_reminder_tracking.sql`), sends one FCM push per device
token via the FCM HTTP v1 API, then calls `mark_reminder_sent()` so the same event
doesn't get reminded twice.

## Deploying

Already deployed at `evento-reminder-notifications` on Cloudflare, cron active. To
redeploy after a code change:

```
cd workers/reminder-notifications
npm install
npx wrangler deploy
```

## Secrets

Three secrets, set via `wrangler secret put <NAME>` (never in `wrangler.jsonc`):

| Secret | Status | Where it comes from |
|---|---|---|
| `SUPABASE_URL` | ✅ set | Your Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | ✅ set | Supabase dashboard → Project Settings → API → the `secret`-type key (bypasses RLS — this job reads across every user's data on purpose, see the migration file) |
| `FIREBASE_SERVICE_ACCOUNT` | ⬜ **needed** | See below |

### Getting the Firebase service-account key

This is a **different credential** from `google-services.json` (that one configures
the client SDK; this one authorizes server-to-server sends) — download it once:

1. Firebase console → the `events-platform-pk` project → ⚙️ **Project Settings** →
   **Service Accounts** tab
2. Click **"Generate new private key"** → confirm → a JSON file downloads
3. Set it as a secret directly from that file (don't paste it manually — avoids any
   copy/paste corruption of the private key's newlines):
   ```
   npx wrangler secret put FIREBASE_SERVICE_ACCOUNT < path\to\the-downloaded-file.json
   ```

Once that's set, the next cron run (within 15 minutes) will actually be able to send.

## Manual testing

```
npm run dev              # local dev server with --test-scheduled
curl http://localhost:8787/__scheduled

# or hit the deployed Worker directly (also runs the sweep, not just a health check):
curl https://evento-reminder-notifications.bozo35811.workers.dev

wrangler tail             # watch live logs from the deployed Worker
```
