begin;
select plan(47);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
select ('55000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
 '00000000-0000-0000-0000-000000000000','authenticated','authenticated',
 'election-'||n||'@example.test','' from generate_series(1,24) n;

insert into public.communities(id,name,owner_id,governance_state)
values ('55100000-0000-4000-8000-000000000001','Election community','55000000-0000-4000-8000-000000000001','democratic_preparation'),
       ('55100000-0000-4000-8000-000000000002','Other election community','55000000-0000-4000-8000-000000000024','democratic_transition');
insert into public.memberships(community_id,user_id,role,status)
select '55100000-0000-4000-8000-000000000001',
 ('55000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 case when n in (1,2) then 'admin'::public.membership_role else 'member' end,
 case when n=10 then 'pending'::public.membership_status else 'active' end
from generate_series(1,10)n;
insert into public.memberships values
 ('55100000-0000-4000-8000-000000000002','55000000-0000-4000-8000-000000000024','admin','active',now());

create temporary table ids(cycle uuid, round uuid);
grant select on table pg_temp.ids to authenticated;
insert into ids(cycle) values(public.create_election_cycle('55100000-0000-4000-8000-000000000001',3));
set local role authenticated;
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000001',true);
select lives_ok(format('select public.stand_for_election(%L)',(select cycle from ids)),'active owner may stand');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000002',true);
select lives_ok(format('select public.stand_for_election(%L)',(select cycle from ids)),'active appointed admin may stand');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000003',true);
select lives_ok(format('select public.stand_for_election(%L)',(select cycle from ids)),'active member may stand');
select throws_ok(format('select public.stand_for_election(%L)',(select cycle from ids)),'23505',null,'duplicate candidacy rejected');
select lives_ok(format('select public.withdraw_election_candidacy(%L)',(select cycle from ids)),'candidate may withdraw while open');
select lives_ok(format('select public.stand_for_election(%L)',(select cycle from ids)),'withdrawn candidate may stand again');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000010',true);
select throws_ok(format('select public.stand_for_election(%L)',(select cycle from ids)),'42501','Active community membership required','pending member rejected');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000011',true);
select throws_ok(format('select public.stand_for_election(%L)',(select cycle from ids)),'42501','Active community membership required','outsider rejected');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000024',true);
select throws_ok(format('select public.stand_for_election(%L)',(select cycle from ids)),'42501','Active community membership required','active member of another community cannot cross-nominate');

set local role postgres;
update ids set round=public.freeze_election_cycle(cycle);
select is((select count(*) from public.election_electorate where cycle_id=(select cycle from ids)),9::bigint,'electorate freezes active memberships');
select is((select count(*) from public.election_candidates where cycle_id=(select cycle from ids)),3::bigint,'candidate snapshot is persistent');
select is((select quorum_threshold from public.election_rounds where id=(select round from ids)),3,'small electorate quorum is three');
update public.memberships set status='pending' where community_id='55100000-0000-4000-8000-000000000001' and user_id='55000000-0000-4000-8000-000000000009';
insert into public.memberships values ('55100000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000012','member','active',now());
select ok(exists(select 1 from public.election_electorate where cycle_id=(select cycle from ids) and voter_id='55000000-0000-4000-8000-000000000009'),'later membership status change does not rewrite electorate snapshot');
select ok(not exists(select 1 from public.election_electorate where cycle_id=(select cycle from ids) and voter_id='55000000-0000-4000-8000-000000000012'),'member added after freeze is absent from electorate snapshot');
set local role authenticated;
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000003',true);
select throws_ok(format('select public.withdraw_election_candidacy(%L)',(select cycle from ids)),'55000','Candidacies are not open','withdrawal after freeze rejected');
select throws_ok(format('select public.stand_for_election(%L)',(select cycle from ids)),'55000','Candidacies are not open','late candidacy rejected');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000012',true);
select throws_ok(format('select public.submit_election_ballot(%L,array[]::uuid[])',(select round from ids)),'42501','Voter is not in the electorate snapshot','late active member cannot vote in frozen cycle');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000024',true);
select throws_ok(format('select public.submit_election_ballot(%L,array[]::uuid[])',(select round from ids)),'42501','Voter is not in the electorate snapshot','other-community voter cannot use round');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000003',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L::uuid,%L::uuid])',(select round from ids),'55000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000002'),'snapshot voter may submit approvals');
select throws_ok(format('select public.submit_election_ballot(%L,array[]::uuid[])',(select round from ids)),'23505',null,'one ballot per voter per round');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000004',true);
select throws_ok(format('select public.submit_election_ballot(%L,array[%L::uuid,%L::uuid])',(select round from ids),'55000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000001'),'22023','A ballot cannot contain duplicate approvals','duplicate approval rejected');
select throws_ok(format('select public.submit_election_ballot(%L,array[%L::uuid])',(select round from ids),'55000000-0000-4000-8000-000000000009'),'22023','Ballot contains an ineligible candidate','non-candidate rejected');
select throws_ok(format('select public.submit_election_ballot(%L,array[%L::uuid,%L::uuid,%L::uuid,%L::uuid])',(select round from ids),'55000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000002','55000000-0000-4000-8000-000000000003','55000000-0000-4000-8000-000000000004'),'22023','Too many approvals','target-three maximum enforced');
select lives_ok(format('select public.submit_election_ballot(%L,array[]::uuid[])',(select round from ids)),'empty approval ballot is explicitly allowed and counts only toward quorum');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000011',true);
select throws_ok(format('select public.submit_election_ballot(%L,array[]::uuid[])',(select round from ids)),'42501','Voter is not in the electorate snapshot','non-snapshot voter rejected');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000005',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L::uuid,%L::uuid,%L::uuid])',(select round from ids),'55000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000002','55000000-0000-4000-8000-000000000003'),'third ballot reaches quorum');
select throws_ok(format('select public.finalize_election_round(%L)',(select round from ids)),'42501',null,'ordinary elector cannot finalize an open round');
set local role postgres;
select is((select status::text from public.election_rounds where id=(select round from ids)),'voting','unauthorized finalization cannot cause failed quorum or close voting');
select lives_ok(format('select public.close_election_round(%L)',(select round from ids)),'internal authority closes a genuinely finalizable round');
select is(public.finalize_election_round((select round from ids))::text,'completed','deterministic top three completes the election');
select is((select count(*) from public.election_winners where cycle_id=(select cycle from ids)),3::bigint,'three positive-score winners recorded');
select throws_ok(format('select public.finalize_election_round(%L)',(select round from ids)),'55000','Election round is already finalized','repeat finalization rejected');
select throws_ok(format('select public.submit_election_ballot(%L,array[]::uuid[])',(select round from ids)),'55000','Voting is closed','vote after finalization rejected');

