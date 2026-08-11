begin;

select plan(25);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password)
values
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test', ''),
  ('10000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member@example.test', ''),
  ('10000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'outsider@example.test', ''),
  ('10000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'other-admin@example.test', '');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);

select lives_ok(
  $$select public.create_community('Riverside neighbours')$$,
  'an authenticated user can create a community'
);
select is((select count(*) from public.communities), 1::bigint, 'the creator can read the community');
select is((select role::text from public.memberships), 'admin', 'the creator is an admin');
select is((select status::text from public.memberships), 'active', 'the creator membership is active');
select isnt((select join_code::text from public.communities), '', 'the community has a join code');

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.communities), 0::bigint, 'a non-member cannot read the private community');

-- RLS hides the code, so use the fixed value captured while acting as the creator.
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
create temporary table test_community as select id, join_code from public.communities;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select lives_ok(
  format('select public.request_to_join_community(%L)', (select join_code from test_community)),
  'a user with the private code can request to join'
);
select is((select status::text from public.memberships), 'pending', 'the new membership is pending');
select is((select role::text from public.memberships), 'member', 'the requester cannot choose an admin role');
select is((select count(*) from public.communities), 0::bigint, 'pending membership does not reveal community data');
select throws_ok(
  $$update public.memberships set role = 'admin'$$,
  '42501',
  'permission denied for table memberships',
  'a member cannot promote themselves'
);
select throws_ok(
  format('select public.approve_membership(%L, %L)', (select id from test_community), '10000000-0000-4000-8000-000000000002'),
  '42501',
  'Only an active community admin can approve memberships',
  'a pending member cannot activate themselves'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select is((select count(*) from public.memberships), 2::bigint, 'an admin can see pending memberships in their community');
select lives_ok(
  format('select public.approve_membership(%L, %L)', (select id from test_community), '10000000-0000-4000-8000-000000000002'),
  'an active admin can approve a pending member'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.communities), 1::bigint, 'an active member can read their community');
select is((select status::text from public.memberships), 'active', 'the approved membership is active');
select is((select count(*) from public.memberships), 1::bigint, 'a regular member can only read their own membership');

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', true);
select lives_ok($$select public.create_community('Hilltop neighbours')$$, 'another user can create another community');
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select is((select count(*) from public.communities), 1::bigint, 'community data is isolated between communities');
select is((select count(*) from public.memberships), 2::bigint, 'community admins cannot read another community memberships');
select throws_ok(
  $$select public.approve_membership(
      (select id from public.communities where name = 'Hilltop neighbours'),
      '10000000-0000-4000-8000-000000000003')$$,
  '42501',
  'Only an active community admin can approve memberships',
  'an admin cannot manipulate another community memberships'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
select throws_ok(
  $$select public.request_to_join_community('ffffffff-ffff-4fff-8fff-ffffffffffff')$$,
  '22023',
  'Invalid community join code',
  'an invalid join code is rejected'
);
select is((select count(*) from public.communities), 0::bigint, 'an outsider sees no communities');
select is((select count(*) from public.memberships), 0::bigint, 'an outsider sees no memberships');

select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select public.create_community('No identity')$$,
  '42501',
  'Authentication required',
  'community creation requires authentication'
);

select * from finish();
rollback;
