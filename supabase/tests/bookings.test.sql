begin;

select plan(39);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password) values
  ('80000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@example.test', ''),
  ('80000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'borrower@example.test', ''),
  ('80000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pending@example.test', ''),
  ('80000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'outsider@example.test', ''),
  ('80000000-0000-4000-8000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cross@example.test', ''),
  ('80000000-0000-4000-8000-000000000006', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'other-owner@example.test', '');
insert into public.communities (id, name) values
  ('81000000-0000-4000-8000-000000000001', 'Booking community'),
  ('81000000-0000-4000-8000-000000000002', 'Other booking community');
insert into public.memberships (community_id, user_id, role, status) values
  ('81000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 'member', 'active'),
  ('81000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000002', 'member', 'active'),
  ('81000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000003', 'member', 'pending'),
  ('81000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000006', 'member', 'active'),
  ('81000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000005', 'member', 'active');
insert into public.items (id, community_id, owner_id, name, category, description, photo_path, is_free, photo_uploaded, archived) values
  ('82000000-0000-4000-8000-000000000001', '81000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 'Available drill', 'small_diy', 'Synthetic fixture', '82000000-0000-4000-8000-000000000001/photo.jpg', true, true, false),
  ('82000000-0000-4000-8000-000000000002', '81000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 'No dates drill', 'small_diy', 'Synthetic fixture', '82000000-0000-4000-8000-000000000002/photo.jpg', true, true, false),
  ('82000000-0000-4000-8000-000000000003', '81000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 'Draft drill', 'small_diy', 'Synthetic fixture', '82000000-0000-4000-8000-000000000003/photo.jpg', true, false, false),
  ('82000000-0000-4000-8000-000000000004', '81000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 'Archived drill', 'small_diy', 'Synthetic fixture', '82000000-0000-4000-8000-000000000004/photo.jpg', true, true, true);
insert into public.availabilities (item_id, start_date, end_date) values
  ('82000000-0000-4000-8000-000000000001', '2026-08-10', '2026-08-12'),
  ('82000000-0000-4000-8000-000000000001', '2026-08-13', '2026-08-15'),
  ('82000000-0000-4000-8000-000000000001', '2026-08-17', '2026-08-18'),
  ('82000000-0000-4000-8000-000000000003', '2026-08-10', '2026-08-18'),
  ('82000000-0000-4000-8000-000000000004', '2026-08-10', '2026-08-18');

set local role authenticated;
select set_config('request.jwt.claim.sub', '80000000-0000-4000-8000-000000000002', true);

select lives_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-10', '2026-08-10')$$, 'a one-day request is accepted');
select lives_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-10', '2026-08-15')$$, 'inclusive boundaries and adjacent availability ranges cover a request');
select lives_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-11', '2026-08-14')$$, 'a fully available range is accepted');
select is((select count(*) from public.list_booking_requests()), 3::bigint, 'the borrower sees their minimal requests');
select is((select status::text from public.list_booking_requests() limit 1), 'requested', 'the server fixes the initial status to requested');
select ok((select bool_and(is_borrower and not is_item_owner) from public.list_booking_requests()), 'the projection identifies the borrower perspective without ids');

reset role;
select is((select count(*) from public.bookings where borrower_id = '80000000-0000-4000-8000-000000000002'), 3::bigint, 'borrower_id is always auth.uid()');
set local role authenticated;
select set_config('request.jwt.claim.sub', '80000000-0000-4000-8000-000000000002', true);

select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-15', '2026-08-14')$$, '22023', 'The end date must be on or after the start date', 'an inverted range is rejected');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', 'not-a-date', '2026-08-14')$$, '22007', null, 'an invalid start date is rejected at the PostgreSQL boundary');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', null, '2026-08-14')$$, '22023', 'Choose both a start date and an end date', 'a missing start date is rejected');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-14', null)$$, '22023', 'Choose both a start date and an end date', 'a missing end date is rejected');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '-infinity', '2026-08-14')$$, '22023', 'Booking dates must be finite calendar dates', 'negative infinity is rejected');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-14', 'infinity')$$, '22023', 'Booking dates must be finite calendar dates', 'positive infinity is rejected');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-09', '2026-08-10')$$, '22023', 'The requested dates are not fully available', 'a range starting outside availability is rejected');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-15', '2026-08-16')$$, '22023', 'The requested dates are not fully available', 'a request exceeding an availability boundary is rejected');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-15', '2026-08-17')$$, '22023', 'The requested dates are not fully available', 'one unavailable day between ranges rejects the request');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000002', '2026-08-10', '2026-08-10')$$, '22023', 'The requested dates are not fully available', 'an item without availability is unavailable');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '0001-01-01', '9999-12-31')$$, '22023', 'The requested dates are not fully available', 'a very large uncovered request is rejected without enumerating its days');
select is(
  position('generate_series' in pg_get_functiondef('public.request_booking(uuid,date,date)'::regprocedure)),
  0,
  'booking availability validation does not enumerate requested days'
);
select lives_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-11', '2026-08-14')$$, 'overlapping requested bookings remain non-exclusive');

