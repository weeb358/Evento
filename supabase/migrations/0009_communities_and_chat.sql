-- Full Phase 4+ scope, on explicit request: communities (create/join/leave,
-- posts, comments, likes, moderators, rules, pinned posts, events inside
-- communities) and real-time chat (1:1 DMs + group chat tied to a
-- community). Read receipts are a `last_read_at` timestamp per
-- participant, not a per-message-per-user table — good enough to derive
-- "read" for 1:1 and small groups without a write on every message view.
-- Typing indicators are intentionally NOT a table — they're ephemeral UI
-- state, handled client-side via Supabase Realtime Presence/Broadcast on a
-- per-thread channel, which never touches Postgres.

-- ---------------------------------------------------------------------------
-- Communities
-- ---------------------------------------------------------------------------

create type community_member_role as enum ('owner', 'moderator', 'member');

create table public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text,
  cover_image_url text,
  rules text,
  is_private boolean not null default false,
  created_by uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint communities_slug_format check (slug ~ '^[a-z0-9-]{3,50}$')
);

create trigger communities_set_updated_at
  before update on public.communities
  for each row execute function public.set_updated_at();

create index communities_created_by_idx on public.communities (created_by);

create table public.community_members (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  role community_member_role not null default 'member',
  joined_at timestamptz not null default now(),
  unique (community_id, user_id)
);

create index community_members_community_id_idx on public.community_members (community_id);
create index community_members_user_id_idx on public.community_members (user_id);

-- Creating a community auto-joins the creator as its owner — otherwise
-- they'd create a community they can't post in (insert policies below
-- require membership).
create or replace function public.handle_new_community()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.community_members (community_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end;
$$;

create trigger on_community_created
  after insert on public.communities
  for each row execute function public.handle_new_community();

create table public.community_posts (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities (id) on delete cascade,
  author_id uuid not null references public.users (id) on delete cascade,
  content text not null,
  image_url text,
  is_pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger community_posts_set_updated_at
  before update on public.community_posts
  for each row execute function public.set_updated_at();

create index community_posts_community_id_idx on public.community_posts (community_id, is_pinned desc, created_at desc);

create table public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts (id) on delete cascade,
  author_id uuid not null references public.users (id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create index post_comments_post_id_idx on public.post_comments (post_id, created_at);

create table public.post_likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create index post_likes_post_id_idx on public.post_likes (post_id);

-- Events inside communities — nullable, so ungrouped events (all of Phase
-- 1-3) are unaffected.
alter table public.events add column community_id uuid references public.communities (id) on delete set null;
create index events_community_id_idx on public.events (community_id) where community_id is not null;

-- ---------------------------------------------------------------------------
-- Communities RLS
-- ---------------------------------------------------------------------------

alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.community_posts enable row level security;
alter table public.post_comments enable row level security;
alter table public.post_likes enable row level security;

create or replace function public.is_community_member(p_community_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.community_members
    where community_id = p_community_id and user_id = auth.uid()
  );
$$;

create or replace function public.is_community_moderator(p_community_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.community_members
    where community_id = p_community_id and user_id = auth.uid() and role in ('owner', 'moderator')
  );
$$;

create policy "communities_select_public_or_member" on public.communities
  for select using (not is_private or public.is_community_member(id));

create policy "communities_insert_own" on public.communities
  for insert with check (created_by = auth.uid());

create policy "communities_update_moderator" on public.communities
  for update using (public.is_community_moderator(id)) with check (public.is_community_moderator(id));

create policy "communities_delete_owner" on public.communities
  for delete using (
    exists (
      select 1 from public.community_members
      where community_id = id and user_id = auth.uid() and role = 'owner'
    )
  );

create policy "community_members_select_visible" on public.community_members
  for select using (
    exists (
      select 1 from public.communities c
      where c.id = community_id and (not c.is_private or public.is_community_member(c.id))
    )
  );

-- Self-join is only allowed on public communities; joining a private one
-- (or adding someone else at all) requires an existing moderator/owner —
-- there's no invite-code flow yet, a moderator just adds the row directly.
create policy "community_members_insert_self_or_moderator" on public.community_members
  for insert with check (
    (
      user_id = auth.uid()
      and exists (select 1 from public.communities c where c.id = community_id and not c.is_private)
    )
    or public.is_community_moderator(community_id)
  );

create policy "community_members_update_owner" on public.community_members
  for update using (
    exists (
      select 1 from public.community_members m
      where m.community_id = community_members.community_id and m.user_id = auth.uid() and m.role = 'owner'
    )
  );

create policy "community_members_delete_self_or_moderator" on public.community_members
  for delete using (user_id = auth.uid() or public.is_community_moderator(community_id));

create policy "community_posts_select_visible" on public.community_posts
  for select using (
    exists (
      select 1 from public.communities c
      where c.id = community_id and (not c.is_private or public.is_community_member(c.id))
    )
  );

create policy "community_posts_insert_member" on public.community_posts
  for insert with check (author_id = auth.uid() and public.is_community_member(community_id));

create policy "community_posts_update_author_or_moderator" on public.community_posts
  for update using (author_id = auth.uid() or public.is_community_moderator(community_id));

create policy "community_posts_delete_author_or_moderator" on public.community_posts
  for delete using (author_id = auth.uid() or public.is_community_moderator(community_id));

create policy "post_comments_select_visible" on public.post_comments
  for select using (
    exists (
      select 1 from public.community_posts p
      join public.communities c on c.id = p.community_id
      where p.id = post_id and (not c.is_private or public.is_community_member(c.id))
    )
  );

create policy "post_comments_insert_member" on public.post_comments
  for insert with check (
    author_id = auth.uid()
    and exists (
      select 1 from public.community_posts p
      where p.id = post_id and public.is_community_member(p.community_id)
    )
  );

create policy "post_comments_delete_author_or_moderator" on public.post_comments
  for delete using (
    author_id = auth.uid()
    or exists (
      select 1 from public.community_posts p
      where p.id = post_id and public.is_community_moderator(p.community_id)
    )
  );

create policy "post_likes_select_visible" on public.post_likes
  for select using (
    exists (
      select 1 from public.community_posts p
      join public.communities c on c.id = p.community_id
      where p.id = post_id and (not c.is_private or public.is_community_member(c.id))
    )
  );

create policy "post_likes_insert_member" on public.post_likes
  for insert with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.community_posts p
      where p.id = post_id and public.is_community_member(p.community_id)
    )
  );

create policy "post_likes_delete_own" on public.post_likes
  for delete using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Chat: 1:1 DMs + group chat (optionally tied to a community)
-- ---------------------------------------------------------------------------

create table public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  is_group boolean not null default false,
  community_id uuid references public.communities (id) on delete cascade,
  title text,
  created_by uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.chat_participants (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  unique (thread_id, user_id)
);

create index chat_participants_user_id_idx on public.chat_participants (user_id);
create index chat_participants_thread_id_idx on public.chat_participants (thread_id);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  sender_id uuid not null references public.users (id) on delete cascade,
  content text,
  image_url text,
  location_lat double precision,
  location_lng double precision,
  created_at timestamptz not null default now(),
  constraint chat_messages_has_content check (
    content is not null or image_url is not null or (location_lat is not null and location_lng is not null)
  )
);

