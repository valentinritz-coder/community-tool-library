-- Issue #10: participant-controlled handover/return and private condition evidence.
drop trigger enforce_booking_status_transition on public.bookings;
create or replace function public.enforce_booking_status_transition()
returns trigger language plpgsql set search_path = '' as $$
begin
  if not (
    (old.status = 'requested' and new.status in ('accepted', 'refused'))
    or (old.status = 'accepted' and new.status = 'checked_out')
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
  'Reservation lifecycle: requested bookings can be accepted/refused; participants advance accepted to checked_out to returned. Returned transactions are historical.';

alter table public.bookings drop constraint accepted_bookings_do_not_overlap;
alter table public.bookings add constraint accepted_bookings_do_not_overlap
  exclude using gist (item_id with =, daterange(start_date, end_date, '[]') with &&)
  where (status in ('accepted', 'checked_out'));

create table public.condition_reports (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete restrict,
  phase public.condition_phase not null,
  photo_path text not null unique,
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'image/webp')),
  author_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint condition_photo_path_matches_report check (
    photo_path ~ ('^' || booking_id::text || '/' || phase::text || '/' || id::text || '\.(jpg|png|webp)$')
  )
);

alter table public.condition_reports enable row level security;
revoke all on public.condition_reports from anon, authenticated;
grant select (id, booking_id, phase, photo_path, created_at)
on public.condition_reports to authenticated;

create function public.can_read_condition_report(target_booking_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.bookings b join public.items i on i.id = b.item_id
    where b.id = target_booking_id and (
      b.borrower_id = auth.uid() or i.owner_id = auth.uid()
      or public.is_active_community_admin(i.community_id)
    )
  );
$$;
revoke all on function public.can_read_condition_report(uuid) from public;
grant execute on function public.can_read_condition_report(uuid) to authenticated;

create policy "authorized users can read condition reports"
on public.condition_reports for select to authenticated
using (public.can_read_condition_report(booking_id));

create function public.advance_booking(target_booking_id uuid, expected_status public.booking_status, next_status public.booking_status)
returns table (id uuid, status public.booking_status)
language plpgsql security definer set search_path = '' as $$
declare target_booking public.bookings; owner_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if not ((expected_status = 'accepted' and next_status = 'checked_out') or
          (expected_status = 'checked_out' and next_status = 'returned')) then
    raise exception 'Invalid lifecycle action' using errcode = '22023';
  end if;
  select b.* into target_booking
  from public.bookings b
  where b.id = target_booking_id for update;
  if target_booking is null then raise exception 'Booking not found' using errcode = 'P0002'; end if;
  select i.owner_id into owner_id from public.items i where i.id = target_booking.item_id;
  -- Membership is deliberately not rechecked: the real participants must be able to
  -- complete an already accepted exchange even if membership later changes.
  if auth.uid() not in (target_booking.borrower_id, owner_id) then
    raise exception 'Only transaction participants can record this lifecycle action' using errcode = '42501';
  end if;
  if target_booking.status <> expected_status then
    raise exception 'Booking is not in the required state' using errcode = '55000';
  end if;
  update public.bookings b set status = next_status where b.id = target_booking_id
  returning b.id, b.status into id, status;
  return next;
end;
$$;
revoke all on function public.advance_booking(uuid, public.booking_status, public.booking_status) from public;

create function public.record_handover(target_booking_id uuid)
returns table (id uuid, status public.booking_status)
language sql security definer set search_path = '' as $$
  select * from public.advance_booking(target_booking_id, 'accepted', 'checked_out');
$$;
create function public.record_return(target_booking_id uuid)
returns table (id uuid, status public.booking_status)
language sql security definer set search_path = '' as $$
  select * from public.advance_booking(target_booking_id, 'checked_out', 'returned');
$$;
revoke all on function public.record_handover(uuid) from public;
revoke all on function public.record_return(uuid) from public;
grant execute on function public.record_handover(uuid) to authenticated;
grant execute on function public.record_return(uuid) to authenticated;

