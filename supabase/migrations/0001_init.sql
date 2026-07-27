-- Phase 1 schema: users, events, event_rsvps, reviews, reports.
-- reviews/reports use polymorphic subject_type/target_type columns so Phase 3
-- (hosting) can add new subject/target kinds later without a schema migration.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type user_tier as enum ('standard', 'premium');
create type event_status as enum ('draft', 'published', 'cancelled');
create type rsvp_status as enum ('going', 'interested');
create type report_status as enum ('open', 'reviewing', 'resolved', 'dismissed');
create type review_subject_type as enum ('event', 'user');
create type report_target_type as enum ('event', 'user');

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

create function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- users — one row per auth.users identity, created via trigger below.
-- ---------------------------------------------------------------------------

create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  phone text unique,
  name text,
  city text,
  photo_url text,
  bio text,
  is_verified boolean not null default false,
  tier user_tier not null default 'standard',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.users is 'App-level profile, 1:1 with auth.users.';

-- Auto-create a users row whenever someone signs up via Supabase Auth.
create function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, phone)
  values (new.id, new.phone)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------------

create table public.events (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.users (id) on delete cascade,
  title text not null,
  description text,
  category text not null,
  city text not null,
  venue_name text,
  lat double precision,
  lng double precision,
  start_time timestamptz not null,
  end_time timestamptz,
  price numeric(10, 2) not null default 0,
  capacity integer,
  cover_image_url text,
  status event_status not null default 'published',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  search_vector tsvector generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(venue_name, '')), 'C')
  ) stored,
  constraint events_end_after_start check (end_time is null or end_time >= start_time),
  constraint events_price_non_negative check (price >= 0),
  constraint events_capacity_positive check (capacity is null or capacity > 0)
);

create trigger events_set_updated_at
  before update on public.events
  for each row execute function public.set_updated_at();

create index events_city_idx on public.events (city);
create index events_category_idx on public.events (category);
create index events_start_time_idx on public.events (start_time);
create index events_organizer_id_idx on public.events (organizer_id);
create index events_search_vector_idx on public.events using gin (search_vector);

-- ---------------------------------------------------------------------------
-- event_rsvps
-- ---------------------------------------------------------------------------

create table public.event_rsvps (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  status rsvp_status not null,
  created_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create index event_rsvps_event_id_idx on public.event_rsvps (event_id);
create index event_rsvps_user_id_idx on public.event_rsvps (user_id);

-- ---------------------------------------------------------------------------
-- reviews — polymorphic subject (event or user) so hosting reviews can reuse
-- this table later by adding new review_subject_type values.
-- ---------------------------------------------------------------------------

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  subject_type review_subject_type not null,
  subject_id uuid not null,
  reviewer_id uuid not null references public.users (id) on delete cascade,
  rating smallint not null,
  text text,
  created_at timestamptz not null default now(),
  constraint reviews_rating_range check (rating between 1 and 5),
  unique (subject_type, subject_id, reviewer_id)
);

create index reviews_subject_idx on public.reviews (subject_type, subject_id);

-- ---------------------------------------------------------------------------
-- reports — polymorphic target (event or user).
-- ---------------------------------------------------------------------------

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users (id) on delete cascade,
  target_type report_target_type not null,
  target_id uuid not null,
  reason text not null,
  status report_status not null default 'open',
  created_at timestamptz not null default now()
);

create index reports_target_idx on public.reports (target_type, target_id);
create index reports_status_idx on public.reports (status);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.users enable row level security;
alter table public.events enable row level security;
alter table public.event_rsvps enable row level security;
alter table public.reviews enable row level security;
alter table public.reports enable row level security;

-- users: profiles are publicly readable (organizer name, reviewer name, etc.
-- need to render across the app); only the owner can modify their own row.
create policy "users_select_all" on public.users
  for select using (true);

create policy "users_update_own" on public.users
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- events: published events are publicly readable; organizers can also see
-- their own drafts. Only the organizer can insert/update/delete their events.
create policy "events_select_published_or_own" on public.events
  for select using (status = 'published' or organizer_id = auth.uid());

create policy "events_insert_own" on public.events
  for insert with check (organizer_id = auth.uid());

create policy "events_update_own" on public.events
  for update using (organizer_id = auth.uid()) with check (organizer_id = auth.uid());

create policy "events_delete_own" on public.events
  for delete using (organizer_id = auth.uid());

-- event_rsvps: an event's organizer and the RSVP'ing user can see the RSVP;
-- only the user can create/update/delete their own RSVP.
create policy "rsvps_select_own_or_organizer" on public.event_rsvps
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from public.events e
      where e.id = event_rsvps.event_id and e.organizer_id = auth.uid()
    )
  );

create policy "rsvps_insert_own" on public.event_rsvps
  for insert with check (user_id = auth.uid());

create policy "rsvps_update_own" on public.event_rsvps
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "rsvps_delete_own" on public.event_rsvps
  for delete using (user_id = auth.uid());

-- reviews: publicly readable; only the reviewer can write their own review.
create policy "reviews_select_all" on public.reviews
  for select using (true);

create policy "reviews_insert_own" on public.reviews
  for insert with check (reviewer_id = auth.uid());

create policy "reviews_update_own" on public.reviews
  for update using (reviewer_id = auth.uid()) with check (reviewer_id = auth.uid());

create policy "reviews_delete_own" on public.reviews
  for delete using (reviewer_id = auth.uid());

-- reports: only the reporter can see/create their own reports. No update/delete
-- policy is defined on purpose — reports are immutable once filed by a user;
-- status changes are a moderation action to be done via the service role.
create policy "reports_select_own" on public.reports
  for select using (reporter_id = auth.uid());

create policy "reports_insert_own" on public.reports
  for insert with check (reporter_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Storage buckets
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('event-covers', 'event-covers', true)
on conflict (id) do nothing;

-- Both buckets: anyone can read (public URLs for images in the app/website);
-- a user may only write into a path prefixed with their own uid, e.g.
-- `avatars/{uid}/photo.jpg` or `event-covers/{uid}/{event_id}.jpg`.
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

create policy "avatars_owner_write" on storage.objects
  for insert with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_owner_update" on storage.objects
  for update using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_owner_delete" on storage.objects
  for delete using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "event_covers_public_read" on storage.objects
  for select using (bucket_id = 'event-covers');

create policy "event_covers_owner_write" on storage.objects
  for insert with check (
    bucket_id = 'event-covers' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "event_covers_owner_update" on storage.objects
  for update using (
    bucket_id = 'event-covers' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "event_covers_owner_delete" on storage.objects
  for delete using (
    bucket_id = 'event-covers' and (storage.foldername(name))[1] = auth.uid()::text
  );