create index chat_messages_thread_id_idx on public.chat_messages (thread_id, created_at);

alter table public.chat_threads enable row level security;
alter table public.chat_participants enable row level security;
alter table public.chat_messages enable row level security;

create or replace function public.is_thread_participant(p_thread_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.chat_participants
    where thread_id = p_thread_id and user_id = auth.uid()
  );
$$;

create policy "chat_threads_select_participant" on public.chat_threads
  for select using (public.is_thread_participant(id));

create policy "chat_threads_insert_own" on public.chat_threads
  for insert with check (created_by = auth.uid());

create policy "chat_participants_select_fellow_participant" on public.chat_participants
  for select using (public.is_thread_participant(thread_id));

-- A thread's creator adds the initial participants (including themself);
-- an existing participant can add others to a *group* thread (not 1:1 —
-- app-level logic keeps 1:1 threads to exactly two people).
create policy "chat_participants_insert_creator_or_participant" on public.chat_participants
  for insert with check (
    exists (select 1 from public.chat_threads t where t.id = thread_id and t.created_by = auth.uid())
    or public.is_thread_participant(thread_id)
  );

create policy "chat_participants_update_own" on public.chat_participants
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "chat_participants_delete_own" on public.chat_participants
  for delete using (user_id = auth.uid());

create policy "chat_messages_select_participant" on public.chat_messages
  for select using (public.is_thread_participant(thread_id));

create policy "chat_messages_insert_participant" on public.chat_messages
  for insert with check (sender_id = auth.uid() and public.is_thread_participant(thread_id));

-- Finds an existing 1:1 thread between the caller and [other_user_id], or
-- creates one — prevents duplicate DM threads accumulating between the
-- same pair every time either one opens a chat.
create or replace function public.get_or_create_direct_thread(other_user_id uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  existing_thread_id uuid;
  new_thread_id uuid;
begin
  select cp1.thread_id into existing_thread_id
  from public.chat_participants cp1
  join public.chat_participants cp2 on cp2.thread_id = cp1.thread_id
  join public.chat_threads t on t.id = cp1.thread_id
  where t.is_group = false
    and cp1.user_id = auth.uid()
    and cp2.user_id = other_user_id
  limit 1;

  if existing_thread_id is not null then
    return existing_thread_id;
  end if;

  insert into public.chat_threads (is_group, created_by)
  values (false, auth.uid())
  returning id into new_thread_id;

  insert into public.chat_participants (thread_id, user_id)
  values (new_thread_id, auth.uid()), (new_thread_id, other_user_id);

  return new_thread_id;
end;
$$;

grant execute on function public.get_or_create_direct_thread(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime: live-update chat messages and community posts/comments/likes.
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table public.chat_messages;
alter publication supabase_realtime add table public.community_posts;
alter publication supabase_realtime add table public.post_comments;
alter publication supabase_realtime add table public.post_likes;
