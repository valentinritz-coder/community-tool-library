begin;

select plan(64);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
select ('56000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
  '00000000-0000-0000-0000-000000000000','authenticated','authenticated',
  'transfer-'||n||'@example.test',''
from generate_series(1,9) n;

set local role postgres;
insert into public.communities(id,name,owner_id,governance_state)
values
 ('56100000-0000-4000-8000-000000000001','Transfer community','56000000-0000-4000-8000-000000000001','managed'),
 ('56100000-0000-4000-8000-000000000002','Cancelled preparation','56000000-0000-4000-8000-000000000001','managed'),
 ('56100000-0000-4000-8000-000000000003','Small electorate','56000000-0000-4000-8000-000000000001','managed'),
 ('56100000-0000-4000-8000-000000000004','Other community','56000000-0000-4000-8000-000000000009','managed');
insert into public.memberships(community_id,user_id,role,status)
select '56100000-0000-4000-8000-000000000001',
 ('56000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 case when n=2 then 'admin'::public.membership_role else 'member'::public.membership_role end,'active'
from generate_series(1,6)n;
insert into public.memberships(community_id,user_id,role,status) values
 ('56100000-0000-4000-8000-000000000002','56000000-0000-4000-8000-000000000001','member','active'),
 ('56100000-0000-4000-8000-000000000003','56000000-0000-4000-8000-000000000001','member','active'),
 ('56100000-0000-4000-8000-000000000003','56000000-0000-4000-8000-000000000002','member','active'),
 ('56100000-0000-4000-8000-000000000003','56000000-0000-4000-8000-000000000003','member','active'),
 ('56100000-0000-4000-8000-000000000003','56000000-0000-4000-8000-000000000004','member','active'),
 ('56100000-0000-4000-8000-000000000004','56000000-0000-4000-8000-000000000009','member','active');

set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.begin_democratic_preparation('56100000-0000-4000-8000-000000000001',3)$$,
 '42501','Only the community owner can start democratic preparation','non-owner cannot start preparation');

select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.begin_democratic_preparation('56100000-0000-4000-8000-000000000001',4)$$,
 '22023','Council target must be 3 or 5','invalid target is rejected');
select lives_ok($$select public.begin_democratic_preparation('56100000-0000-4000-8000-000000000001',5)$$,'owner starts preparation');
select is((select governance_state::text from public.communities where id='56100000-0000-4000-8000-000000000001'),'democratic_preparation','state enters preparation');
set local role postgres;
select is((select target_seats from public.election_cycles where id=(select active_election_cycle_id from public.communities where id='56100000-0000-4000-8000-000000000001')),5::smallint,'cycle is authoritative target');
set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000002',true);
select throws_ok($$select public.change_preparation_council_target('56100000-0000-4000-8000-000000000001',3)$$,
 '42501','Only the community owner can change the council target','appointed admin cannot change preparation target');
select throws_ok($$select public.cancel_democratic_preparation('56100000-0000-4000-8000-000000000001')$$,
 '42501','Only the community owner can cancel democratic preparation','appointed admin cannot cancel preparation');
select throws_ok($$select public.commit_democratic_transfer('56100000-0000-4000-8000-000000000001')$$,
 '42501','Only the community owner can commit democratic transfer','appointed admin cannot commit transfer');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000006',true);
select throws_ok($$select public.change_preparation_council_target('56100000-0000-4000-8000-000000000001',3)$$,
 '42501','Only the community owner can change the council target','ordinary member cannot change preparation target');
select throws_ok($$select public.cancel_democratic_preparation('56100000-0000-4000-8000-000000000001')$$,
 '42501','Only the community owner can cancel democratic preparation','ordinary member cannot cancel preparation');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000009',true);
select throws_ok($$select public.change_preparation_council_target('56100000-0000-4000-8000-000000000001',3)$$,
 '42501','Only the community owner can change the council target','outsider cannot change preparation target');
select throws_ok($$select public.cancel_democratic_preparation('56100000-0000-4000-8000-000000000001')$$,
 '42501','Only the community owner can cancel democratic preparation','outsider cannot cancel preparation');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select lives_ok($$select public.change_preparation_council_target('56100000-0000-4000-8000-000000000001',3)$$,'owner atomically changes target');