select throws_ok($$insert into public.bookings (item_id, borrower_id, start_date, end_date) values ('82000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', '2026-08-10', '2026-08-10')$$, '42501', null, 'a client cannot choose borrower_id with direct insert');
select is(
  (select pg_get_function_identity_arguments('public.request_booking(uuid,date,date)'::regprocedure)),
  'target_item_id uuid, requested_start_date date, requested_end_date date',
  'the RPC accepts no borrower or status supplied by the client'
);
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000099', '2026-08-10', '2026-08-10')$$, '42501', 'This item is not available to request', 'a forged item id proves no access');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000003', '2026-08-10', '2026-08-10')$$, '42501', 'This item is not available to request', 'a draft item cannot be requested');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000004', '2026-08-10', '2026-08-10')$$, '42501', 'This item is not available to request', 'an archived item cannot be requested');

select set_config('request.jwt.claim.sub', '80000000-0000-4000-8000-000000000003', true);
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-10', '2026-08-10')$$, '42501', 'This item is not available to request', 'a pending member cannot request');
select set_config('request.jwt.claim.sub', '80000000-0000-4000-8000-000000000004', true);
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-10', '2026-08-10')$$, '42501', 'This item is not available to request', 'a non-member cannot request');
select is((select count(*) from public.list_booking_requests()), 0::bigint, 'a non-member sees no requests');
select set_config('request.jwt.claim.sub', '80000000-0000-4000-8000-000000000005', true);
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-10', '2026-08-10')$$, '42501', 'This item is not available to request', 'a cross-community member cannot request');
select is((select count(*) from public.list_booking_requests()), 0::bigint, 'a cross-community member sees no requests');

select set_config('request.jwt.claim.sub', '80000000-0000-4000-8000-000000000001', true);
select is((select count(*) from public.list_booking_requests()), 4::bigint, 'the item owner sees pending requests');
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-10', '2026-08-10')$$, '42501', 'This item is not available to request', 'an active owner cannot request their own published available item');
select is((select count(*) from public.list_booking_requests()), 4::bigint, 'a denied self-request creates no booking');
select is((select borrower_label from public.list_booking_requests() limit 1), 'Community member', 'the owner gets only a generic borrower label');
select throws_ok($$select borrower_id from public.list_booking_requests()$$, '42703', 'column "borrower_id" does not exist', 'owner projection excludes the raw auth UUID');
select throws_ok($$select email from public.list_booking_requests()$$, '42703', 'column "email" does not exist', 'owner projection excludes contact details');
select throws_ok($$select pickup from public.list_booking_requests()$$, '42703', 'column "pickup" does not exist', 'owner projection excludes pickup details');

select set_config('request.jwt.claim.sub', '80000000-0000-4000-8000-000000000006', true);
select is((select count(*) from public.list_booking_requests()), 0::bigint, 'another owner cannot see requests for items they do not own');

reset role;
set local role anon;
select throws_ok($$select * from public.request_booking('82000000-0000-4000-8000-000000000001', '2026-08-10', '2026-08-10')$$, '42501', null, 'an unauthenticated client cannot execute the booking RPC');

select * from finish();
rollback;
