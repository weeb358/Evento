-- Community cover images and post images — same public-read/owner-write
-- shape as avatars/event-covers/host-photos (0001, 0002).

insert into storage.buckets (id, name, public)
values ('community-covers', 'community-covers', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('community-post-images', 'community-post-images', true)
on conflict (id) do nothing;

create policy "community_covers_public_read" on storage.objects
  for select using (bucket_id = 'community-covers');

-- Path convention: {community_id}/cover.{ext} — only a moderator/owner of
-- that community may write it.
create policy "community_covers_moderator_write" on storage.objects
  for insert with check (
    bucket_id = 'community-covers'
    and public.is_community_moderator(((storage.foldername(name))[1])::uuid)
  );

create policy "community_covers_moderator_update" on storage.objects
  for update using (
    bucket_id = 'community-covers'
    and public.is_community_moderator(((storage.foldername(name))[1])::uuid)
  );

create policy "community_covers_moderator_delete" on storage.objects
  for delete using (
    bucket_id = 'community-covers'
    and public.is_community_moderator(((storage.foldername(name))[1])::uuid)
  );

-- Path convention: {user_id}/{filename} — any signed-in user may write
-- their own post image (post creation itself is still gated by
-- community_posts_insert_member RLS).
create policy "community_post_images_public_read" on storage.objects
  for select using (bucket_id = 'community-post-images');

create policy "community_post_images_owner_write" on storage.objects
  for insert with check (
    bucket_id = 'community-post-images' and (storage.foldername(name))[1] = auth.uid()::text
  );
