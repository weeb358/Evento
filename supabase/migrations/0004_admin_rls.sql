-- Admin/moderator RLS: the website's /admin section needs to read every
-- report (not just the reporter's own) and approve host verification /
-- user verification. There's no roles table yet (see docs/ROADMAP.md, "full
-- admin panel" is Phase 4+) — for now, admin/moderator is a `role` value in
-- the user's `auth.users.user_metadata`, readable in RLS via `auth.jwt()`
-- since Supabase embeds user_metadata in the access token. Grant it via the
-- Supabase dashboard or Admin API; there's no self-serve UI for this by
-- design — it's not something a client should be able to set on itself.

create or replace function public.is_admin_or_moderator()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce(
    (auth.jwt() -> 'user_metadata' ->> 'role') in ('admin', 'moderator'),
    false
  );
$$;

grant execute on function public.is_admin_or_moderator() to authenticated;

-- reports: admins/moderators can read and update every report, alongside
-- the existing reporter-can-see-own-and-insert policies from 0001_init.sql.
-- Safe as plain RLS policies because reports has no owner-side UPDATE
-- policy at all (reports are immutable once filed — see 0001) — so this is
-- the only way to update a report row, no column-grant interaction risk.
create policy "reports_select_admin" on public.reports
  for select using (public.is_admin_or_moderator());

create policy "reports_update_admin" on public.reports
  for update using (public.is_admin_or_moderator()) with check (public.is_admin_or_moderator());

-- host_profiles / users: verification columns must NOT be reachable via a
-- plain "is admin" RLS policy here, because both tables already have an
-- owner-can-update-own-row policy with no column scoping
-- (host_profiles_update_own in 0002, users_update_own in 0001). Postgres
-- combines multiple permissive UPDATE policies with OR and applies column
-- privileges role-wide, not per-policy — so simply granting the
-- verification column to `authenticated` would let an owner satisfy the
-- *owner* policy while touching a column only the *admin* policy was meant
-- to protect. Routing verification writes through SECURITY DEFINER
-- functions that check authorization in code sidesteps that trap entirely:
-- these run with elevated privilege and never rely on RLS/column grants
-- for the authorization decision.

create or replace function public.set_host_verification_status(
  target_host_id uuid,
  new_status host_verification_status
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin_or_moderator() then
    raise exception 'not authorized';
  end if;
  update public.host_profiles set verification_status = new_status where id = target_host_id;
end;
$$;

grant execute on function public.set_host_verification_status(uuid, host_verification_status) to authenticated;

create or replace function public.set_user_verified(target_user_id uuid, verified boolean)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin_or_moderator() then
    raise exception 'not authorized';
  end if;
  update public.users set is_verified = verified where id = target_user_id;
end;
$$;

grant execute on function public.set_user_verified(uuid, boolean) to authenticated;

-- The two SECURITY DEFINER functions above are necessary but not
-- sufficient: host_profiles_update_own (0002) and users_update_own (0001)
-- still have no column scoping, so an owner could reach verification_status
-- / is_verified directly through their own-row UPDATE policy without ever
-- calling an RPC. Column-level privileges are the actual enforcement here —
-- explicitly enumerate what an owner may touch and leave verification
-- columns out of the grant entirely.
revoke update on public.host_profiles from authenticated;
grant update (headline, about, home_type, max_guests, house_rules, is_active, city, lat, lng)
  on public.host_profiles to authenticated;

-- A host can request review (-> 'pending') but never self-approve; this is
-- deliberately narrower than set_host_verification_status above, which is
-- admin-only and can set any status.
create or replace function public.request_host_verification()
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.host_profiles set verification_status = 'pending' where id = auth.uid();
end;
$$;

grant execute on function public.request_host_verification() to authenticated;
