begin;
select plan(31);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
select ('57000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 '00000000-0000-0000-0000-000000000000','authenticated','authenticated',
 case n when 1 then 'owner@example.test' when 2 then 'admin@example.test'
   else 'member-'||n||'@example.test' end,'' from generate_series(1,6)n;

set local role postgres;
insert into public.communities(id,name,owner_id,governance_state)
values('57100000-0000-4000-8000-000000000001','Governance UI fixture',
 '57000000-0000-4000-8000-000000000001','managed');
insert into public.memberships(community_id,user_id,role,status,display_name)
select '57100000-0000-4000-8000-000000000001',id,
 case when id='57000000-0000-4000-8000-000000000002' then 'admin'::public.membership_role else 'member' end,
 'active',case when id='57000000-0000-4000-8000-000000000001' then 'Oak Owner'
  when id='57000000-0000-4000-8000-000000000002' then 'Ash Admin' else null end
 from auth.users where id::text between
 '57000000-0000-4000-8000-000000000001' and '57000000-0000-4000-8000-000000000004';

set local role authenticated;
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.begin_democratic_preparation('57100000-0000-4000-8000-000000000001',3)$$,
 'owner opens the projection fixture preparation');
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000001',true);
select public.stand_for_election((select cycle_id from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')));
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000002',true);
select public.stand_for_election((select cycle_id from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')));
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000003',true);
select lives_ok($$select public.stand_for_election((select cycle_id from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')))$$,
 'a missing display name does not affect election eligibility');
select is((select current_user_label from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'Community member • 0003','a historical membership without a display name keeps a privacy-safe fallback');
select is(public.set_community_display_name('57100000-0000-4000-8000-000000000001','  Cedar Member  '),
 'Cedar Member','an active member can set and whitespace-trim their own community display name');
select is((select current_user_label from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'Cedar Member','the new display name appears in the member-scoped read model');
select throws_ok($$select public.set_community_display_name('57100000-0000-4000-8000-000000000001','x')$$,
 '22023','Display name must contain between 2 and 80 characters','a one-character display name is rejected');
select throws_ok($$select public.set_community_display_name('57100000-0000-4000-8000-000000000001',repeat('x',81))$$,
 '22023','Display name must contain between 2 and 80 characters','a display name over 80 characters is rejected');
set local role postgres;
select is((select display_name from public.memberships where community_id='57100000-0000-4000-8000-000000000001'
 and user_id='57000000-0000-4000-8000-000000000001'),'Oak Owner',
 'updating a display name cannot modify another community member');
set local role authenticated;
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000006',true);
select throws_ok($$select public.set_community_display_name('57100000-0000-4000-8000-000000000001','Outsider Name')$$,
 '42501','Active community membership required','an outsider cannot set a community display name');
select ok(not has_function_privilege('anon','public.set_community_display_name(uuid,text)','execute')
 and has_function_privilege('authenticated','public.set_community_display_name(uuid,text)','execute'),
 'only authenticated users receive the display-name RPC boundary');

select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000001',true);
select lives_ok($$select * from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')$$,
 'read model executes without ambiguous columns');
select is((select owner_label from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'Oak Owner','owner has a community-readable identity');
select is((select appointed_admins->0->>'label' from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'Ash Admin','appointed admin has a community-readable identity');
select ok((select may_manage_appointed_admins from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'managed owner may manage appointed administrators');
select ok((select may_approve_memberships and may_moderate_community from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'managed owner receives server-derived ordinary capabilities');
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000002',true);
select ok(not (select may_manage_appointed_admins from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'appointed admin cannot manage appointment lifecycle');
select ok((select may_approve_memberships from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'managed appointed admin receives delegated administration capability');
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000001',true);
select is((select jsonb_array_length(candidates) from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 3,'all individual candidates are projected');
select ok((select candidates @> '[{"label":"Cedar Member"}]'::jsonb
 from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'candidate identity is readable and stable');
select ok(not (select may_commit_founding_transfer from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'three candidates do not bypass the electorate minimum');
select is((select commit_blocker from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'electorate_minimum','projection explains the authoritative blocker');
set local role postgres;
update public.memberships set status='pending' where community_id='57100000-0000-4000-8000-000000000001'
 and user_id='57000000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000001',true);
select is((select valid_candidate_count from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),2,
 'inactive candidacy is excluded from valid progress');
select is((select jsonb_array_length(candidates) from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),2,
 'inactive candidate is excluded from the displayed list');

set local role postgres;
update public.memberships set status='active' where community_id='57100000-0000-4000-8000-000000000001'
 and user_id='57000000-0000-4000-8000-000000000003';
insert into public.memberships(community_id,user_id,role,status) values
 ('57100000-0000-4000-8000-000000000001','57000000-0000-4000-8000-000000000005','member','active');
set local role authenticated;
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000001',true);
select ok((select may_commit_founding_transfer from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'projection enables commitment when all current backend preconditions hold');
select ok(not has_table_privilege('authenticated','public.election_ballot_approvals','select'),
 'browser role still cannot read ballot approvals');
select ok(position('approval' in pg_get_function_result('public.get_community_governance_ui(uuid)'::regprocedure))=0,
 'read contract contains no ballot choice or approval field');
select ok((select owner_label not like '%@%' and appointed_admins::text not like '%@%' and candidates::text not like '%@%'
 from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),
 'authentication emails are absent from community governance identities');
select ok(position('email' in pg_get_functiondef('public.get_community_governance_ui(uuid)'::regprocedure))=0,
 'governance read model never reads authentication email');
select ok(not has_function_privilege('anon','public.get_community_governance_ui(uuid)','execute'),
 'anonymous role cannot execute the read model');
select ok(has_function_privilege('authenticated','public.get_community_governance_ui(uuid)','execute'),
 'authenticated role may execute the member-scoped read model');
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000006',true);
select is((select count(*) from public.get_community_governance_ui('57100000-0000-4000-8000-000000000001')),0::bigint,
 'non-member receives no governance data');

select * from finish();
rollback;
