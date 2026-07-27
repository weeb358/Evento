-- Adds email/password as a second auth method alongside phone OTP, and a
-- real 3-role model (admin / event_planner / user) backed by a column
-- instead of JWT user_metadata. Replaces is_admin_or_moderator() (which
-- only ever needs to check a single admin role now — "moderator" was never
-- a real role, just a placeholder) with is_admin(), reading
-- public.users.role directly so there's no JWT-staleness window between a
-- role change and the client's token refreshing.

create type user_role as enum ('user', 'event_planner', 'admin');

alter table public.users
  add column role user_role not null default 'user',
  add column email text unique;

-- ---------------------------------------------------------------------------
-- Keep public.users.email/phone in sync with auth.users automatically,
-- instead of trusting the client to set them (they aren't permissions, but
-- they should still only ever reflect what Supabase Auth actually verified).
-- ---------------------------------------------------------------------------

create or replace function public.handle_auth_user_update()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.users set phone = new.phone, email = new.email where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_updated
  after update of phone, email on auth.users
  for each row execute function public.handle_auth_user_update();

-- Email signups skip the phone-based insert trigger's phone value and need
-- email populated too; a signup can also request the 'event_planner' role
-- for itself (never 'admin') via `options.data.requested_role` — anything
-- other than the literal string 'event_planner' is ignored and the row
-- keeps the 'user' default. This is safe to honor unauthenticated at signup
-- because 'event_planner' carries no privilege beyond "can create events".
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, phone, email, role)
  values (
    new.id,
    new.phone,
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

-- ---------------------------------------------------------------------------
-- Role checks + admin-only role management. See docs/ARCHITECTURE.md for
-- why this can't just be a granted column + RLS policy (same trap as
-- verification_status/tier).
-- ---------------------------------------------------------------------------

create or replace function public.current_user_role()
returns user_role
language sql
stable
security definer set search_path = public
as $$
  select role from public.users where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce(public.current_user_role() = 'admin', false);
$$;

grant execute on function public.current_user_role() to authenticated;
grant execute on function public.is_admin() to authenticated;

-- A signed-in user may upgrade their own account to event_planner, but only
-- ever from 'user' — never touches an existing admin's role, and can't be
-- used to set 'admin' since the target value is hardcoded, not a parameter.
create or replace function public.request_event_planner_role()
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.users set role = 'event_planner' where id = auth.uid() and role = 'user';
end;
$$;

grant execute on function public.request_event_planner_role() to authenticated;

-- Admin-only: change anyone's role, for the rare case a role needs manual
-- correction (e.g. demoting a planner, promoting a second admin). No UI
-- calls this yet — it exists so that's a config change, not a migration.
create or replace function public.set_user_role(target_user_id uuid, new_role user_role)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;
  update public.users set role = new_role where id = target_user_id;
end;
$$;

grant execute on function public.set_user_role(uuid, user_role) to authenticated;

-- ---------------------------------------------------------------------------
-- Migrate existing admin-check policies from JWT user_metadata to is_admin().
-- ---------------------------------------------------------------------------

drop policy "reports_select_admin" on public.reports;
drop policy "reports_update_admin" on public.reports;

create policy "reports_select_admin" on public.reports
  for select using (public.is_admin());

create policy "reports_update_admin" on public.reports
  for update using (public.is_admin()) with check (public.is_admin());

create or replace function public.set_host_verification_status(
  target_host_id uuid,
  new_status host_verification_status
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;
  update public.host_profiles set verification_status = new_status where id = target_host_id;
end;
$$;

create or replace function public.set_user_verified(target_user_id uuid, verified boolean)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;
  update public.users set is_verified = verified where id = target_user_id;
end;
$$;

drop function if exists public.is_admin_or_moderator();

-- ---------------------------------------------------------------------------
-- Event creation now requires the event_planner or admin role — previously
-- any signed-in user could organize (see 0001_init.sql). Edit/delete on an
-- already-created event stays organizer-only regardless of current role, so
-- a demoted planner doesn't lose control of events they already made.
-- ---------------------------------------------------------------------------

drop policy "events_insert_own" on public.events;

create policy "events_insert_own" on public.events
  for insert with check (
    organizer_id = auth.uid()
    and public.current_user_role() in ('event_planner', 'admin')
  );