create function public.create_condition_report(target_booking_id uuid, report_phase public.condition_phase, photo_extension text)
returns table (id uuid, booking_id uuid, phase public.condition_phase, photo_path text, created_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare b public.bookings; owner_id uuid; report_id uuid := gen_random_uuid(); report_mime_type text; report public.condition_reports;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if photo_extension not in ('jpg', 'png', 'webp') then
    raise exception 'Photo must be JPEG, PNG, or WebP' using errcode = '22023';
  end if;
  report_mime_type := case photo_extension
    when 'jpg' then 'image/jpeg'
    when 'png' then 'image/png'
    when 'webp' then 'image/webp'
  end;
  select bookings.* into b
  from public.bookings
  where bookings.id = target_booking_id for update;
  if b is null then raise exception 'Booking not found' using errcode = 'P0002'; end if;
  select items.owner_id into owner_id from public.items where items.id = b.item_id;
  if auth.uid() not in (b.borrower_id, owner_id) then
    raise exception 'Only transaction participants can add condition evidence' using errcode = '42501';
  end if;
  if not ((report_phase = 'before' and b.status = 'accepted') or
          (report_phase = 'after' and b.status = 'checked_out')) then
    raise exception 'Condition evidence is not allowed in this booking state' using errcode = '55000';
  end if;
  insert into public.condition_reports (id, booking_id, phase, photo_path, mime_type, author_id)
  values (report_id, b.id, report_phase,
    b.id::text || '/' || report_phase::text || '/' || report_id::text || '.' || photo_extension,
    report_mime_type, auth.uid()) returning * into report;
  return query select report.id, report.booking_id, report.phase, report.photo_path, report.created_at;
end;
$$;
revoke all on function public.create_condition_report(uuid, public.condition_phase, text) from public;
grant execute on function public.create_condition_report(uuid, public.condition_phase, text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('condition-photos', 'condition-photos', false, 5242880, array['image/jpeg','image/png','image/webp']);

create policy "authorized users can read condition photos" on storage.objects
for select to authenticated using (
  bucket_id = 'condition-photos' and exists (
    select 1 from public.condition_reports r where r.photo_path = name
      and public.can_read_condition_report(r.booking_id)
  )
);
create policy "participants can upload reserved condition photos" on storage.objects
for insert to authenticated with check (
  bucket_id = 'condition-photos' and exists (
    select 1 from public.condition_reports r
    join public.bookings b on b.id = r.booking_id join public.items i on i.id = b.item_id
    where r.photo_path = name and r.author_id = auth.uid()
      and metadata->>'mimetype' = r.mime_type
      and auth.uid() in (b.borrower_id, i.owner_id)
      and ((r.phase = 'before' and b.status = 'accepted') or (r.phase = 'after' and b.status = 'checked_out'))
  )
);

-- Extend participant projections without exposing raw user identifiers.
drop function public.list_booking_requests();
create function public.list_booking_requests()
returns table (id uuid, item_id uuid, item_name text, start_date date, end_date date,
  status public.booking_status, is_borrower boolean, is_item_owner boolean,
  can_decide boolean, borrower_label text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  return query select b.id, b.item_id, i.name, b.start_date, b.end_date, b.status,
    b.borrower_id = auth.uid(), i.owner_id = auth.uid(),
    b.status = 'requested' and ((i.owner_id = auth.uid() and public.is_active_community_member(i.community_id)) or public.is_active_community_admin(i.community_id)),
    case when b.borrower_id = auth.uid() then 'You' else 'Community member' end
  from public.bookings b join public.items i on i.id = b.item_id
  where (b.borrower_id = auth.uid() or i.owner_id = auth.uid())
    or (b.status = 'requested' and public.is_active_community_admin(i.community_id))
  order by b.created_at desc;
end;
$$;
revoke all on function public.list_booking_requests() from public;
grant execute on function public.list_booking_requests() to authenticated;

drop function public.list_accepted_booking_contacts();
create function public.list_accepted_booking_contacts()
returns table (booking_id uuid, counterparty_email text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  return query select b.id, case when b.borrower_id = auth.uid() then ou.email::text else bu.email::text end
  from public.bookings b join public.items i on i.id = b.item_id
  join auth.users bu on bu.id = b.borrower_id join auth.users ou on ou.id = i.owner_id
  where b.status = 'accepted'
    and public.is_active_community_member(i.community_id)
    and (b.borrower_id = auth.uid() or i.owner_id = auth.uid());
end;
$$;
revoke all on function public.list_accepted_booking_contacts() from public;
grant execute on function public.list_accepted_booking_contacts() to authenticated;
