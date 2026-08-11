drop function public.list_booking_requests();

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
  can_decide boolean,
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
    (
      (items.owner_id = auth.uid() and public.is_active_community_member(items.community_id))
      or public.is_active_community_admin(items.community_id)
    ),
    case when bookings.borrower_id = auth.uid() then 'You' else 'Community member' end
  from public.bookings
  join public.items on items.id = bookings.item_id
  where public.is_active_community_member(items.community_id)
    and (
      bookings.borrower_id = auth.uid()
      or items.owner_id = auth.uid()
      or public.is_active_community_admin(items.community_id)
    )
  order by bookings.created_at desc;
end;
$$;

comment on function public.list_booking_requests() is
  'Privacy-safe booking status and decision-capability projection for borrowers, owners, and active same-community admins; excludes participant identifiers and contact details.';

revoke all on function public.list_booking_requests() from public;
grant execute on function public.list_booking_requests() to authenticated;

create function public.list_accepted_booking_contacts()
returns table (
  booking_id uuid,
  counterparty_email text
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
  select bookings.id,
    case
      when bookings.borrower_id = auth.uid() then owner_user.email::text
      else borrower_user.email::text
    end
  from public.bookings
  join public.items on items.id = bookings.item_id
  join auth.users as borrower_user on borrower_user.id = bookings.borrower_id
  join auth.users as owner_user on owner_user.id = items.owner_id
  where bookings.status = 'accepted'
    and public.is_active_community_member(items.community_id)
    and (bookings.borrower_id = auth.uid() or items.owner_id = auth.uid());
end;
$$;

comment on function public.list_accepted_booking_contacts() is
  'Narrow accepted-transaction projection exposing only booking id and counterparty email to an active borrower or item owner.';

revoke all on function public.list_accepted_booking_contacts() from public;
grant execute on function public.list_accepted_booking_contacts() to authenticated;
