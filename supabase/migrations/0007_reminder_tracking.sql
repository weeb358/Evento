-- Backs the reminder-sender Cloudflare Worker (workers/reminder-notifications)
-- — the piece explicitly deferred when push notifications were first built
-- (see docs/ARCHITECTURE.md, "Push notifications (FCM) — receiving half
-- only"). Both functions below are meant to be called with the Supabase
-- service role key, which bypasses RLS entirely — that's intentional and
-- documented on push_tokens in 0006: there's no broad-read RLS policy for
-- a sender job because it was always meant to run as service role, not as
-- a regular authenticated user.

alter table public.events add column reminder_sent_at timestamptz;

-- Returns one row per (event, RSVP'd user, device token) that needs a
-- "starting soon" reminder: status = 'going', event starts within the next
-- hour, and no reminder has been sent for this event yet. The Worker polls
-- on a schedule (see wrangler.jsonc), so "next hour" is intentionally wider
-- than the poll interval to tolerate a missed run.
create or replace function public.get_pending_reminders()
returns table (
  event_id uuid,
  event_title text,
  event_start_time timestamptz,
  user_id uuid,
  push_token text
)
language sql
stable
security definer set search_path = public
as $$
  select
    e.id as event_id,
    e.title as event_title,
    e.start_time as event_start_time,
    r.user_id,
    t.token as push_token
  from public.events e
  join public.event_rsvps r on r.event_id = e.id and r.status = 'going'
  join public.push_tokens t on t.user_id = r.user_id
  where e.reminder_sent_at is null
    and e.start_time between now() and now() + interval '1 hour'
    and e.status = 'published';
$$;

-- Not grantable to `authenticated`/`anon` — this reveals data across every
-- user's RSVPs and device tokens, which is exactly why it's service-role
-- only. Omitting the grant is the enforcement: only the service role (which
-- bypasses grants and RLS alike) can call it.

create or replace function public.mark_reminder_sent(target_event_id uuid)
returns void
language sql
security definer set search_path = public
as $$
  update public.events set reminder_sent_at = now() where id = target_event_id;
$$;
