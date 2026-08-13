-- Issue #38: narrow, participant-authorized booking cancellation.
drop trigger enforce_booking_status_transition on public.bookings;
create or replace function public.enforce_booking_status_transition()
returns trigger language plpgsql set search_path = '' as $$
begin
  if not (
    (old.status = 'requested' and new.status in ('accepted', 'refused', 'cancelled'))
    or (old.status = 'accepted' and new.status in ('checked_out', 'cancelled'))
    or (old.status = 'checked_out' and new.status = 'returned')
  ) then
    raise exception 'Invalid booking status transition' using errcode = '55000';
  end if;
  return new;
end;
$$;
create trigger enforce_booking_status_transition before update of status on public.bookings
for each row execute function public.enforce_booking_status_transition();

comment on table public.bookings is
  'Reservation lifecycle: requested bookings can be accepted/refused or borrower-cancelled; accepted bookings can be handed over or participant-cancelled; checked-out bookings can be returned. Returned and cancelled transactions are historical.';

create function public.cancel_booking(target_booking_id uuid)
returns table (id uuid, status public.booking_status)
language plpgsql security definer set search_path = '' as $$
declare target_booking public.bookings; owner_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select b.* into target_booking
  from public.bookings b
  where b.id = target_booking_id
  for update;
  if target_booking is null then
    raise exception 'Booking not found' using errcode = 'P0002';
  end if;

  select i.owner_id into owner_id
  from public.items i
  where i.id = target_booking.item_id;

  -- Membership is deliberately not rechecked. Cancellation is cleanup by an
  -- actual transaction participant, never an administrator-only capability.
  if target_booking.status = 'requested' then
    if auth.uid() <> target_booking.borrower_id then
      raise exception 'Only the borrower can cancel a requested booking' using errcode = '42501';
    end if;
  elsif target_booking.status = 'accepted' then
    if auth.uid() not in (target_booking.borrower_id, owner_id) then
      raise exception 'Only transaction participants can cancel an accepted booking' using errcode = '42501';
    end if;
  elsif target_booking.status = 'checked_out' then
    raise exception 'Booking cannot be cancelled after handover' using errcode = '55000';
  else
    raise exception 'Booking cannot be cancelled in its current state' using errcode = '55000';
  end if;

  update public.bookings b set status = 'cancelled'
  where b.id = target_booking_id
  returning b.id, b.status into id, status;
  return next;
end;
$$;

comment on function public.cancel_booking(uuid) is
  'Cancels a requested booking for its borrower or an accepted booking for either participant, serialized on the booking row.';
revoke all on function public.cancel_booking(uuid) from public;
grant execute on function public.cancel_booking(uuid) to authenticated;
