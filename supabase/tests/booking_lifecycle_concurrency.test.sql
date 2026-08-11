-- This test deliberately commits its synthetic fixture so two independent database
-- sessions can contend for the same booking row.
create extension if not exists dblink with schema extensions;

begin;
select plan(5);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password) values
  ('c0000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'concurrent-owner@example.test', ''),
  ('c0000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'concurrent-borrower@example.test', '');
insert into public.communities (id, name) values
  ('c1000000-0000-4000-8000-000000000001', 'Concurrency community');
insert into public.memberships (community_id, user_id, role, status) values
  ('c1000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'member', 'active'),
  ('c1000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002', 'member', 'active');
insert into public.items (id, community_id, owner_id, name, category, description, photo_path, is_free, photo_uploaded)
values ('c2000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'Concurrency drill', 'small_diy', 'Synthetic concurrent fixture', 'c2000000-0000-4000-8000-000000000001/photo.jpg', true, true);
insert into public.bookings (id, item_id, borrower_id, start_date, end_date, status)
values ('c3000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002', '2026-12-01', '2026-12-01', 'accepted');
commit;

-- Supabase's pgTAP runner connects locally without password authentication.
-- dblink_connect rejects that for a non-superuser even when a password appears
-- in the connection string. The explicitly untrusted variant is confined to
-- this test and still creates two real PostgreSQL backend sessions.
select extensions.dblink_connect_u('lifecycle_one', 'host=127.0.0.1 port=5432 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect_u('lifecycle_two', 'host=127.0.0.1 port=5432 dbname=postgres user=postgres password=postgres');
select extensions.dblink_exec('lifecycle_one', 'begin');
select * from extensions.dblink('lifecycle_one', $$select 1 from public.bookings where id = 'c3000000-0000-4000-8000-000000000001' for update$$) as result(value integer);
select extensions.dblink_exec('lifecycle_one', 'set role authenticated');
select * from extensions.dblink('lifecycle_one', $$select set_config('request.jwt.claim.sub', 'c0000000-0000-4000-8000-000000000001', false)$$) as result(value text);
select extensions.dblink_exec('lifecycle_two', 'set role authenticated');
select * from extensions.dblink('lifecycle_two', $$select set_config('request.jwt.claim.sub', 'c0000000-0000-4000-8000-000000000002', false)$$) as result(value text);

select is(
  extensions.dblink_send_query('lifecycle_two', $$select * from public.record_handover('c3000000-0000-4000-8000-000000000001')$$),
  1,
  'a second participant transition starts in an independent session'
);
select pg_sleep(0.1);
select is(extensions.dblink_is_busy('lifecycle_two'), 1, 'the concurrent transition waits on the booking row lock');
select is(
  (select status::text from extensions.dblink('lifecycle_one', $$select * from public.record_handover('c3000000-0000-4000-8000-000000000001')$$) as result(id uuid, status public.booking_status)),
  'checked_out',
  'the lock holder performs the single valid handover'
);
select extensions.dblink_exec('lifecycle_one', 'commit');
select throws_ok(
  $$select * from extensions.dblink_get_result('lifecycle_two') as result(id uuid, status public.booking_status)$$,
  '55000',
  'Booking is not in the required state',
  'the waiting transition rechecks state after acquiring the lock and is rejected'
);
select is(
  (select status::text from public.bookings where id = 'c3000000-0000-4000-8000-000000000001'),
  'checked_out',
  'concurrent handover attempts produce exactly one coherent state change'
);

select extensions.dblink_disconnect('lifecycle_one');
select extensions.dblink_disconnect('lifecycle_two');

delete from public.communities where id = 'c1000000-0000-4000-8000-000000000001';
delete from auth.users where id in ('c0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002');
select * from finish();
