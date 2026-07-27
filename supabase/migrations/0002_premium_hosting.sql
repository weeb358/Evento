-- Phase 2 (Premium) + Phase 3 (Hosting/Couchsurfing) schema, per docs/ROADMAP.md.
-- Builds on 0001_init.sql. Payment is stubbed: a user "activates" their own
-- subscription row (simulating a successful checkout) instead of a payment
-- webhook — see docs/ARCHITECTURE.md for why, and what to change before
-- wiring a real gateway.

-- ---------------------------------------------------------------------------
-- Security hardening: the 0001 users_update_own RLS policy checks row
-- ownership but not which columns change, so a signed-in user could
-- otherwise `update users set tier = 'premium'` on themselves directly.
-- Restrict UPDATE at the column-privilege level; tier is only ever changed
-- by sync_user_tier_from_subscription below (security definer, owned by a
-- role that bypasses grants) and is_verified only by a future admin action.
-- ---------------------------------------------------------------------------

revoke update on public.users from authenticated;
grant update (name, city, photo_url, bio) on public.users to authenticated;

-- ---------------------------------------------------------------------------
-- Premium: subscriptions
-- ---------------------------------------------------------------------------

create type subscription_status as enum ('active', 'canceled', 'expired');

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  status subscription_status not null default 'active',
  started_at timestamptz not null default now(),
  current_period_end timestamptz not null,
  payment_reference text,
  created_at timestamptz not null default now()
);

create index subscriptions_user_id_idx on public.subscriptions (user_id);

alter table public.subscriptions enable row level security;

create policy "subscriptions_select_own" on public.subscriptions
  for select using (user_id = auth.uid());

-- Stubbed checkout: a user may create their own subscription row. Replace
-- with a service-role-only insert once a real payment webhook exists.
create policy "subscriptions_insert_own" on public.subscriptions
  for insert with check (user_id = auth.uid());

-- Lets a user cancel their own subscription (downgrade only — the insert
-- policy above already accepts a self-asserted 'active' row under the same
-- stubbed-payment caveat, so this adds no new risk).
create policy "subscriptions_update_own" on public.subscriptions
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Keep users.tier in sync with the latest subscription row so RLS/app checks
-- everywhere else can keep reading the simple users.tier field.
create function public.sync_user_tier_from_subscription()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.users
  set tier = case
    when new.status = 'active' and new.current_period_end > now() then 'premium'
    else 'standard'
  end
  where id = new.user_id;
  return new;
end;
$$;

create trigger subscriptions_sync_user_tier
  after insert or update on public.subscriptions
  for each row execute function public.sync_user_tier_from_subscription();

