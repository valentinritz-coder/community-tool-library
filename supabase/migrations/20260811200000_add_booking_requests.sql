create type public.booking_status as enum ('requested');

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.items(id) on delete cascade,
  borrower_id uuid not null references auth.users(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  status public.booking_status not null default 'requested',
  created_at timestamptz not null default now(),
  constraint booking_dates_are_finite check (isfinite(start_date) and isfinite(end_date)),
  constraint booking_dates_in_order check (start_date <= end_date)
);

comment on table public.bookings is
  'A booking is only a non-exclusive request in M3 issue #8. Exclusivity and decisions belong to issue #9.';

alter table public.bookings enable row level security;

revoke all on public.bookings from anon, authenticated;

create policy "borrowers can read their booking rows"
on public.bookings for select to authenticated
using (
  borrower_id = (select auth.uid())
  and exists (
    select 1 from public.items
    where items.id = bookings.item_id
      and public.is_active_community_member(items.community_id)
  )
);

create policy "owners can read booking rows for their items"
on public.bookings for select to authenticated
using (
  exists (
    select 1 from public.items
    where items.id = bookings.item_id
      and items.owner_id = (select auth.uid())
      and public.is_active_community_member(items.community_id)
  )
);

create function public.request_booking(
  target_item_id uuid,
  requested_start_date date,
  requested_end_date date
)
returns table (
  id uuid,
  item_id uuid,
  start_date date,
  end_date date,
  status public.booking_status
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_community_id uuid;
  new_booking public.bookings;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if requested_start_date is null or requested_end_date is null then
    raise exception 'Choose both a start date and an end date' using errcode = '22023';
  end if;
  if not isfinite(requested_start_date) or not isfinite(requested_end_date) then
    raise exception 'Booking dates must be finite calendar dates' using errcode = '22023';
  end if;
  if requested_start_date > requested_end_date then
    raise exception 'The end date must be on or after the start date' using errcode = '22023';
  end if;

  select items.community_id into target_community_id
  from public.items
  where items.id = target_item_id
    and items.photo_uploaded
    and not items.archived
    and items.owner_id <> auth.uid();

  if target_community_id is null
    or not public.is_active_community_member(target_community_id) then
    raise exception 'This item is not available to request' using errcode = '42501';
  end if;

  if not coalesce(
    (
      select range_agg(daterange(start_date, end_date, '[]'))
        @> daterange(requested_start_date, requested_end_date, '[]')
      from public.availabilities
      where availabilities.item_id = target_item_id
    ),
    false
  ) then
    raise exception 'The requested dates are not fully available' using errcode = '22023';
  end if;

  insert into public.bookings (item_id, borrower_id, start_date, end_date, status)
  values (target_item_id, auth.uid(), requested_start_date, requested_end_date, 'requested')
  returning * into new_booking;

  return query select new_booking.id, new_booking.item_id, new_booking.start_date,
    new_booking.end_date, new_booking.status;
end;
$$;

create function public.list_booking_requests()
returns table (
  id uuid,
  item_id uuid,
  item_name text,
  start_date date,
  end_date date,
  status public.booking_status,
  is_borrower boolean,
  is_item_owner boolean,
  borrower_label text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  return query
  select bookings.id, bookings.item_id, items.name, bookings.start_date,
    bookings.end_date, bookings.status,
    bookings.borrower_id = auth.uid(), items.owner_id = auth.uid(),
    case when bookings.borrower_id = auth.uid() then 'You' else 'Community member' end
  from public.bookings
  join public.items on items.id = bookings.item_id
  where public.is_active_community_member(items.community_id)
    and (bookings.borrower_id = auth.uid() or items.owner_id = auth.uid())
  order by bookings.created_at desc;
end;
$$;

revoke all on function public.request_booking(uuid, date, date) from public;
revoke all on function public.list_booking_requests() from public;
grant execute on function public.request_booking(uuid, date, date) to authenticated;
grant execute on function public.list_booking_requests() to authenticated;
