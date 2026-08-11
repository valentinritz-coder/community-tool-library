create type public.availability_kind as enum ('available', 'unavailable');

create extension if not exists btree_gist with schema extensions;

create table public.availabilities (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  kind public.availability_kind not null,
  start_date date not null,
  end_date date not null,
  created_at timestamptz not null default now(),
  constraint availability_dates_in_order check (start_date <= end_date),
  constraint availability_ranges_do_not_overlap exclude using gist (
    item_id with =,
    daterange(start_date, end_date, '[]') with &&
  )
);

comment on table public.availabilities is
  'Explicit available or unavailable calendar-date ranges. Both boundaries are inclusive; ranges for one item may not overlap.';

alter table public.availabilities enable row level security;

revoke all on public.availabilities from anon, authenticated;
grant select, insert, delete on public.availabilities to authenticated;
grant update (kind, start_date, end_date) on public.availabilities to authenticated;

create policy "active owners can read availability"
on public.availabilities for select to authenticated
using (
  exists (
    select 1 from public.items
    where items.id = availabilities.item_id
      and items.owner_id = (select auth.uid())
      and public.is_active_community_member(items.community_id)
  )
);

create policy "active owners can create availability"
on public.availabilities for insert to authenticated
with check (
  exists (
    select 1 from public.items
    where items.id = availabilities.item_id
      and items.owner_id = (select auth.uid())
      and public.is_active_community_member(items.community_id)
  )
);

create policy "active owners can update availability"
on public.availabilities for update to authenticated
using (
  exists (
    select 1 from public.items
    where items.id = availabilities.item_id
      and items.owner_id = (select auth.uid())
      and public.is_active_community_member(items.community_id)
  )
)
with check (
  exists (
    select 1 from public.items
    where items.id = availabilities.item_id
      and items.owner_id = (select auth.uid())
      and public.is_active_community_member(items.community_id)
  )
);

create policy "active owners can delete availability"
on public.availabilities for delete to authenticated
using (
  exists (
    select 1 from public.items
    where items.id = availabilities.item_id
      and items.owner_id = (select auth.uid())
      and public.is_active_community_member(items.community_id)
  )
);

drop function public.browse_community_inventory(uuid);

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
  is_owned boolean,
  availability_summary text
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
    items.owner_id = auth.uid(),
    coalesce(
      (
        select string_agg(
          case availability.kind
            when 'available' then 'Available'
            else 'Unavailable'
          end ||
          case
            when availability.start_date = availability.end_date
              then ' on ' || availability.start_date::text
            else ' from ' || availability.start_date::text || ' through ' || availability.end_date::text
          end,
          '; ' order by availability.start_date, availability.end_date
        )
        from public.availabilities as availability
        where availability.item_id = items.id
      ),
      'Not set by the owner.'
    )
  from public.items
  where items.community_id = target_community_id
    and items.photo_uploaded
    and not items.archived
  order by items.created_at desc;
end;
$$;

revoke all on function public.browse_community_inventory(uuid) from public;
grant execute on function public.browse_community_inventory(uuid) to authenticated;
