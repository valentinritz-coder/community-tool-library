begin;

select no_plan();

insert into auth.users (id, instance_id, aud, role, email, encrypted_password) values
  ('90000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'decision-owner@example.test', ''),
  ('90000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'decision-borrower-a@example.test', ''),
  ('90000000-0000-4000-8000-000000000003', '00000000-0000-0000-8000-000000000000', 'authenticated', 'authenticated', 'decision-borrower-b@example.test', ''),
  ('90000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'decision-admin@example.test', ''),
  ('90000000-0000-4000-8000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'decision-member@example.test', ''),
  ('90000000-0000-4000-8000-000000000006', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'decision-pending-admin@example.test', ''),
  ('90000000-0000-4000-8000-000000000007', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'decision-outsider@example.test', ''),
  ('90000000-0000-4000-8000-000000000008', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'decision-cross-admin@example.test', ''),
  ('90000000-0000-4000-8000-000000000009', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'decision-pending-member@example.test', '');

insert into public.communities (id, name, owner_id) values
  ('91000000-0000-4000-8000-000000000001', 'Decision community', '90000000-0000-4000-8000-000000000004'),
  ('91000000-0000-4000-8000-000000000002', 'Cross decision community', '90000000-0000-4000-8000-000000000008');

insert into public.memberships (community_id, user_id, role, status) values
  ('91000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000001', 'member', 'active'),
  ('91000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002', 'member', 'active'),
  ('91000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000003', 'member', 'active'),
  ('91000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000004', 'admin', 'active'),
  ('91000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000005', 'member', 'active'),
  ('91000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000006', 'admin', 'pending'),
  ('91000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000009', 'member', 'pending'),
  ('91000000-0000-4000-8000-000000000002', '90000000-0000-4000-8000-000000000008', 'admin', 'active');

insert into public.items (id, community_id, owner_id, name, category, description, photo_path, is_free, photo_uploaded, archived) values
  ('92000000-0000-4000-8000-000000000001', '91000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000001', 'Decision drill', 'small_diy', 'Synthetic decision fixture', '92000000-0000-4000-8000-000000000001/photo.jpg', true, true, false),
  ('92000000-0000-4000-8000-000000000002', '91000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000001', 'Changing availability drill', 'small_diy', 'Synthetic revalidation fixture', '92000000-0000-4000-8000-000000000002/photo.jpg', true, true, false);

insert into public.availabilities (item_id, start_date, end_date) values
  ('92000000-0000-4000-8000-000000000001', '2026-09-01', '2026-09-30'),
  ('92000000-0000-4000-8000-000000000002', '2026-09-01', '2026-09-30');

insert into public.bookings (id, item_id, borrower_id, start_date, end_date) values
  ('93000000-0000-4000-8000-000000000001', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002', '2026-09-01', '2026-09-02'),
  ('93000000-0000-4000-8000-000000000002', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002', '2026-09-04', '2026-09-05'),
  ('93000000-0000-4000-8000-000000000003', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002', '2026-09-07', '2026-09-08'),
  ('93000000-0000-4000-8000-000000000004', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002', '2026-09-10', '2026-09-11'),
  ('93000000-0000-4000-8000-000000000005', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002', '2026-09-13', '2026-09-14'),
  ('93000000-0000-4000-8000-000000000006', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002', '2026-09-16', '2026-09-17'),
  ('93000000-0000-4000-8000-000000000007', '92000000-0000-4000-8000-000000000002', '90000000-0000-4000-8000-000000000002', '2026-09-20', '2026-09-21');

set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000001', true);

select is((select status::text from public.decide_booking('93000000-0000-4000-8000-000000000001', 'accepted')), 'accepted', 'the active item owner accepts a requested booking');
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000001', 'accepted')$$, '55000', 'This booking request has already been decided', 'accepted cannot be accepted again');
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000001', 'refused')$$, '55000', 'This booking request has already been decided', 'accepted cannot become refused');
select is((select status::text from public.decide_booking('93000000-0000-4000-8000-000000000002', 'refused')), 'refused', 'the active item owner refuses a requested booking');
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000002', 'accepted')$$, '55000', 'This booking request has already been decided', 'refused cannot become accepted');
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000002', 'refused')$$, '55000', 'This booking request has already been decided', 'refused cannot be refused again');
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000003', 'requested')$$, '22023', 'Decision must be accepted or refused', 'the RPC rejects requested as a decision');
select throws_ok($$update public.bookings set status = 'refused' where id = '93000000-0000-4000-8000-000000000003'$$, '42501', null, 'an authenticated client cannot update booking status directly');

select set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000004', true);
select is((select status::text from public.decide_booking('93000000-0000-4000-8000-000000000003', 'accepted')), 'accepted', 'an active same-community admin accepts');
select is((select status::text from public.decide_booking('93000000-0000-4000-8000-000000000004', 'refused')), 'refused', 'an active same-community admin refuses');

select set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000005', true);
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000005', 'accepted')$$, '42501', 'Only the item owner or an active community admin can decide this request', 'an active non-owner member cannot decide');
select set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000006', true);
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000005', 'accepted')$$, '42501', 'Only the item owner or an active community admin can decide this request', 'a pending admin cannot decide');
select set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000009', true);
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000005', 'accepted')$$, '42501', 'Only the item owner or an active community admin can decide this request', 'a pending member cannot decide');
select set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000007', true);
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000005', 'accepted')$$, '42501', 'Only the item owner or an active community admin can decide this request', 'a non-member cannot decide');
select set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000008', true);
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000005', 'accepted')$$, '42501', 'Only the item owner or an active community admin can decide this request', 'an active cross-community admin cannot decide');

reset role;
set local role anon;
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000005', 'accepted')$$, '42501', null, 'an unauthenticated client cannot execute the decision RPC');
reset role;

delete from public.availabilities where item_id = '92000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000001', true);
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000007', 'accepted')$$, '22023', 'The requested dates are no longer fully available', 'acceptance revalidates current availability');
reset role;
select is((select status::text from public.bookings where id = '93000000-0000-4000-8000-000000000007'), 'requested', 'failed revalidation leaves the request requested');

update public.items set archived = true where id = '92000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000001', true);
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000006', 'accepted')$$, '22023', 'Booking request is no longer valid', 'an archived item cannot have a request accepted');
reset role;
select is((select status::text from public.bookings where id = '93000000-0000-4000-8000-000000000006'), 'requested', 'failed item revalidation leaves the request requested');
update public.items set archived = false where id = '92000000-0000-4000-8000-000000000001';

select throws_ok($$update public.bookings set status = 'requested' where id = '93000000-0000-4000-8000-000000000001'$$, '55000', 'Invalid booking status transition', 'the database rejects accepted to requested even for a privileged writer');
select throws_ok($$update public.bookings set status = 'accepted' where id = '93000000-0000-4000-8000-000000000002'$$, '55000', 'Invalid booking status transition', 'the database rejects refused to accepted even for a privileged writer');

select lives_ok($$insert into public.bookings (id, item_id, borrower_id, start_date, end_date, status) values ('93000000-0000-4000-8000-000000000020', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002', '2026-09-20', '2026-09-21', 'accepted')$$, 'one accepted booking can occupy a range');
select lives_ok($$insert into public.bookings (id, item_id, borrower_id, start_date, end_date, status) values ('93000000-0000-4000-8000-000000000021', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000003', '2026-09-22', '2026-09-23', 'accepted')$$, 'a disjoint accepted booking is allowed');
select throws_ok($$insert into public.bookings (id, item_id, borrower_id, start_date, end_date, status) values ('93000000-0000-4000-8000-000000000022', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000003', '2026-09-19', '2026-09-20', 'accepted')$$, '23P01', null, 'accepted ranges cannot overlap');
select throws_ok($$insert into public.bookings (id, item_id, borrower_id, start_date, end_date, status) values ('93000000-0000-4000-8000-000000000023', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000003', '2026-09-23', '2026-09-24', 'accepted')$$, '23P01', null, 'accepted ranges sharing an inclusive boundary conflict');
select lives_ok($$insert into public.bookings (id, item_id, borrower_id, start_date, end_date) values ('93000000-0000-4000-8000-000000000024', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002', '2026-09-25', '2026-09-27'), ('93000000-0000-4000-8000-000000000025', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000003', '2026-09-26', '2026-09-28')$$, 'overlapping requested bookings remain allowed');
select is((select count(*) from pg_constraint where conname = 'accepted_bookings_do_not_overlap' and contype = 'x'), 1::bigint, 'the accepted overlap invariant is an exclusion constraint');

set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000002', true);
select throws_ok($$select * from public.request_booking('92000000-0000-4000-8000-000000000001', '2026-09-20', '2026-09-22')$$, '23P01', 'These dates conflict with another accepted booking', 'a new request overlapping accepted dates is rejected cleanly');
select lives_ok($$select * from public.request_booking('92000000-0000-4000-8000-000000000001', '2026-09-24', '2026-09-24')$$, 'a new disjoint and available request succeeds');
select lives_ok($$select * from public.request_booking('92000000-0000-4000-8000-000000000001', '2026-09-26', '2026-09-27')$$, 'an existing requested booking does not block another request');
reset role;

insert into public.bookings (id, item_id, borrower_id, start_date, end_date) values
  ('93000000-0000-4000-8000-000000000030', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000002', '2026-09-10', '2026-09-12'),
  ('93000000-0000-4000-8000-000000000031', '92000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000003', '2026-09-11', '2026-09-13');
set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000001', true);
select lives_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000030', 'accepted')$$, 'the first overlapping request can be accepted');
select throws_ok($$select * from public.decide_booking('93000000-0000-4000-8000-000000000031', 'accepted')$$, '23P01', 'These dates conflict with another accepted booking', 'the second acceptance reports a privacy-safe conflict');
reset role;
select is((select count(*) from public.bookings where id in ('93000000-0000-4000-8000-000000000030', '93000000-0000-4000-8000-000000000031') and status = 'accepted'), 1::bigint, 'exactly one conflicting request is accepted');
select is((select status::text from public.bookings where id = '93000000-0000-4000-8000-000000000031'), 'requested', 'the losing request remains coherent and requested');
select is(position('generate_series' in pg_get_functiondef('public.decide_booking(uuid,public.booking_status)'::regprocedure)), 0, 'acceptance revalidation does not enumerate days');

select * from finish();
rollback;