set local role postgres;
select is((select (c.council_target_size=e.target_seats)::text from public.communities c join public.election_cycles e on e.id=c.active_election_cycle_id where c.id='56100000-0000-4000-8000-000000000001'),'true','community and active cycle target agree');
set local role authenticated;

select lives_ok($$select public.begin_democratic_preparation('56100000-0000-4000-8000-000000000002',3)$$,'second preparation starts');
select lives_ok($$select public.cancel_democratic_preparation('56100000-0000-4000-8000-000000000002')$$,'preparation can be cancelled');
select is((select governance_state::text from public.communities where id='56100000-0000-4000-8000-000000000002'),'managed','cancel returns to managed');
set local role postgres;
select is((select count(*) from public.election_cycles where community_id='56100000-0000-4000-8000-000000000002' and status in ('candidacy','voting')),0::bigint,'cancel leaves no ghost open cycle');
select is((select count(*) from public.community_governance_history where community_id='56100000-0000-4000-8000-000000000002'),2::bigint,'start and cancellation are audited');
set local role authenticated;

-- The electorate minimum is checked against the snapshot produced by freeze. A failure rolls the
-- entire freeze back, including the state transition, and a later valid attempt may proceed.
select lives_ok($$select public.begin_democratic_preparation('56100000-0000-4000-8000-000000000003',5)$$,'small electorate preparation starts with target five');
set local role postgres;
insert into public.election_candidacies(cycle_id,community_id,candidate_id)
select c.active_election_cycle_id,c.id,u from public.communities c,
 unnest(array['56000000-0000-4000-8000-000000000001'::uuid,'56000000-0000-4000-8000-000000000002','56000000-0000-4000-8000-000000000003'])u
where c.id='56100000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.commit_democratic_transfer('56100000-0000-4000-8000-000000000003')$$,
 '55000','At least five electors are required','frozen electorate below five rejects commitment');
select is((select governance_state::text from public.communities where id='56100000-0000-4000-8000-000000000003'),'democratic_preparation','failed freeze atomically preserves preparation');
set local role postgres;
select is((select status::text from public.election_cycles where id=(select active_election_cycle_id from public.communities where id='56100000-0000-4000-8000-000000000003')),'candidacy','failed freeze atomically preserves candidacy');
insert into public.memberships(community_id,user_id,role,status) values
 ('56100000-0000-4000-8000-000000000003','56000000-0000-4000-8000-000000000005','member','active');
set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.commit_democratic_transfer('56100000-0000-4000-8000-000000000003')$$,'target five accepts exactly three candidates with five electors');
set local role postgres;
select is((select public.finalize_foundation_round(er.id)::text from public.election_rounds er join public.communities c on c.active_election_cycle_id=er.cycle_id where c.id='56100000-0000-4000-8000-000000000003'),'failed_quorum','failed quorum finalization installs nothing');
set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000005',true);
select lives_ok($$select public.open_transition_retry_cycle('56100000-0000-4000-8000-000000000003')$$,'active member can open retry after terminal failure');
select is((select governance_state::text from public.communities where id='56100000-0000-4000-8000-000000000003'),'democratic_transition','failed election and retry remain irreversibly transitional');
set local role postgres;
select is((select target_seats from public.election_cycles where id=(select active_election_cycle_id from public.communities where id='56100000-0000-4000-8000-000000000003')),5::smallint,'retry preserves frozen council target');

-- Candidate eligibility is revalidated at freeze rather than trusted from the earlier stand.
insert into public.memberships(community_id,user_id,role,status)
select '56100000-0000-4000-8000-000000000004',('56000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'member','active'
from generate_series(1,5)n;
set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000009',true);
select lives_ok($$select public.begin_democratic_preparation('56100000-0000-4000-8000-000000000004',3)$$,'eligibility fixture enters preparation');
set local role postgres;
insert into public.election_candidacies(cycle_id,community_id,candidate_id)
select c.active_election_cycle_id,c.id,u from public.communities c,
 unnest(array['56000000-0000-4000-8000-000000000001'::uuid,'56000000-0000-4000-8000-000000000002','56000000-0000-4000-8000-000000000003'])u
where c.id='56100000-0000-4000-8000-000000000004';
update public.memberships set status='pending' where community_id='56100000-0000-4000-8000-000000000004' and user_id='56000000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000009',true);
select throws_ok($$select public.commit_democratic_transfer('56100000-0000-4000-8000-000000000004')$$,
 '55000','At least three active candidates are required','inactive candidacy no longer satisfies commitment minimum');