select is(public.election_quorum_threshold(5),3,'quorum boundary 5');
select is(public.election_quorum_threshold(10),3,'quorum boundary 10');
select is(public.election_quorum_threshold(15),3,'quorum boundary 15');
select is(public.election_quorum_threshold(16),4,'quorum boundary 16');
select is(public.election_quorum_threshold(20),4,'quorum boundary 20');
select is(public.election_quorum_threshold(21),5,'quorum boundary 21');
select ok(not has_table_privilege('authenticated','public.election_ballots','select') and not has_table_privilege('authenticated','public.election_ballot_approvals','select'),'authenticated roles cannot read voter-choice storage');
select ok(has_function_privilege('authenticated','public.get_election_result(uuid)','execute'),'members can access aggregate result RPC');
select ok(not has_function_privilege('authenticated','public.close_election_round(uuid)','execute') and not has_function_privilege('authenticated','public.finalize_election_round(uuid)','execute'),'browser roles cannot close or finalize rounds');
set local role authenticated;
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000001',true);
select throws_ok('select * from public.election_ballot_approvals','42501','permission denied for table election_ballot_approvals','owner cannot read ballot choices');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000002',true);
select throws_ok('select * from public.election_ballot_approvals','42501','permission denied for table election_ballot_approvals','appointed admin cannot read ballot choices');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000003',true);
select throws_ok('select * from public.election_ballot_approvals','42501','permission denied for table election_ballot_approvals','candidate cannot read ballot choices');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000005',true);
select throws_ok('select * from public.election_ballot_approvals','42501','permission denied for table election_ballot_approvals','ordinary member cannot read ballot choices');
select set_config('request.jwt.claim.sub','55000000-0000-4000-8000-000000000024',true);
select is((select count(*) from public.get_election_result((select cycle from ids))),0::bigint,'outsider cannot read aggregate result');

select * from finish();
rollback;
