create table public.rls_validation_notes (
  id uuid primary key,
  owner_id uuid not null default auth.uid(),
  body text not null check (char_length(body) between 1 and 200)
);

comment on table public.rls_validation_notes is
  'Minimal technical proof for issue #3; not an MVP domain table.';

alter table public.rls_validation_notes enable row level security;

revoke all on table public.rls_validation_notes from anon, authenticated;
grant select, insert on table public.rls_validation_notes to authenticated;

create policy "owners can read validation notes"
on public.rls_validation_notes
for select
to authenticated
using (owner_id = (select auth.uid()));

create policy "owners can create validation notes"
on public.rls_validation_notes
for insert
to authenticated
with check (owner_id = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'item-photos',
  'item-photos',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
);

create policy "owners can read their item photo objects"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'item-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "owners can upload their item photo objects"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'item-photos'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);
