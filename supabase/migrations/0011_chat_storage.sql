-- Chat image attachments. Path convention: {thread_id}/{filename} — write
-- access is gated by thread participation (is_thread_participant, defined
-- in 0009), not by ownership of the path prefix like other buckets, since
-- multiple participants share a thread's image folder.
--
-- Known limitation: this bucket is `public = true` (same as every other
-- bucket in this project), which means Supabase serves it via unauthenticated
-- public URLs — the SELECT policy below only matters for authenticated
-- reads via the client library, not for someone who obtains a raw URL
-- (UUIDs in the path make that unguessable, but it isn't real access
-- control). For a general events/social app that's consistent with how
-- every other image in this app is served; for a genuinely private
-- messenger it wouldn't be — that would need a non-public bucket and
-- short-lived signed URLs generated per-participant instead.

insert into storage.buckets (id, name, public)
values ('chat-images', 'chat-images', true)
on conflict (id) do nothing;

create policy "chat_images_participant_read" on storage.objects
  for select using (
    bucket_id = 'chat-images'
    and public.is_thread_participant(((storage.foldername(name))[1])::uuid)
  );

create policy "chat_images_participant_write" on storage.objects
  for insert with check (
    bucket_id = 'chat-images'
    and public.is_thread_participant(((storage.foldername(name))[1])::uuid)
  );
