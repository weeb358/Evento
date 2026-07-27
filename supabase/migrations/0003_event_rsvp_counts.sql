-- Public "N going" / "N interested" counters need to be visible to every
-- browsing user, but 0002's event_rsvps SELECT policy intentionally
-- restricts row-level visibility (organizer / own row / premium-with-own-
-- rsvp) — that's the Premium "who else RSVP'd" gate. This function exposes
-- only the aggregate counts, never the underlying rows, so it's safe to run
-- as security definer for anyone.

create or replace function public.get_event_rsvp_counts(p_event_id uuid)
returns table (going_count bigint, interested_count bigint)
language sql
stable
security definer set search_path = public
as $$
  select
    count(*) filter (where status = 'going') as going_count,
    count(*) filter (where status = 'interested') as interested_count
  from public.event_rsvps
  where event_id = p_event_id;
$$;

grant execute on function public.get_event_rsvp_counts(uuid) to authenticated, anon;
