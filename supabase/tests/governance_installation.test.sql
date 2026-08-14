begin;
select plan(26);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
select ('57000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 '00000000-0000-0000-0000-000000000000','authenticated','authenticated','install-'||n||'@example.test',''
from generate_series(1,8)n;

-- Build isolated authoritative cycles for installation cardinality and provenance checks.
set local role postgres;
insert into public.communities(id,name,owner_id,governance_state,council_target_size)
select ('57100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'Install fixture '||n,
 '57000000-0000-4000-8000-000000000001','democratic_transition',case when n<=2 then 3 else 5 end
from generate_series(1,8)n;
insert into public.memberships(community_id,user_id,role,status)
select c.id,u,case when u='57000000-0000-4000-8000-000000000002' then 'admin'::public.membership_role else 'member'::public.membership_role end,'active'
from public.communities c cross join unnest(array[
 '57000000-0000-4000-8000-000000000001'::uuid,'57000000-0000-4000-8000-000000000002',
 '57000000-0000-4000-8000-000000000003','57000000-0000-4000-8000-000000000004',
 '57000000-0000-4000-8000-000000000005'])u where c.id::text like '57100000-0000-4000-8000-%';
insert into public.election_cycles(community_id,target_seats,status,completed_at)
select c.id,c.council_target_size,case when right(c.id::text,1)='7' then 'voting'::public.election_cycle_status else 'completed' end,
 case when right(c.id::text,1)='7' then null else now() end
from public.communities c where c.id::text like '57100000-0000-4000-8000-%';
update public.communities c set active_election_cycle_id=e.id from public.election_cycles e where e.community_id=c.id and c.id::text like '57100000-0000-4000-8000-%';

-- Winner counts: target3 fixtures 1/2 have 2/3; target5 fixtures 3/4/5/6 have 2/3/4/5.
insert into public.election_winners(cycle_id,candidate_id,elected_in_round,approval_count)
select e.id,u,1,1 from public.election_cycles e
join lateral (select u from unnest(array[
 '57000000-0000-4000-8000-000000000001'::uuid,'57000000-0000-4000-8000-000000000002',
 '57000000-0000-4000-8000-000000000003','57000000-0000-4000-8000-000000000004',
 '57000000-0000-4000-8000-000000000005']) with ordinality x(u,n)
 where n<=case right(e.community_id::text,1)
   when '1' then 2 when '2' then 3 when '3' then 2 when '4' then 3 when '5' then 4 when '6' then 5 else 3 end) winners on true
where e.community_id::text like '57100000-0000-4000-8000-%' and right(e.community_id::text,1)<>'8';
insert into public.election_provisional_winners(cycle_id,candidate_id,carried_from_round,approval_count)
select active_election_cycle_id,'57000000-0000-4000-8000-000000000001',1,1 from public.communities where id='57100000-0000-4000-8000-000000000008';
insert into public.election_candidacies(cycle_id,community_id,candidate_id)
select active_election_cycle_id,id,'57000000-0000-4000-8000-000000000004' from public.communities where id='57100000-0000-4000-8000-000000000004';

select throws_ok($$select public.install_elected_council('57100000-0000-4000-8000-000000000001',(select active_election_cycle_id from public.communities where id='57100000-0000-4000-8000-000000000001'))$$,
 '55000','Election did not produce an installable council','target 3 rejects two winners');
select lives_ok($$select public.install_elected_council('57100000-0000-4000-8000-000000000002',(select active_election_cycle_id from public.communities where id='57100000-0000-4000-8000-000000000002'))$$,'target 3 accepts exactly three winners');
select throws_ok($$select public.install_elected_council('57100000-0000-4000-8000-000000000003',(select active_election_cycle_id from public.communities where id='57100000-0000-4000-8000-000000000003'))$$,
 '55000','Election did not produce an installable council','target 5 rejects two winners');
select lives_ok($$select public.install_elected_council('57100000-0000-4000-8000-000000000004',(select active_election_cycle_id from public.communities where id='57100000-0000-4000-8000-000000000004'))$$,'target 5 accepts three winners');
select lives_ok($$select public.install_elected_council('57100000-0000-4000-8000-000000000005',(select active_election_cycle_id from public.communities where id='57100000-0000-4000-8000-000000000005'))$$,'target 5 accepts four winners');
select lives_ok($$select public.install_elected_council('57100000-0000-4000-8000-000000000006',(select active_election_cycle_id from public.communities where id='57100000-0000-4000-8000-000000000006'))$$,'target 5 accepts five winners');
select throws_ok($$select public.install_elected_council('57100000-0000-4000-8000-000000000007',(select active_election_cycle_id from public.communities where id='57100000-0000-4000-8000-000000000007'))$$,
 '55000','A completed matching election is required','non-completed cycle is rejected');
select throws_ok($$select public.install_elected_council('57100000-0000-4000-8000-000000000008',(select active_election_cycle_id from public.communities where id='57100000-0000-4000-8000-000000000007'))$$,
 '55000','Election is not authoritative for this community','cross-community cycle is rejected');
select throws_ok($$select public.install_elected_council('57100000-0000-4000-8000-000000000008',(select active_election_cycle_id from public.communities where id='57100000-0000-4000-8000-000000000008'))$$,
 '55000','Election did not produce an installable council','provisional-only result cannot install a council');
select is((select count(*) from public.elected_councils where community_id in ('57100000-0000-4000-8000-000000000001','57100000-0000-4000-8000-000000000003','57100000-0000-4000-8000-000000000007','57100000-0000-4000-8000-000000000008')),0::bigint,'invalid and unresolved elections install no council');
select throws_ok($$select public.install_elected_council('57100000-0000-4000-8000-000000000002',(select active_election_cycle_id from public.communities where id='57100000-0000-4000-8000-000000000002'))$$,
 '55000','Community cannot install a council','second installation is rejected exactly once');
select is((select count(*) from public.elected_council_mandates where community_id='57100000-0000-4000-8000-000000000006'),5::bigint,'five final winners produce exactly five mandates');
select is((select count(*) from public.elected_council_mandates m join public.election_winners w on w.cycle_id=m.source_cycle_id and w.candidate_id=m.member_id where m.community_id='57100000-0000-4000-8000-000000000006'),5::bigint,'every mandate has final election-winner provenance');
select is((select count(*) from pg_constraint con join pg_class rel on rel.oid=con.conrelid
  where rel.oid='public.elected_council_mandates'::regclass and con.contype='u'
    and pg_get_constraintdef(con.oid) like '%community_id, member_id%'),0::bigint,
  'mandate history permits the same member in a later council');
select ok(has_function_privilege('service_role','public.finalize_foundation_round(uuid)','EXECUTE'),
  'trusted platform service role can invoke founding finalization');

-- Fixture 4 elected owner, former appointed admin, and ordinary member; users 4/5 remain unelected.
set local role authenticated;
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000001',true);
select ok(public.has_elected_council_authority('57100000-0000-4000-8000-000000000004'),'elected owner has authority through mandate');
select ok(public.is_active_community_admin('57100000-0000-4000-8000-000000000004'),'elected owner receives ordinary administration');
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000002',true);
select ok(public.has_elected_council_authority('57100000-0000-4000-8000-000000000004'),'elected former appointed admin has authority through mandate');
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000003',true);
select ok(public.has_elected_council_authority('57100000-0000-4000-8000-000000000004'),'elected ordinary member has council authority');
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000004',true);
select ok(not public.has_elected_council_authority('57100000-0000-4000-8000-000000000004'),'unelected candidate has no council authority');
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000005',true);
select ok(not public.has_elected_council_authority('57100000-0000-4000-8000-000000000004'),'unelected appointed admin has no council authority');
select ok(not public.is_active_community_admin('57100000-0000-4000-8000-000000000004'),'former appointed role grants no democratic administration');

-- Total fail-closed helper behavior protects PL/pgSQL callers using IF NOT helper(...).
select set_config('request.jwt.claim.sub','',true);
select is(public.is_active_community_admin('57100000-0000-4000-8000-000000000004'),false,'anonymous helper result is false, never null');
select set_config('request.jwt.claim.sub','57000000-0000-4000-8000-000000000001',true);
select is(public.is_active_community_admin('57999999-0000-4000-8000-000000000099'),false,'missing-community helper result is false, never null');
select throws_ok($$select public.finalize_foundation_round('57999999-0000-4000-8000-000000000001')$$,
 '42501','permission denied for function finalize_foundation_round','browser cannot invoke platform finalization orchestration');
select throws_ok($$select * from public.election_electorate$$,'42501','permission denied for table election_electorate','electorate snapshot stays private');

select * from finish();
rollback;
