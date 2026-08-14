begin;

select plan(39);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password)
values
  ('54000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@example.test', ''),
  ('54000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member@example.test', ''),
  ('54000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'outsider@example.test', ''),
  ('54000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'other-owner@example.test', '');

set local role authenticated;
select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000001', true);
select lives_ok($$select public.create_community('Governed community')$$, 'creator can create a community atomically');
select is((select owner_id from public.communities), '54000000-0000-4000-8000-000000000001'::uuid, 'creator is explicit owner');
select is((select governance_state::text from public.communities), 'managed', 'new community is managed');
select is((select role::text || '/' || status::text from public.memberships), 'admin/active', 'historical creator membership is preserved');
select ok(public.is_community_owner((select id from public.communities)), 'owner helper recognizes owner');
select ok(public.is_active_appointed_admin((select id from public.communities)), 'creator is also independently appointed admin');

create temporary table governed as select id, join_code from public.communities;
select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000002', true);
select lives_ok(format('select public.request_to_join_community(%L)', (select join_code from governed)), 'member requests membership');
select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000001', true);
select lives_ok(format('select public.approve_membership(%L, %L)', (select id from governed), '54000000-0000-4000-8000-000000000002'), 'owner approves active membership');
select lives_ok(format('select public.set_appointed_administrator(%L, %L, true)', (select id from governed), '54000000-0000-4000-8000-000000000002'), 'owner appoints active member');

select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000002', true);
select ok(not public.is_community_owner((select id from governed)), 'appointed admin is not owner');
select ok(public.is_active_appointed_admin((select id from governed)), 'appointed admin helper recognizes delegation');
select ok(public.has_managed_administration_authority((select id from governed)), 'appointed admin has ordinary managed authority');
select throws_ok(
  format('select public.set_appointed_administrator(%L, %L, false)', (select id from governed), '54000000-0000-4000-8000-000000000001'),
  '42501', 'Only the community owner can manage appointed administrators', 'appointed admin cannot demote a peer'
);

select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000003', true);
select ok(not public.is_community_owner((select id from governed)), 'outsider is not owner');
select ok(not public.is_active_appointed_admin((select id from governed)), 'outsider is not appointed admin');
select ok(not public.has_managed_administration_authority((select id from governed)), 'outsider lacks ordinary administration');
select throws_ok(
  format('select public.set_appointed_administrator(%L, %L, true)', (select id from governed), '54000000-0000-4000-8000-000000000003'),
  '42501', 'Only the community owner can manage appointed administrators', 'outsider cannot appoint an admin'
);

select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000004', true);
select lives_ok($$select public.create_community('Other governed community')$$, 'second owner creates isolated community');
create temporary table other_governed as select id from public.communities;
select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000001', true);
select throws_ok(
  format('select public.set_appointed_administrator(%L, %L, true)', (select id from other_governed), '54000000-0000-4000-8000-000000000002'),
  '42501', 'Only the community owner can manage appointed administrators', 'owner cannot attack another community'
);

select lives_ok(format('select public.set_appointed_administrator(%L, %L, false)', (select id from governed), '54000000-0000-4000-8000-000000000001'), 'owner can remove their coincident admin delegation');
select ok(public.is_community_owner((select id from governed)), 'removing delegation preserves ownership');
select is((select role::text from public.memberships where community_id = (select id from governed) and user_id = auth.uid()), 'member', 'removal changes role only');
select is((select status::text from public.memberships where community_id = (select id from governed) and user_id = auth.uid()), 'active', 'removal preserves active membership');
select ok(public.has_managed_administration_authority((select id from governed)), 'owner administers managed community without admin role');
select lives_ok(format('select public.set_appointed_administrator(%L, %L, false)', (select id from governed), '54000000-0000-4000-8000-000000000002'), 'owner removes appointed admin');
select is((select count(*) from public.memberships where community_id = (select id from governed) and user_id = '54000000-0000-4000-8000-000000000002'), 1::bigint, 'admin removal does not delete membership');

select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000002', true);
select ok(not public.has_managed_administration_authority((select id from governed)), 'ordinary member has no administration authority');
select throws_ok(
  format('select public.set_appointed_administrator(%L, %L, true)', (select id from governed), '54000000-0000-4000-8000-000000000003'),
  '42501', 'Only the community owner can manage appointed administrators', 'ordinary member cannot appoint an admin'
);

select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000001', true);
select throws_ok(
  format('select public.set_appointed_administrator(%L, %L, true)', (select id from governed), '54000000-0000-4000-8000-000000000003'),
  'P0002', 'Active community membership not found', 'pending or absent user is not implicitly joined'
);
select throws_ok($$update public.communities set governance_state = 'democratic'$$, '42501', 'permission denied for table communities', 'client cannot mutate governance state directly');
select throws_ok($$insert into public.communities (name, owner_id) values ('Forged', '54000000-0000-4000-8000-000000000003')$$, '42501', 'permission denied for table communities', 'client cannot forge ownership');
select is((select count(*) from public.communities where owner_id is null), 0::bigint, 'no visible community is ownerless');
select is((select count(distinct owner_id) from public.communities where id = (select id from governed)), 1::bigint, 'community has exactly one authoritative owner');

select lives_ok(format('select public.set_appointed_administrator(%L, %L, true)', (select id from governed), '54000000-0000-4000-8000-000000000002'), 'owner can reappoint an active member');
set local role postgres;
update public.communities set governance_state = 'democratic_preparation' where id = (select id from governed);
set local role authenticated;
select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000001', true);
select ok(public.has_managed_administration_authority((select id from governed)), 'owner retains ordinary authority during democratic preparation');
select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000002', true);
select ok(public.has_managed_administration_authority((select id from governed)), 'appointed admin retains ordinary authority during democratic preparation');
select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000003', true);
select ok(not public.has_managed_administration_authority((select id from governed)), 'outsider remains unauthorized during democratic preparation');
select set_config('request.jwt.claim.sub', '54000000-0000-4000-8000-000000000001', true);
select lives_ok(format('select public.set_appointed_administrator(%L, %L, false)', (select id from governed), '54000000-0000-4000-8000-000000000002'), 'owner may remove an appointment during reversible preparation');
select ok(public.is_community_owner((select id from governed)), 'preparation appointment changes still preserve ownership');

select * from finish();
rollback;
