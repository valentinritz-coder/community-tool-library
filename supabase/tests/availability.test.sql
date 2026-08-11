begin;

select plan(35);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password)
values
  ('70000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'availability-owner@example.test', ''),
  ('70000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'availability-member@example.test', ''),
  ('70000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'availability-pending@example.test', ''),
  ('70000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'availability-outsider@example.test', ''),
  ('70000000-0000-4000-8000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'availability-cross-community@example.test', '');

insert into public.communities (id, name) values
  ('71000000-0000-4000-8000-000000000001', 'Availability community'),
  ('71000000-0000-4000-8000-000000000002', 'Other availability community');
insert into public.memberships (community_id, user_id, role, status) values
  ('71000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', 'member', 'active'),
  ('71000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000002', 'member', 'active'),
  ('71000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000003', 'member', 'pending'),
  ('71000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000005', 'member', 'active');
insert into public.items (
  id, community_id, owner_id, name, category, description, photo_path,
  is_free, photo_uploaded
) values (
  '72000000-0000-4000-8000-000000000001',
  '71000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000001',
  'Date-only drill', 'small_diy', 'Synthetic availability fixture',
  '72000000-0000-4000-8000-000000000001/photo.jpg', true, true
), (
  '72000000-0000-4000-8000-000000000002',
  '71000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000001',
  'Unset drill', 'small_diy', 'Synthetic unset fixture',
  '72000000-0000-4000-8000-000000000002/photo.jpg', true, true
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000001', true);

select lives_ok(
  $$insert into public.availabilities (item_id, start_date, end_date)
    values ('72000000-0000-4000-8000-000000000001', '2026-08-11', '2026-08-15')$$,
  'an active owner can create an inclusive valid range'
);
select lives_ok(
  $$insert into public.availabilities (item_id, start_date, end_date)
    values ('72000000-0000-4000-8000-000000000001', '2026-08-20', '2026-08-20')$$,
  'a one-day inclusive range is valid'
);
select ok(
  exists (
    select 1 from public.availabilities
    where start_date = '2026-08-20'
      and '2026-08-20' between start_date and end_date
  ),
  'the only date in a one-day range is available'
);
select is((select count(*) from public.availabilities), 2::bigint, 'the owner can read their ranges');
select lives_ok(
  $$update public.availabilities set end_date = '2026-08-21' where start_date = '2026-08-20'$$,
  'the owner can update a range'
);
select lives_ok(
  $$delete from public.availabilities where start_date = '2026-08-20'$$,
  'the owner can delete a range'
);
select throws_ok(
  $$insert into public.availabilities (item_id, start_date, end_date)
    values ('72000000-0000-4000-8000-000000000001', '2026-08-12', '2026-08-13')$$,
  '23P01', 'conflicting key value violates exclusion constraint "availability_ranges_do_not_overlap"',
  'contradictory overlapping ranges are rejected'
);
select throws_ok(
  $$insert into public.availabilities (item_id, start_date, end_date)
    values ('72000000-0000-4000-8000-000000000001', '2026-08-15', '2026-08-16')$$,
  '23P01', 'conflicting key value violates exclusion constraint "availability_ranges_do_not_overlap"',
  'inclusive ranges cannot overlap at an endpoint'
);
select throws_ok(
  $$insert into public.availabilities (item_id, start_date, end_date)
    values ('72000000-0000-4000-8000-000000000001', '2026-09-02', '2026-09-01')$$,
  '23514', 'new row for relation "availabilities" violates check constraint "availability_dates_in_order"',
  'a reversed range is rejected by the database'
);
select throws_ok(
  $$insert into public.availabilities (item_id, start_date, end_date)
    values ('72000000-0000-4000-8000-000000000001', '-infinity', '2026-08-01')$$,
  '23514', 'new row for relation "availabilities" violates check constraint "availability_dates_are_finite"',
  'negative infinity is not a calendar date'
);
select throws_ok(
  $$insert into public.availabilities (item_id, start_date, end_date)
    values ('72000000-0000-4000-8000-000000000001', '2026-09-01', 'infinity')$$,
  '23514', 'new row for relation "availabilities" violates check constraint "availability_dates_are_finite"',
  'positive infinity is not a calendar date'
);
select ok(
  exists (
    select 1 from public.availabilities
    where item_id = '72000000-0000-4000-8000-000000000001'
      and '2026-08-12' between start_date and end_date
  ),
  'a date inside a range is available'
);
select ok(
  exists (
    select 1 from public.availabilities
    where item_id = '72000000-0000-4000-8000-000000000001'
      and '2026-08-11' between start_date and end_date
  ),
  'the inclusive start date is available'
);
select ok(
  exists (
    select 1 from public.availabilities
    where item_id = '72000000-0000-4000-8000-000000000001'
      and '2026-08-15' between start_date and end_date
  ),
  'the inclusive end date is available'
);
select ok(
  not exists (
    select 1 from public.availabilities
    where item_id = '72000000-0000-4000-8000-000000000001'
      and '2026-08-16' between start_date and end_date
  ),
  'a date outside every range is unavailable by default'
);
select ok(
  not exists (
    select 1 from public.availabilities
    where item_id = '72000000-0000-4000-8000-000000000002'
      and '2026-08-12' between start_date and end_date
  ),
  'an item without ranges is unavailable by default'
);
select set_config('TimeZone', 'Pacific/Auckland', true);
select is((select start_date::text from public.availabilities), '2026-08-11', 'calendar dates are unchanged in a positive-offset timezone');
select set_config('TimeZone', 'America/Los_Angeles', true);
select is((select end_date::text from public.availabilities), '2026-08-15', 'calendar dates are unchanged in a negative-offset timezone');

select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.availabilities), 0::bigint, 'a same-community member cannot read owner management rows');
select is(
  (select availability_summary from public.browse_community_inventory('71000000-0000-4000-8000-000000000001') where id = '72000000-0000-4000-8000-000000000001'),
  'Available only from 2026-08-11 through 2026-08-15',
  'an active member receives an understandable availability summary'
);
select is(
  (select availability_summary from public.browse_community_inventory('71000000-0000-4000-8000-000000000001') where id = '72000000-0000-4000-8000-000000000002'),
  'Unavailable: the owner has not added available dates.',
  'an item without rules has an honest summary'
);
select throws_ok(
  $$select owner_id from public.browse_community_inventory('71000000-0000-4000-8000-000000000001')$$,
  '42703', 'column "owner_id" does not exist',
  'the borrower projection still exposes no owner id'
);
select throws_ok(
  $$insert into public.availabilities (item_id, start_date, end_date)
    values ('72000000-0000-4000-8000-000000000001', '2026-09-01', '2026-09-02')$$,
  '42501', 'new row violates row-level security policy for table "availabilities"',
  'a same-community non-owner cannot create a range'
);
select is_empty($$update public.availabilities set end_date = '2026-08-16' returning 1$$, 'a same-community non-owner cannot update a range');
select is_empty($$delete from public.availabilities returning 1$$, 'a same-community non-owner cannot delete a range');

select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000003', true);
select throws_ok(
  $$insert into public.availabilities (item_id, start_date, end_date)
    values ('72000000-0000-4000-8000-000000000001', '2026-09-01', '2026-09-02')$$,
  '42501', 'new row violates row-level security policy for table "availabilities"',
  'a pending member cannot create a range'
);
select is_empty($$update public.availabilities set end_date = '2026-08-16' returning 1$$, 'a pending member cannot update a range');

select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000004', true);
select throws_ok(
  $$insert into public.availabilities (item_id, start_date, end_date)
    values ('72000000-0000-4000-8000-000000000001', '2026-09-01', '2026-09-02')$$,
  '42501', 'new row violates row-level security policy for table "availabilities"',
  'a non-member cannot create a range'
);
select is_empty($$delete from public.availabilities returning 1$$, 'a non-member cannot delete a range');

select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000005', true);
select throws_ok(
  $$insert into public.availabilities (item_id, start_date, end_date)
    values ('72000000-0000-4000-8000-000000000001', '2026-09-01', '2026-09-02')$$,
  '42501', 'new row violates row-level security policy for table "availabilities"',
  'an active cross-community member cannot create a range'
);
select is_empty($$update public.availabilities set end_date = '2026-08-16' returning 1$$, 'a cross-community member cannot update a range');
select throws_ok(
  $$insert into public.availabilities (item_id, start_date, end_date)
    values ('72000000-0000-4000-8000-000000000099', '2026-09-01', '2026-09-02')$$,
  '42501', 'new row violates row-level security policy for table "availabilities"',
  'a forged item id cannot bypass authorization'
);
select throws_ok(
  $$select * from public.browse_community_inventory('71000000-0000-4000-8000-000000000001')$$,
  '42501', 'Active community membership required',
  'a cross-community member cannot request the availability projection'
);

select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000001', true);
select is((select item_id from public.availabilities limit 1), '72000000-0000-4000-8000-000000000001'::uuid, 'availability remains tied to the real item');
select is((select count(*) from public.availabilities), 1::bigint, 'denied mutations leave the owner data intact');

select * from finish();
rollback;
