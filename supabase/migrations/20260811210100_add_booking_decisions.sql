alter table public.bookings
  add constraint accepted_bookings_do_not_overlap
  exclude using gist (
    item_id with =,
    daterange(start_date, end_date, '[]') with &&
  ) where (status = 'accepted');

comment on table public.bookings is
  'Reservation requests. Requested rows are non-exclusive; accepted date ranges are exclusive; accepted and refused decisions are terminal.';

create function public.enforce_booking_status_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status <> 'requested' or new.status not in ('accepted', 'refused') then
    raise exception 'Invalid booking status transition' using errcode = '55000';
  end if;
  return new;
end;
$$;

create trigger enforce_booking_status_transition
before update of status on public.bookings
for each row execute function public.enforce_booking_status_transition();

revoke all on function public.enforce_booking_status_transition() from public;

create or replace function public.request_booking(
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
      select range_agg(daterange(availability.start_date, availability.end_date, '[]'))
        @> daterange(requested_start_date, requested_end_date, '[]')
      from public.availabilities as availability
      where availability.item_id = target_item_id
    ),
    false
  ) then
    raise exception 'The requested dates are not fully available' using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.bookings
    where bookings.item_id = target_item_id
      and bookings.status = 'accepted'
      and daterange(bookings.start_date, bookings.end_date, '[]')
        && daterange(requested_start_date, requested_end_date, '[]')
  ) then
    raise exception 'These dates conflict with another accepted booking' using errcode = '23P01';
  end if;

  insert into public.bookings (item_id, borrower_id, start_date, end_date, status)
  values (target_item_id, auth.uid(), requested_start_date, requested_end_date, 'requested')
  returning * into new_booking;

  return query select new_booking.id, new_booking.item_id, new_booking.start_date,
    new_booking.end_date, new_booking.status;
end;
$$;

create function public.decide_booking(
  target_booking_id uuid,
  decision public.booking_status
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
  target_booking public.bookings;
  target_item public.items;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if decision is null or decision not in ('accepted', 'refused') then
    raise exception 'Decision must be accepted or refused' using errcode = '22023';
  end if;

  select * into target_booking
  from public.bookings
  where bookings.id = target_booking_id
  for update;

  if target_booking is null then
    raise exception 'Booking request not found' using errcode = 'P0002';
  end if;

  select * into target_item
  from public.items
  where items.id = target_booking.item_id;

  if target_item is null then
    raise exception 'Booking request is no longer valid' using errcode = '22023';
  end if;

  if not (
    (
      target_item.owner_id = auth.uid()
      and public.is_active_community_member(target_item.community_id)
    )
    or public.is_active_community_admin(target_item.community_id)
  ) then
    raise exception 'Only the item owner or an active community admin can decide this request'
      using errcode = '42501';
  end if;

  if target_booking.status <> 'requested' then
    raise exception 'This booking request has already been decided' using errcode = '55000';
  end if;

  if decision = 'accepted' then
    if target_item.archived or not target_item.photo_uploaded
      or target_booking.start_date is null or target_booking.end_date is null
      or not isfinite(target_booking.start_date) or not isfinite(target_booking.end_date)
      or target_booking.start_date > target_booking.end_date then
      raise exception 'Booking request is no longer valid' using errcode = '22023';
    end if;

    if not coalesce(
      (
        select range_agg(daterange(availability.start_date, availability.end_date, '[]'))
          @> daterange(target_booking.start_date, target_booking.end_date, '[]')
        from public.availabilities as availability
        where availability.item_id = target_booking.item_id
      ),
      false
    ) then
      raise exception 'The requested dates are no longer fully available' using errcode = '22023';
    end if;
  end if;

  begin
    update public.bookings
    set status = decision
    where bookings.id = target_booking.id
    returning * into target_booking;
  exception
    when exclusion_violation then
      raise exception 'These dates conflict with another accepted booking' using errcode = '23P01';
  end;

  return query select target_booking.id, target_booking.item_id, target_booking.start_date,
    target_booking.end_date, target_booking.status;
end;
$$;

revoke all on function public.decide_booking(uuid, public.booking_status) from public;
grant execute on function public.decide_booking(uuid, public.booking_status) to authenticated;