select is((select governance_state::text from public.communities where id='56100000-0000-4000-8000-000000000004'),'democratic_preparation','invalid candidate freeze failure preserves preparation');

select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);

select throws_ok($$select public.commit_democratic_transfer('56100000-0000-4000-8000-000000000001')$$,
 '55000','At least three active candidates are required','zero candidates cannot commit');

-- Three independent members stand; candidate registration stays member-controlled.
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000003',true);
select lives_ok($$select public.stand_for_election((select active_election_cycle_id from public.communities where id='56100000-0000-4000-8000-000000000001'))$$,'first candidate stands');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000004',true);
select lives_ok($$select public.stand_for_election((select active_election_cycle_id from public.communities where id='56100000-0000-4000-8000-000000000001'))$$,'second candidate stands');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000005',true);
select lives_ok($$select public.stand_for_election((select active_election_cycle_id from public.communities where id='56100000-0000-4000-8000-000000000001'))$$,'third candidate stands');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.commit_democratic_transfer('56100000-0000-4000-8000-000000000001')$$,'exactly three candidates and six electors can commit');
select is((select governance_state::text from public.communities where id='56100000-0000-4000-8000-000000000001'),'democratic_transition','commit enters irreversible transition');
set local role postgres;
select is((select count(*) from public.election_electorate where cycle_id=(select active_election_cycle_id from public.communities where id='56100000-0000-4000-8000-000000000001')),6::bigint,'authoritative electorate is frozen');
select is((select count(*) from public.election_candidates where cycle_id=(select active_election_cycle_id from public.communities where id='56100000-0000-4000-8000-000000000001')),3::bigint,'authoritative candidates are frozen');
create temporary table founding_round as select er.id from public.election_rounds er join public.communities c on c.active_election_cycle_id=er.cycle_id where c.id='56100000-0000-4000-8000-000000000001';
grant select on founding_round to authenticated;
grant select on founding_round to service_role;
set local role authenticated;
select throws_ok($$select public.cancel_democratic_preparation('56100000-0000-4000-8000-000000000001')$$,
 '55000','Democratic transfer can no longer be cancelled','cancel after commitment is rejected');
select throws_ok($$select public.change_preparation_council_target('56100000-0000-4000-8000-000000000001',5)$$,
 '55000','Council target is immutable after commitment','target is immutable after commitment');
select ok(not public.is_active_community_admin('56100000-0000-4000-8000-000000000001'),'owner without appointment loses ordinary authority after commit');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000002',true);
select ok(public.has_temporary_caretaker_authority('56100000-0000-4000-8000-000000000001'),'appointed admin independently becomes caretaker');

-- Three ballots produce a real deterministic finalization; the internal orchestration installs.
set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.submit_election_ballot((select id from founding_round),array['56000000-0000-4000-8000-000000000003'::uuid,'56000000-0000-4000-8000-000000000004','56000000-0000-4000-8000-000000000005'])$$,'first elector votes');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000002',true);
select lives_ok($$select public.submit_election_ballot((select id from founding_round),array['56000000-0000-4000-8000-000000000003'::uuid,'56000000-0000-4000-8000-000000000004','56000000-0000-4000-8000-000000000005'])$$,'second elector votes');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000003',true);
select lives_ok($$select public.submit_election_ballot((select id from founding_round),array['56000000-0000-4000-8000-000000000003'::uuid,'56000000-0000-4000-8000-000000000004','56000000-0000-4000-8000-000000000005'])$$,'third elector votes');
set local role service_role;
select is((select public.finalize_foundation_round((select id from founding_round))::text),'completed','successful finalization installs council in authoritative boundary');
set local role postgres;
select is((select governance_state::text from public.communities where id='56100000-0000-4000-8000-000000000001'),'democratic','installation atomically enters democratic state');
select is((select count(*) from public.elected_council_mandates where community_id='56100000-0000-4000-8000-000000000001'),3::bigint,'exactly three final mandates are materialized');
select is((select nominal_term_ends_at=took_office_at+interval '12 months' from public.elected_councils where community_id='56100000-0000-4000-8000-000000000001'),true,'mandate records constitutional nominal term');
select throws_ok($$select public.install_elected_council('56100000-0000-4000-8000-000000000001',(select active_election_cycle_id from public.communities where id='56100000-0000-4000-8000-000000000001'))$$,
 '55000','Community cannot install a council','installation is exactly once');

