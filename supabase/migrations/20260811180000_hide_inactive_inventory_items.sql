drop policy "active members can read community items" on public.items;

create policy "active members can read published community items"
on public.items for select to authenticated
using (
  (select public.is_active_community_member(community_id))
  and (
    owner_id = (select auth.uid())
    or (photo_uploaded and not archived)
  )
);
