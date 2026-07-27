-- FCM device tokens, so a later reminder scheduler (see docs/ROADMAP.md —
-- still not built; this migration only covers the app-side registration
-- half of push notifications) has somewhere to read tokens from.

create table public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  token text not null unique,
  platform text not null default 'android',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index push_tokens_user_id_idx on public.push_tokens (user_id);

create trigger push_tokens_set_updated_at
  before update on public.push_tokens
  for each row execute function public.set_updated_at();

alter table public.push_tokens enable row level security;

-- A user manages only their own tokens. There's no admin/broad-read policy
-- here on purpose — a future sender (the reminder scheduler) runs with the
-- service role and bypasses RLS entirely, so it never needs one.
create policy "push_tokens_all_own" on public.push_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
