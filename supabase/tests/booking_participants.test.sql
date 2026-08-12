begin;

select plan(34);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password) values
  ('a0000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@example.test', ''),
  ('a0000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'borrower@example.test', ''),
  ('a0000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member@example.test', ''),
  ('a0000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test', ''),
  ('a0000000-0000-4000-8000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pending@example.test', ''),
  ('a0000000-0000-4000-8000-000000000006', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'outsider@example.test', ''),
  ('a0000000-0000-4000-8000-000000000007', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cross-admin@example.test', ''),
  ('a0000000-0000-4000-8000-000000000008', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pending-member@example.test', '');
insert into public.communities (id, name) values
  ('a1000000-0000-4000-8000-000000000001', 'Participant community'),
  ('a1000000-0000-4000-8000-000000000002', 'Other community');
insert into public.memberships (community_id, user_id, role, status) values
  ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'member', 'active'),
  ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', 'member', 'active'),
  ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003', 'member', 'active'),
  ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000004', 'admin', 'active'),
  ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000005', 'admin', 'pending'),
  ('a1000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000007', 'admin', 'active'),
  ('a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000008', 'member', 'pending');
insert into public.items (id, community_id, owner_id, name, category, description, photo_path, is_free, photo_uploaded) values
  ('a2000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'Contact drill', 'small_diy', 'Synthetic fixture', 'a2000000-0000-4000-8000-000000000001/photo.jpg', true, true);
insert into public.bookings (id, item_id, borrower_id, start_date, end_date, status) values
  ('a3000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', '2026-10-01', '2026-10-01', 'requested'),
  ('a3000000-0000-4000-8000-000000000002', 'a2000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', '2026-10-02', '2026-10-02', 'accepted'),
  ('a3000000-0000-4000-8000-000000000003', 'a2000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', '2026-10-03', '2026-10-03', 'refused');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.list_booking_requests()), 3::bigint, 'borrower sees requested, accepted, and refused bookings');
select is((select count(*) from public.list_booking_requests() where status = 'requested'), 1::bigint, 'borrower sees requested status');
select is((select count(*) from public.list_booking_requests() where status = 'accepted'), 1::bigint, 'borrower sees accepted status');
select is((select count(*) from public.list_booking_requests() where status = 'refused'), 1::bigint, 'borrower sees refused status');
select ok((select bool_and(not can_decide) from public.list_booking_requests()), 'borrower gets no decision capability');
select throws_ok($$select borrower_id from public.list_booking_requests()$$, '42703', 'column "borrower_id" does not exist', 'booking projection excludes borrower UUID');
select throws_ok($$select owner_id from public.list_booking_requests()$$, '42703', 'column "owner_id" does not exist', 'booking projection excludes owner UUID');
select is((select counterparty_email from public.list_accepted_booking_contacts()), 'owner@example.test', 'accepted borrower sees only owner email');
select is((select count(*) from public.list_accepted_booking_contacts()), 1::bigint, 'requested and refused bookings expose no borrower contact rows');

select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000001', true);
select is((select count(*) from public.list_booking_requests()), 3::bigint, 'owner sees every status for requests on their item');
select is((select count(*) from public.list_booking_requests() where status = 'requested' and can_decide), 1::bigint, 'active owner can decide the requested booking');
select is((select count(*) from public.list_booking_requests() where status = 'accepted' and not can_decide), 1::bigint, 'active owner cannot decide the accepted booking');
select is((select count(*) from public.list_booking_requests() where status = 'refused' and not can_decide), 1::bigint, 'active owner cannot decide the refused booking');
select is((select counterparty_email from public.list_accepted_booking_contacts()), 'borrower@example.test', 'accepted owner sees only borrower email');
select is((select count(*) from public.list_accepted_booking_contacts()), 1::bigint, 'requested and refused bookings expose no owner contact rows');
select throws_ok($$select borrower_id from public.list_accepted_booking_contacts()$$, '42703', 'column "borrower_id" does not exist', 'contact projection excludes borrower UUID');
select throws_ok($$select owner_id from public.list_accepted_booking_contacts()$$, '42703', 'column "owner_id" does not exist', 'contact projection excludes owner UUID');
select throws_ok($$select phone from public.list_accepted_booking_contacts()$$, '42703', 'column "phone" does not exist', 'contact projection has no phone field');
select throws_ok($$select address from public.list_accepted_booking_contacts()$$, '42703', 'column "address" does not exist', 'contact projection has no address field');

reset role;
update public.memberships
set status = 'pending'
where community_id = 'a1000000-0000-4000-8000-000000000001'
  and user_id = 'a0000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.list_accepted_booking_contacts()), 0::bigint, 'inactive borrower loses contact access while booking remains accepted');
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000001', true);
select is((select counterparty_email from public.list_accepted_booking_contacts()), 'borrower@example.test', 'active owner retains contact access when accepted borrower becomes inactive');

select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000004', true);
select is((select count(*) from public.list_booking_requests()), 1::bigint, 'non-participant admin sees only requested bookings');
select ok((select bool_and(status = 'requested' and can_decide) from public.list_booking_requests()), 'active same-community admin can decide the requested booking');
select is((select count(*) from public.list_accepted_booking_contacts()), 0::bigint, 'non-participant admin receives no contact');

select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000003', true);
select is((select count(*) from public.list_booking_requests()), 0::bigint, 'unrelated active member sees no bookings');
select is((select count(*) from public.list_accepted_booking_contacts()), 0::bigint, 'unrelated active member receives no contact');
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000005', true);
select is((select count(*) from public.list_booking_requests()), 0::bigint, 'pending admin sees no bookings');
select is((select count(*) from public.list_accepted_booking_contacts()), 0::bigint, 'pending admin receives no contact');
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000008', true);
select is((select count(*) from public.list_booking_requests()), 0::bigint, 'pending member sees no bookings');
select is((select count(*) from public.list_accepted_booking_contacts()), 0::bigint, 'pending member receives no contact');
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000006', true);
select is((select count(*) from public.list_accepted_booking_contacts()), 0::bigint, 'non-member receives no contact');
select set_config('request.jwt.claim.sub', 'a0000000-0000-4000-8000-000000000007', true);
select is((select count(*) from public.list_booking_requests()), 0::bigint, 'cross-community admin sees no bookings');
select is((select count(*) from public.list_accepted_booking_contacts()), 0::bigint, 'cross-community admin receives no contact');

reset role;
set local role anon;
select throws_ok($$select * from public.list_accepted_booking_contacts()$$, '42501', null, 'unauthenticated user cannot execute contact projection');
reset role;

select * from finish();
rollback;
