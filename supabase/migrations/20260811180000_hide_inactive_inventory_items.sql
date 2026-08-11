drop policy "active members can read community items" on public.items;

create policy "owners can read their items"
on public.items for select to authenticated
using (
  owner_id = (select auth.uid())
  and (select public.is_active_community_member(community_id))
);

create function public.browse_community_inventory(target_community_id uuid)
returns table (
  id uuid,
  community_id uuid,
  name text,
  category public.item_category,
  description text,
  photo_path text,
  is_free boolean,
  price_per_day_cents integer,
  is_owned boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_active_community_member(target_community_id) then
    raise exception 'Active community membership required' using errcode = '42501';
  end if;

  return query
  select
    items.id,
    items.community_id,
    items.name,
    items.category,
    items.description,
    items.photo_path,
    items.is_free,
    items.price_per_day_cents,
    items.owner_id = auth.uid()
  from public.items
  where items.community_id = target_community_id
    and items.photo_uploaded
    and not items.archived
  order by items.created_at desc;
end;
$$;

revoke all on function public.browse_community_inventory(uuid) from public;
grant execute on function public.browse_community_inventory(uuid) to authenticated;

create function public.can_read_inventory_photo(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.items
    where items.photo_path = object_name
      and items.photo_uploaded
      and public.is_active_community_member(items.community_id)
      and (not items.archived or items.owner_id = auth.uid())
  );
$$;

revoke all on function public.can_read_inventory_photo(text) from public;
grant execute on function public.can_read_inventory_photo(text) to authenticated;

drop policy "active community members can read item photos" on storage.objects;

create policy "active community members can read inventory photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'item-photos'
  and public.can_read_inventory_photo(name)
);