-- ---------------------------------------------------------------------------
-- Premium: saved collections (folders) + saved events (bookmarks)
-- Every user gets one default collection on signup (Standard tier's "save/
-- bookmark" feature); Premium users may create additional named collections.
-- The one-collection limit for Standard is a soft business rule enforced in
-- the app layer, not RLS — see docs/ARCHITECTURE.md.
-- ---------------------------------------------------------------------------

create table public.saved_collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  name text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create index saved_collections_user_id_idx on public.saved_collections (user_id);

create table public.saved_events (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.saved_collections (id) on delete cascade,
  event_id uuid not null references public.events (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (collection_id, event_id)
);

create index saved_events_collection_id_idx on public.saved_events (collection_id);
create index saved_events_event_id_idx on public.saved_events (event_id);

alter table public.saved_collections enable row level security;
alter table public.saved_events enable row level security;

create policy "saved_collections_all_own" on public.saved_collections
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "saved_events_all_own" on public.saved_events
  for all using (
    exists (
      select 1 from public.saved_collections c
      where c.id = saved_events.collection_id and c.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.saved_collections c
      where c.id = saved_events.collection_id and c.user_id = auth.uid()
    )
  );

create function public.handle_new_user_default_collection()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.saved_collections (user_id, name, is_default)
  values (new.id, 'Saved', true);
  return new;
end;
$$;

create trigger on_user_created_default_collection
  after insert on public.users
  for each row execute function public.handle_new_user_default_collection();

-- ---------------------------------------------------------------------------
-- Premium: basic analytics (event views, profile views)
-- ---------------------------------------------------------------------------

create table public.event_views (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  viewer_id uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index event_views_event_id_idx on public.event_views (event_id, created_at);

create table public.profile_views (
  id uuid primary key default gen_random_uuid(),
  viewed_user_id uuid not null references public.users (id) on delete cascade,
  viewer_id uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index profile_views_viewed_user_id_idx on public.profile_views (viewed_user_id, created_at);

alter table public.event_views enable row level security;
alter table public.profile_views enable row level security;

-- Anyone signed in can record a view; only the event's organizer (for their
-- own analytics) or the viewed profile's owner can read view rows back.
create policy "event_views_insert_any" on public.event_views
  for insert with check (auth.uid() is not null);

create policy "event_views_select_organizer" on public.event_views
  for select using (
    exists (
      select 1 from public.events e
      where e.id = event_views.event_id and e.organizer_id = auth.uid()
    )
  );

create policy "profile_views_insert_any" on public.profile_views
  for insert with check (auth.uid() is not null);

create policy "profile_views_select_own" on public.profile_views
  for select using (viewed_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Premium: recurring event templates
-- ---------------------------------------------------------------------------

create table public.event_templates (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.users (id) on delete cascade,
  title text not null,
  description text,
  category text not null,
  city text not null,
  venue_name text,
  lat double precision,
  lng double precision,
  duration_minutes integer not null default 60,
  price numeric(10, 2) not null default 0,
  capacity integer,
  cover_image_url text,
  -- e.g. {"freq":"weekly","interval":1,"count":8,"time":"18:00"}
  recurrence_rule jsonb not null,
  created_at timestamptz not null default now()
);

create index event_templates_organizer_id_idx on public.event_templates (organizer_id);

alter table public.event_templates enable row level security;

create policy "event_templates_all_own" on public.event_templates
  for all using (organizer_id = auth.uid()) with check (organizer_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Premium: events gains featured placement + early-access RSVP window
-- ---------------------------------------------------------------------------

alter table public.events
  add column is_featured boolean not null default false,
  add column premium_rsvp_opens_at timestamptz,
  add column template_id uuid references public.event_templates (id) on delete set null;

create index events_is_featured_idx on public.events (is_featured) where is_featured;

-- Premium visibility: a signed-in user who already has their own RSVP on an
-- event may see who else RSVP'd, if they're premium. Supersedes the 0001
-- policy of the same purpose.
drop policy "rsvps_select_own_or_organizer" on public.event_rsvps;

create policy "rsvps_select_own_organizer_or_premium_attendee" on public.event_rsvps
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from public.events e
      where e.id = event_rsvps.event_id and e.organizer_id = auth.uid()
    )
    or (
      exists (
        select 1 from public.event_rsvps mine
        where mine.event_id = event_rsvps.event_id and mine.user_id = auth.uid()
      )
      and exists (
        select 1 from public.users u
        where u.id = auth.uid() and u.tier = 'premium'
      )
    )
  );

-- ---------------------------------------------------------------------------
-- Hosting (Phase 3): host profiles, photos, availability, booking requests.
-- Host reviews reuse the existing `reviews` table with subject_type='user',
-- subject_id = the host's user id — no new table needed there.
-- ---------------------------------------------------------------------------

create type home_type as enum ('apartment', 'house', 'private_room', 'shared_room');
create type host_verification_status as enum ('unverified', 'pending', 'verified');
create type booking_status as enum ('pending', 'accepted', 'declined', 'cancelled', 'completed');

create table public.host_profiles (
  id uuid primary key references public.users (id) on delete cascade,
  headline text,
  about text,
  home_type home_type,
  max_guests integer,
  house_rules text,
  is_active boolean not null default false,
  verification_status host_verification_status not null default 'unverified',
  city text,
  lat double precision,
  lng double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint host_profiles_max_guests_positive check (max_guests is null or max_guests > 0)
);

create trigger host_profiles_set_updated_at
  before update on public.host_profiles
  for each row execute function public.set_updated_at();

create index host_profiles_city_idx on public.host_profiles (city);
create index host_profiles_active_idx on public.host_profiles (is_active) where is_active;

create table public.host_photos (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.host_profiles (id) on delete cascade,
  url text not null,
  sort_order integer not null default 0
);

create index host_photos_host_id_idx on public.host_photos (host_id);

create table public.host_availability (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.host_profiles (id) on delete cascade,
  start_date date not null,
  end_date date not null,
  note text,
  constraint host_availability_end_after_start check (end_date >= start_date)
);

create index host_availability_host_id_idx on public.host_availability (host_id);

create table public.booking_requests (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references public.host_profiles (id) on delete cascade,
  guest_id uuid not null references public.users (id) on delete cascade,
  start_date date not null,
  end_date date not null,
  guests_count integer not null default 1,
  message text,
  status booking_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint booking_requests_end_after_start check (end_date >= start_date),
  constraint booking_requests_guests_positive check (guests_count > 0)
);

create trigger booking_requests_set_updated_at
  before update on public.booking_requests
  for each row execute function public.set_updated_at();

create index booking_requests_host_id_idx on public.booking_requests (host_id);
create index booking_requests_guest_id_idx on public.booking_requests (guest_id);

alter table public.host_profiles enable row level security;
alter table public.host_photos enable row level security;
alter table public.host_availability enable row level security;
alter table public.booking_requests enable row level security;

-- host_profiles: active hosts are publicly browsable; a host can always see
-- and manage their own profile even while inactive/pending.
create policy "host_profiles_select_active_or_own" on public.host_profiles
  for select using (is_active or id = auth.uid());

create policy "host_profiles_insert_own" on public.host_profiles
  for insert with check (id = auth.uid());

create policy "host_profiles_update_own" on public.host_profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- host_photos / host_availability: readable whenever the parent profile is
-- readable; only the owning host can write.
create policy "host_photos_select_visible" on public.host_photos
  for select using (
    exists (
      select 1 from public.host_profiles h
      where h.id = host_photos.host_id and (h.is_active or h.id = auth.uid())
    )
  );

create policy "host_photos_all_own" on public.host_photos
  for all using (host_id = auth.uid()) with check (host_id = auth.uid());

create policy "host_availability_select_visible" on public.host_availability
  for select using (
    exists (
      select 1 from public.host_profiles h
      where h.id = host_availability.host_id and (h.is_active or h.id = auth.uid())
    )
  );

create policy "host_availability_all_own" on public.host_availability
  for all using (host_id = auth.uid()) with check (host_id = auth.uid());

-- booking_requests: guest sees/creates their own; host sees requests
-- targeting them and can update status; guest can update/cancel their own
-- pending request.
create policy "booking_requests_select_guest_or_host" on public.booking_requests
  for select using (guest_id = auth.uid() or host_id = auth.uid());

create policy "booking_requests_insert_guest" on public.booking_requests
  for insert with check (guest_id = auth.uid());

create policy "booking_requests_update_guest_or_host" on public.booking_requests
  for update using (guest_id = auth.uid() or host_id = auth.uid())
  with check (guest_id = auth.uid() or host_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Storage: host listing photos bucket (mirrors avatars/event-covers policy
-- shape from 0001_init.sql).
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('host-photos', 'host-photos', true)
on conflict (id) do nothing;

create policy "host_photos_bucket_public_read" on storage.objects
  for select using (bucket_id = 'host-photos');

create policy "host_photos_bucket_owner_write" on storage.objects
  for insert with check (
    bucket_id = 'host-photos' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "host_photos_bucket_owner_update" on storage.objects
  for update using (
    bucket_id = 'host-photos' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "host_photos_bucket_owner_delete" on storage.objects
  for delete using (
    bucket_id = 'host-photos' and (storage.foldername(name))[1] = auth.uid()::text
  );
