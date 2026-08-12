\set ON_ERROR_STOP on

\if :{?community_id}
\else
  \echo 'community_id is required'
  do $$ begin raise exception 'community_id is required'; end $$;
\endif
\if :{?window_start}
\else
  \echo 'window_start is required'
  do $$ begin raise exception 'window_start is required'; end $$;
\endif
\if :{?window_end}
\else
  \echo 'window_end is required'
  do $$ begin raise exception 'window_end is required'; end $$;
\endif

with scoped_items as (
  select * from public.items where community_id = :'community_id'::uuid
), window_bookings as (
  select b.* from public.bookings b join scoped_items i on i.id=b.item_id
  where b.created_at >= :'window_start'::timestamptz and b.created_at < :'window_end'::timestamptz
), eligible_window_items as (
  select * from scoped_items where created_at >= :'window_start'::timestamptz
    and created_at < :'window_end'::timestamptz and photo_uploaded and not archived and not moderation_hidden
), completed_window_bookings as (
  select b.*,i.owner_id from window_bookings b join scoped_items i on i.id=b.item_id
  where b.status='returned'
), owner_counts as (
  select owner_id,count(*) n from completed_window_bookings group by owner_id
), borrower_counts as (
  select borrower_id,count(*) n from completed_window_bookings group by borrower_id
), report_count as (
  select count(*)::numeric n from public.moderation_reports
  where community_id=:'community_id'::uuid and created_at >= :'window_start'::timestamptz
    and created_at < :'window_end'::timestamptz
), request_count as (select count(*)::numeric n from window_bookings)
select
 (select count(distinct user_id) from public.memberships where community_id=:'community_id'::uuid and status='active') active_members_snapshot,
 (select count(*) from eligible_window_items) listings,
 null::bigint searches_not_currently_calculable,
 null::bigint useful_result_searches_not_currently_calculable,
 (select n from request_count) booking_requests,
 (select count(*) from window_bookings where status in ('accepted','checked_out','returned')) accepted_bookings,
 (select count(*) from window_bookings where status='returned') completed_exchanges,
 (select count(*) from owner_counts where n>=2) repeat_owners,
 (select count(*) from borrower_counts where n>=2) repeat_borrowers,
 null::bigint incidents_not_currently_calculable,
 (select n from report_count) moderation_reports,
 round((select count(*) from window_bookings where status in ('accepted','checked_out','returned'))::numeric/nullif((select n from request_count),0),4) accepted_request_ratio,
 round((select count(*) from window_bookings where status='returned')::numeric/nullif((select n from request_count),0),4) completed_request_ratio,
 round((select count(*) from owner_counts where n>=2)::numeric/nullif((select count(*) from owner_counts),0),4) repeat_owner_share,
 round((select count(*) from borrower_counts where n>=2)::numeric/nullif((select count(*) from borrower_counts),0),4) repeat_borrower_share;
