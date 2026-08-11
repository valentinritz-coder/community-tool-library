create type public.item_category as enum (
  'household',
  'small_diy',
  'garden',
  'leisure'
);

create table public.items (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 2 and 80),
  category public.item_category not null,
  description text not null check (char_length(btrim(description)) between 1 and 500),
  photo_path text not null,
  is_free boolean not null,
  price_per_day_cents integer,
  archived boolean not null default false,
  photo_uploaded boolean not null default false,
  created_at timestamptz not null default now(),
  constraint items_pricing_consistent check (
    (is_free and price_per_day_cents is null)
    or (
      not is_free
      and price_per_day_cents is not null
      and price_per_day_cents between 1 and 100000
    )
  ),
  constraint items_photo_path_matches_id check (
    photo_path ~ ('^' || id::text || '/photo\.(jpg|png|webp)$')
  )
);

alter table public.items enable row level security;

revoke all on public.items from anon, authenticated;
grant select on public.items to authenticated;
grant update (name, category, description, is_free, price_per_day_cents, archived)
on public.items to authenticated;

create policy "active members can read community items"
on public.items for select to authenticated
using (
  (select public.is_active_community_member(community_id))
  and (photo_uploaded or owner_id = (select auth.uid()))
);

create policy "owners can update their items"
on public.items for update to authenticated
using (
  owner_id = (select auth.uid())
  and (select public.is_active_community_member(community_id))
)
with check (
  owner_id = (select auth.uid())
  and (select public.is_active_community_member(community_id))
);

create function public.prevent_item_boundary_changes()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.owner_id <> old.owner_id then
    raise exception 'Item owner cannot be changed' using errcode = '42501';
  end if;
  if new.community_id <> old.community_id then
    raise exception 'Item community cannot be changed' using errcode = '42501';
  end if;
  if new.photo_path <> old.photo_path then
    raise exception 'Item photo path cannot be changed' using errcode = '42501';
  end if;
  if new.created_at <> old.created_at then
    raise exception 'Item creation time cannot be changed' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger protect_item_boundaries
before update on public.items
for each row execute function public.prevent_item_boundary_changes();

create function public.create_item(
  target_community_id uuid,
  item_name text,
  item_category public.item_category,
  item_description text,
  item_is_free boolean,
  item_price_per_day_cents integer,
  photo_extension text
)
returns public.items
language plpgsql
security definer
set search_path = ''
as $$
declare
  item_id uuid := gen_random_uuid();
  new_item public.items;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if not public.is_active_community_member(target_community_id) then
    raise exception 'Active community membership required' using errcode = '42501';
  end if;
  if photo_extension not in ('jpg', 'png', 'webp') then
    raise exception 'Photo must be JPEG, PNG, or WebP' using errcode = '22023';
  end if;

  insert into public.items (
    id, community_id, owner_id, name, category, description, photo_path,
    is_free, price_per_day_cents
  ) values (
    item_id, target_community_id, auth.uid(), btrim(item_name), item_category,
    btrim(item_description), item_id::text || '/photo.' || photo_extension,
    item_is_free, item_price_per_day_cents
  ) returning * into new_item;

  return new_item;
end;
$$;

revoke all on function public.create_item(uuid, text, public.item_category, text, boolean, integer, text) from public;
grant execute on function public.create_item(uuid, text, public.item_category, text, boolean, integer, text) to authenticated;

create function public.publish_item(target_item_id uuid)
returns public.items
language plpgsql
security definer
set search_path = ''
as $$
declare
  published_item public.items;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into published_item
  from public.items
  where id = target_item_id
    and owner_id = auth.uid()
    and public.is_active_community_member(community_id);

  if published_item is null then
    raise exception 'Only the active item owner can publish it' using errcode = '42501';
  end if;
  if not exists (
    select 1 from storage.objects
    where bucket_id = 'item-photos'
      and name = published_item.photo_path
  ) then
    raise exception 'Item photo upload required' using errcode = '23514';
  end if;

  update public.items
  set photo_uploaded = true
  where id = target_item_id
  returning * into published_item;

  return published_item;
end;
$$;

revoke all on function public.publish_item(uuid) from public;
grant execute on function public.publish_item(uuid) to authenticated;

drop policy "owners can read their item photo objects" on storage.objects;
drop policy "owners can upload their item photo objects" on storage.objects;

create policy "active community members can read item photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'item-photos'
  and exists (
    select 1 from public.items
    where items.id::text = (storage.foldername(storage.objects.name))[1]
      and items.photo_path = storage.objects.name
      and items.photo_uploaded
      and public.is_active_community_member(items.community_id)
  )
);

create policy "item owners can upload their photo"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'item-photos'
  and exists (
    select 1 from public.items
    where items.id::text = (storage.foldername(storage.objects.name))[1]
      and items.photo_path = storage.objects.name
      and items.owner_id = auth.uid()
      and public.is_active_community_member(items.community_id)
  )
);

create policy "item owners can replace their photo"
on storage.objects for update to authenticated
using (
  bucket_id = 'item-photos'
  and exists (
    select 1 from public.items
    where items.photo_path = storage.objects.name
      and items.owner_id = auth.uid()
      and public.is_active_community_member(items.community_id)
  )
)
with check (
  bucket_id = 'item-photos'
  and exists (
    select 1 from public.items
    where items.photo_path = storage.objects.name
      and items.owner_id = auth.uid()
      and public.is_active_community_member(items.community_id)
  )
);
