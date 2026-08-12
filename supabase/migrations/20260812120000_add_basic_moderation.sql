create type public.moderation_target_type as enum ('item', 'counterparty');
create type public.moderation_reason as enum ('inappropriate', 'misleading', 'unsafe', 'other');
create type public.moderation_status as enum ('open', 'handled');

alter table public.items add column moderation_hidden boolean not null default false;

create table public.moderation_reports (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  target_type public.moderation_target_type not null,
  item_id uuid references public.items(id) on delete restrict,
  booking_id uuid references public.bookings(id) on delete restrict,
  target_user_id uuid references auth.users(id) on delete restrict,
  reporter_id uuid not null references auth.users(id) on delete restrict,
  reason public.moderation_reason not null,
  note text,
  status public.moderation_status not null default 'open',
  created_at timestamptz not null default now(),
  handled_at timestamptz,
  handled_by uuid references auth.users(id) on delete restrict,
  action_taken text,
  constraint moderation_target_is_consistent check (
    (target_type = 'item' and item_id is not null and booking_id is null and target_user_id is null)
    or (target_type = 'counterparty' and item_id is null and booking_id is not null and target_user_id is not null)
  ),
  constraint moderation_note_length check (note is null or char_length(note) between 1 and 500),
  constraint moderation_handling_is_consistent check (
    (status = 'open' and handled_at is null and handled_by is null and action_taken is null)
    or (status = 'handled' and handled_at is not null and handled_by is not null and action_taken is not null)
  )
);

create unique index one_open_item_report_per_reporter
on public.moderation_reports (reporter_id, item_id) where status = 'open' and item_id is not null;
create unique index one_open_counterparty_report_per_reporter
on public.moderation_reports (reporter_id, booking_id, target_user_id)
where status = 'open' and booking_id is not null;

alter table public.moderation_reports enable row level security;
revoke all on public.moderation_reports from anon, authenticated;