set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);
select ok(not public.is_active_community_admin('56100000-0000-4000-8000-000000000001'),'non-elected owner has no democratic administration');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000002',true);
select ok(not public.is_active_community_admin('56100000-0000-4000-8000-000000000001'),'non-elected former appointed admin has no democratic administration');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000003',true);
select ok(public.has_elected_council_authority('56100000-0000-4000-8000-000000000001'),'elected ordinary member has council authority');
select throws_ok($$select public.install_elected_council('56100000-0000-4000-8000-000000000001',(select active_election_cycle_id from public.communities where id='56100000-0000-4000-8000-000000000001'))$$,
 '42501','permission denied for function install_elected_council','browser roles cannot install councils');
select throws_ok($$select public.close_election_round('56999999-0000-4000-8000-000000000001')$$,
 '42501','permission denied for function close_election_round','browser roles still cannot close elections');
select throws_ok($$select * from public.election_ballot_approvals$$,
 '42501','permission denied for table election_ballot_approvals','ballot choice ledger remains private');

-- A terminal result with quorum but fewer than three electable winners installs nothing and keeps
-- the irreversible transition in force.
set local role postgres;
insert into public.communities(id,name,owner_id,governance_state) values
 ('56100000-0000-4000-8000-000000000005','Insufficient winners','56000000-0000-4000-8000-000000000001','managed');
insert into public.memberships(community_id,user_id,role,status)
select '56100000-0000-4000-8000-000000000005',('56000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'member','active' from generate_series(1,5)n;
set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.begin_democratic_preparation('56100000-0000-4000-8000-000000000005',3)$$,'insufficient-winner fixture starts preparation');
set local role postgres;
insert into public.election_candidacies(cycle_id,community_id,candidate_id)
select c.active_election_cycle_id,c.id,u from public.communities c,
 unnest(array['56000000-0000-4000-8000-000000000001'::uuid,'56000000-0000-4000-8000-000000000002','56000000-0000-4000-8000-000000000003'])u
where c.id='56100000-0000-4000-8000-000000000005';
set local role authenticated;
select lives_ok($$select public.commit_democratic_transfer('56100000-0000-4000-8000-000000000005')$$,'insufficient-winner fixture commits transfer');
set local role postgres;
create temporary table insufficient_round as select er.id from public.election_rounds er join public.communities c on c.active_election_cycle_id=er.cycle_id where c.id='56100000-0000-4000-8000-000000000005';
grant select on insufficient_round to authenticated;
grant select on insufficient_round to service_role;
set local role authenticated;
select lives_ok($$select public.submit_election_ballot((select id from insufficient_round),array['56000000-0000-4000-8000-000000000001'::uuid,'56000000-0000-4000-8000-000000000002'])$$,'insufficient result first ballot');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000002',true);
select lives_ok($$select public.submit_election_ballot((select id from insufficient_round),array['56000000-0000-4000-8000-000000000001'::uuid,'56000000-0000-4000-8000-000000000002'])$$,'insufficient result second ballot');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000003',true);
select lives_ok($$select public.submit_election_ballot((select id from insufficient_round),array['56000000-0000-4000-8000-000000000001'::uuid,'56000000-0000-4000-8000-000000000002'])$$,'insufficient result third ballot');
set local role service_role;
select is((select public.finalize_foundation_round((select id from insufficient_round))::text),'insufficient_winners','fewer than three electable winners is terminal failure');
set local role postgres;
select is((select governance_state::text from public.communities where id='56100000-0000-4000-8000-000000000005'),'democratic_transition','insufficient winners preserve democratic transition');

select * from finish();
rollback;
