-- Auth overhaul, on explicit request: username becomes the unique
-- public-facing identifier (kept as a UNIQUE column, not a literal primary
-- key swap — every other table's foreign keys reference users.id as a
-- uuid; changing the PK type would touch every table in the schema for no
-- real benefit. A unique constraint achieves the actual goal: no two
-- accounts can claim the same handle). Phone-based auth is dropped
-- entirely — email (password or Google) is the only sign-in method now.

alter table public.users
  add column username text,
  add constraint users_username_format check (
    username is null or (username = lower(username) and username ~ '^[a-z0-9_]{3,20}$')
  );

create unique index users_username_unique_idx on public.users (username) where username is not null;

-- Same column-grant pattern as 0002 (name/city/photo_url/bio) — username is
-- just another self-editable profile field, not a privileged one.
grant update (username) on public.users to authenticated;

-- phone was never actually used for anything but auth — safe to drop
-- outright rather than leave an unused, always-null column around.
alter table public.users drop column phone;

-- Signups no longer carry a phone; email always does now that phone auth
-- is gone. Username is chosen by the client post-signup (needs uniqueness
-- validation before insert, which is easier to do from the app than to
-- retry inside this trigger), so it isn't set here.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, email, role)
  values (
    new.id,
    new.email,
    case
      when new.raw_user_meta_data ->> 'requested_role' = 'event_planner' then 'event_planner'::user_role
      else 'user'::user_role
    end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- The existing on_auth_user_updated trigger (0005) watches auth.users'
-- phone/email columns, not public.users' (which just lost phone) — it
-- doesn't need to change. Only the function body below does, via CREATE OR
-- REPLACE, since it's the same function the trigger already points at.
create or replace function public.handle_auth_user_update()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.users set email = new.email where id = new.id;
  return new;
end;
$$;