create function public.submit_item_report(
  target_item_id uuid, report_reason public.moderation_reason, report_note text default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare report_id uuid; normalized_note text := nullif(btrim(report_note), '');
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if report_note is not null and normalized_note is null then raise exception 'Note cannot be blank' using errcode = '22023'; end if;
  if normalized_note is not null and char_length(normalized_note) > 500 then raise exception 'Note must be 500 characters or fewer' using errcode = '22023'; end if;
  insert into public.moderation_reports (community_id, target_type, item_id, reporter_id, reason, note)
  select i.community_id, 'item', i.id, auth.uid(), report_reason, normalized_note
  from public.items i where i.id = target_item_id and i.photo_uploaded and not i.archived
    and not i.moderation_hidden and public.is_active_community_member(i.community_id)
  returning id into report_id;
  if report_id is null then raise exception 'Item is not visible to this reporter' using errcode = '42501'; end if;
  return report_id;
exception when unique_violation then raise exception 'An open report already exists for this target' using errcode = '23505';
end; $$;

create function public.submit_counterparty_report(
  target_booking_id uuid, report_reason public.moderation_reason, report_note text default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare report_id uuid; normalized_note text := nullif(btrim(report_note), '');
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if report_note is not null and normalized_note is null then raise exception 'Note cannot be blank' using errcode = '22023'; end if;
  if normalized_note is not null and char_length(normalized_note) > 500 then raise exception 'Note must be 500 characters or fewer' using errcode = '22023'; end if;
  insert into public.moderation_reports (community_id, target_type, booking_id, target_user_id, reporter_id, reason, note)
  select i.community_id, 'counterparty', b.id,
    case when b.borrower_id = auth.uid() then i.owner_id else b.borrower_id end,
    auth.uid(), report_reason, normalized_note
  from public.bookings b join public.items i on i.id = b.item_id
  where b.id = target_booking_id and (b.borrower_id = auth.uid() or i.owner_id = auth.uid())
    and b.borrower_id <> i.owner_id;
  if report_id is null then raise exception 'Only a booking participant can report its counterparty' using errcode = '42501'; end if;
  return report_id;
exception when unique_violation then raise exception 'An open report already exists for this target' using errcode = '23505';
end; $$;

create function public.list_moderation_reports(target_community_id uuid)
returns table (id uuid, target_type public.moderation_target_type, target_label text,
  item_id uuid, reason public.moderation_reason, note text, status public.moderation_status,
  created_at timestamptz, action_taken text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_active_community_admin(target_community_id) then
    raise exception 'Active same-community admin required' using errcode = '42501';
  end if;
  return query select r.id, r.target_type,
    case when r.target_type = 'item' then coalesce(i.name, 'Item') else 'Transaction counterparty' end,
    r.item_id, r.reason, r.note, r.status, r.created_at, r.action_taken
  from public.moderation_reports r left join public.items i on i.id = r.item_id
  where r.community_id = target_community_id order by r.created_at desc;
end; $$;

create function public.handle_moderation_report(target_report_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare report_community uuid;
begin
  select community_id into report_community from public.moderation_reports where id = target_report_id;
  if report_community is null or not public.is_active_community_admin(report_community) then
    raise exception 'Active same-community admin required' using errcode = '42501';
  end if;
  update public.moderation_reports set status = 'handled', handled_at = now(), handled_by = auth.uid(), action_taken = 'reviewed'
  where id = target_report_id and status = 'open';
  if not found then raise exception 'Report is already handled' using errcode = '22023'; end if;
end; $$;

create function public.hide_reported_item(target_report_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare report_item uuid; report_community uuid;
begin
  select item_id, community_id into report_item, report_community from public.moderation_reports
  where id = target_report_id and target_type = 'item';
  if report_item is null or not public.is_active_community_admin(report_community) then
    raise exception 'Active same-community admin and item report required' using errcode = '42501';
  end if;
  update public.items set moderation_hidden = true where id = report_item;
  update public.moderation_reports set status = 'handled', handled_at = coalesce(handled_at, now()),
    handled_by = coalesce(handled_by, auth.uid()), action_taken = 'item hidden' where id = target_report_id;
end; $$;

revoke all on function public.submit_item_report(uuid, public.moderation_reason, text), public.submit_counterparty_report(uuid, public.moderation_reason, text), public.list_moderation_reports(uuid), public.handle_moderation_report(uuid), public.hide_reported_item(uuid) from public;
grant execute on function public.submit_item_report(uuid, public.moderation_reason, text), public.submit_counterparty_report(uuid, public.moderation_reason, text), public.list_moderation_reports(uuid), public.handle_moderation_report(uuid), public.hide_reported_item(uuid) to authenticated;

drop function public.browse_community_inventory(uuid);
create function public.browse_community_inventory(target_community_id uuid)
returns table (id uuid, community_id uuid, name text, category public.item_category, description text,
 photo_path text, is_free boolean, price_per_day_cents integer, is_owned boolean, availability_summary text)
language plpgsql stable security definer set search_path = '' as $$
begin
 if not public.is_active_community_member(target_community_id) then raise exception 'Active community membership required' using errcode = '42501'; end if;
 return query select i.id,i.community_id,i.name,i.category,i.description,i.photo_path,i.is_free,i.price_per_day_cents,i.owner_id=auth.uid(),
 coalesce((select 'Available only '||string_agg(case when a.start_date=a.end_date then 'on '||a.start_date::text else 'from '||a.start_date::text||' through '||a.end_date::text end,'; ' order by a.start_date,a.end_date) from public.availabilities a where a.item_id=i.id),'Unavailable: the owner has not added available dates.')
 from public.items i where i.community_id=target_community_id and i.photo_uploaded and not i.archived and not i.moderation_hidden order by i.created_at desc;
end; $$;
revoke all on function public.browse_community_inventory(uuid) from public;
grant execute on function public.browse_community_inventory(uuid) to authenticated;

create or replace function public.can_read_inventory_photo(object_name text) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.items i where i.photo_path=object_name and i.photo_uploaded
 and not i.moderation_hidden and public.is_active_community_member(i.community_id) and (not i.archived or i.owner_id=auth.uid()));
$$;
