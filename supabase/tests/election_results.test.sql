begin;
select plan(49);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
select ('56000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 '00000000-0000-0000-0000-000000000000','authenticated','authenticated','result-'||n||'@example.test',''
from generate_series(1,8)n;
insert into public.communities(id,name,owner_id,governance_state) values
 ('56100000-0000-4000-8000-000000000001','Result community','56000000-0000-4000-8000-000000000001','democratic_transition');
insert into public.memberships(community_id,user_id,role,status)
select '56100000-0000-4000-8000-000000000001',('56000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'member','active' from generate_series(1,8)n;

create temporary table cycles(label text primary key,id uuid,round_id uuid);
grant select on table pg_temp.cycles to authenticated;
insert into cycles values ('too-few',public.create_election_cycle('56100000-0000-4000-8000-000000000001',3),null);
select throws_ok(format('select public.freeze_election_cycle(%L)',(select id from cycles where label='too-few')),'55000','At least three candidates are required','zero candidates cannot freeze');
insert into public.election_candidacies select (select id from cycles where label='too-few'),'56100000-0000-4000-8000-000000000001','56000000-0000-4000-8000-000000000001',now();
select throws_ok(format('select public.freeze_election_cycle(%L)',(select id from cycles where label='too-few')),'55000','At least three candidates are required','one candidate cannot freeze');
insert into public.election_candidacies select (select id from cycles where label='too-few'),'56100000-0000-4000-8000-000000000001','56000000-0000-4000-8000-000000000002',now();
select throws_ok(format('select public.freeze_election_cycle(%L)',(select id from cycles where label='too-few')),'55000','At least three candidates are required','two candidates cannot freeze');
delete from public.election_cycles where id=(select id from cycles where label='too-few');

update cycles set id=public.create_election_cycle('56100000-0000-4000-8000-000000000001',5) where label='too-few';
insert into public.election_candidacies select (select id from cycles where label='too-few'),'56100000-0000-4000-8000-000000000001',('56000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,now() from generate_series(1,3)n;
select lives_ok(format('select public.freeze_election_cycle(%L)',(select id from cycles where label='too-few')),'exactly three candidates can freeze a five-seat target');
delete from public.election_cycles where id=(select id from cycles where label='too-few');

update cycles set id=public.create_election_cycle('56100000-0000-4000-8000-000000000001',3) where label='too-few';
insert into public.election_candidacies select (select id from cycles where label='too-few'),'56100000-0000-4000-8000-000000000001',('56000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,now() from generate_series(1,4)n;
update cycles set round_id=public.freeze_election_cycle(id) where label='too-few';
select lives_ok('select 1','more candidates than seats are accepted');

set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L::uuid,%L::uuid,%L::uuid])',(select round_id from cycles),'56000000-0000-4000-8000-000000000001','56000000-0000-4000-8000-000000000002','56000000-0000-4000-8000-000000000003'),'first tie fixture ballot');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000002',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L::uuid,%L::uuid,%L::uuid])',(select round_id from cycles),'56000000-0000-4000-8000-000000000001','56000000-0000-4000-8000-000000000002','56000000-0000-4000-8000-000000000004'),'second tie fixture ballot');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000003',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L::uuid])',(select round_id from cycles),'56000000-0000-4000-8000-000000000001'),'third tie fixture ballot');
set local role postgres;
select lives_ok(format('select public.close_election_round(%L)',(select round_id from cycles)),'authoritative close precedes counting');
select is(public.finalize_election_round((select round_id from cycles))::text,'runoff_required','tie crossing the final seat requires runoff');
select is((select count(*) from public.election_candidate_results where round_id=(select round_id from cycles) and is_runoff_candidate),2::bigint,'runoff is limited to the two boundary candidates');
select is((select count(*) from public.election_provisional_winners where cycle_id=(select id from cycles)),2::bigint,'only candidates above the boundary are provisionally carried forward');
select is((select count(*) from public.election_winners where cycle_id=(select id from cycles)),0::bigint,'unresolved runoff exposes no final elected winners');
select is((select electorate_count from public.election_rounds where cycle_id=(select id from cycles) and round_number=2),8,'runoff preserves electorate snapshot size');
select is((select seats_available from public.election_rounds where cycle_id=(select id from cycles) and round_number=2),1::smallint,'runoff fills only unresolved seat');
select is((select count(*) from public.election_ballots b join public.election_rounds r on r.id=b.round_id where r.cycle_id=(select id from cycles) and r.round_number=2),0::bigint,'initial ballots are not reused in runoff');
set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);
select lives_ok(format('select public.submit_election_ballot((select id from public.election_rounds where cycle_id=%L and round_number=2),array[%L::uuid])',(select id from cycles),'56000000-0000-4000-8000-000000000003'),'same elector may cast a fresh runoff ballot');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000002',true);
select lives_ok(format('select public.submit_election_ballot((select id from public.election_rounds where cycle_id=%L and round_number=2),array[%L::uuid])',(select id from cycles),'56000000-0000-4000-8000-000000000003'),'second runoff ballot');
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000003',true);
select lives_ok(format('select public.submit_election_ballot((select id from public.election_rounds where cycle_id=%L and round_number=2),array[%L::uuid])',(select id from cycles),'56000000-0000-4000-8000-000000000004'),'third runoff ballot reaches quorum');
set local role postgres;
select public.close_election_round(id) from public.election_rounds where cycle_id=(select id from cycles) and round_number=2;
select is(public.finalize_election_round((select id from public.election_rounds where cycle_id=(select id from cycles) and round_number=2))::text,'completed','runoff resolves the cycle');
select is((select count(*) from public.election_winners where cycle_id=(select id from cycles)),3::bigint,'successful founding cycle materializes exactly three final winners');
select is((select count(distinct candidate_id) from public.get_election_result((select id from cycles)) where final_elected),3::bigint,'round-scoped result identifies exactly three distinct final winners');
select is((select governance_state::text from public.communities where id='56100000-0000-4000-8000-000000000001'),'democratic_transition','election mechanics never change governance state');
select ok((select bool_and(approval_count > 0) from public.election_winners where cycle_id=(select id from cycles)),'zero-approval candidates are never winners');

-- A failed runoff may retain transparent provisional data, but never materializes or exposes a
-- one/two-person founding council as final elected winners.
set local role postgres;
insert into cycles values ('failed-runoff',public.create_election_cycle('56100000-0000-4000-8000-000000000001',3),null);
insert into public.election_candidacies select (select id from cycles where label='failed-runoff'),'56100000-0000-4000-8000-000000000001',('56000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,now() from generate_series(1,4)n;
update cycles set round_id=public.freeze_election_cycle(id) where label='failed-runoff';
set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);
select public.submit_election_ballot((select round_id from cycles where label='failed-runoff'),array['56000000-0000-4000-8000-000000000001'::uuid,'56000000-0000-4000-8000-000000000002'::uuid,'56000000-0000-4000-8000-000000000003'::uuid]);
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000002',true);
select public.submit_election_ballot((select round_id from cycles where label='failed-runoff'),array['56000000-0000-4000-8000-000000000001'::uuid,'56000000-0000-4000-8000-000000000002'::uuid,'56000000-0000-4000-8000-000000000004'::uuid]);
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000003',true);
select public.submit_election_ballot((select round_id from cycles where label='failed-runoff'),array['56000000-0000-4000-8000-000000000001'::uuid]);
set local role postgres;
select public.close_election_round((select round_id from cycles where label='failed-runoff'));
select is(public.finalize_election_round((select round_id from cycles where label='failed-runoff'))::text,'runoff_required','second fixture creates a boundary runoff');
select public.close_election_round(id) from public.election_rounds where cycle_id=(select id from cycles where label='failed-runoff') and round_number=2;
select is(public.finalize_election_round((select id from public.election_rounds where cycle_id=(select id from cycles where label='failed-runoff') and round_number=2))::text,'failed_quorum','runoff can fail quorum authoritatively');
select is((select count(*) from public.election_winners where cycle_id=(select id from cycles where label='failed-runoff')),0::bigint,'failed runoff materializes no final winners');
set local role authenticated;
select set_config('request.jwt.claim.sub','56000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.get_election_result((select id from cycles where label='failed-runoff')) where final_elected),0::bigint,'aggregate RPC exposes no elected members for failed founding cycle');

set local role postgres;
create function pg_temp.prepare_outcome(fixture_label text, fixture_target integer, electable_count integer)
returns uuid language plpgsql as $$
declare fixture_cycle uuid; fixture_round uuid; ballot uuid; voter_number integer;
begin
  fixture_cycle := public.create_election_cycle('56100000-0000-4000-8000-000000000001', fixture_target);
  insert into cycles values(fixture_label,fixture_cycle,null);
  insert into public.election_candidacies
    select fixture_cycle,'56100000-0000-4000-8000-000000000001',('56000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,now()
    from generate_series(1,6)n;
  fixture_round := public.freeze_election_cycle(fixture_cycle);
  update cycles set round_id=fixture_round where label=fixture_label;
  for voter_number in 6..8 loop
    insert into public.election_ballots(round_id,voter_id)
      values(fixture_round,('56000000-0000-4000-8000-'||lpad(voter_number::text,12,'0'))::uuid) returning id into ballot;
    insert into public.election_ballot_approvals(ballot_id,round_id,candidate_id)
      select ballot,fixture_round,('56000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid
      from generate_series(1,electable_count)n;
  end loop;
  perform public.close_election_round(fixture_round);
  return fixture_cycle;
end $$;

select pg_temp.prepare_outcome('target5-three',5,3);
select is(public.finalize_election_round((select round_id from cycles where label='target5-three'))::text,'completed','target five accepts exactly three electable winners');
select is((select count(*) from public.election_winners where cycle_id=(select id from cycles where label='target5-three')),3::bigint,'target five leaves two seats vacant with three winners');
select ok((select bool_and(approval_count>0) from public.election_winners where cycle_id=(select id from cycles where label='target5-three')),'target-five three-winner result contains only positive approvals');
select is((select count(*) from public.election_winners where cycle_id=(select id from cycles where label='target5-three') and candidate_id in ('56000000-0000-4000-8000-000000000004','56000000-0000-4000-8000-000000000005','56000000-0000-4000-8000-000000000006')),0::bigint,'zero-score candidates do not fill target-five vacancies');

select pg_temp.prepare_outcome('target5-four',5,4);
select is(public.finalize_election_round((select round_id from cycles where label='target5-four'))::text,'completed','target five accepts exactly four electable winners');
select is((select count(*) from public.election_winners where cycle_id=(select id from cycles where label='target5-four')),4::bigint,'target five leaves one seat vacant with four winners');
select ok((select bool_and(approval_count>0) from public.election_winners where cycle_id=(select id from cycles where label='target5-four')),'target-five four-winner result contains only positive approvals');
select is((select count(*) from public.election_winners where cycle_id=(select id from cycles where label='target5-four') and candidate_id in ('56000000-0000-4000-8000-000000000005','56000000-0000-4000-8000-000000000006')),0::bigint,'target five does not fill its remaining vacancy artificially');

select pg_temp.prepare_outcome('target5-five',5,5);
select is(public.finalize_election_round((select round_id from cycles where label='target5-five'))::text,'completed','target five accepts five electable winners');
select is((select count(*) from public.election_winners where cycle_id=(select id from cycles where label='target5-five')),5::bigint,'target five materializes all five positive winners');
select ok((select bool_and(approval_count>0) from public.election_winners where cycle_id=(select id from cycles where label='target5-five')),'complete target-five result contains only positive approvals');
select is((select count(*) from public.election_winners where cycle_id=(select id from cycles where label='target5-five') and candidate_id='56000000-0000-4000-8000-000000000006'),0::bigint,'sixth zero-score candidate is not elected');

select pg_temp.prepare_outcome('insufficient-two',3,2);
select is(public.finalize_election_round((select round_id from cycles where label='insufficient-two'))::text,'insufficient_winners','quorum with only two electable candidates executes insufficient-winners branch');
select is((select status::text from public.election_rounds where id=(select round_id from cycles where label='insufficient-two')),'insufficient_winners','insufficient-winners round is terminal');
select is((select status::text from public.election_cycles where id=(select id from cycles where label='insufficient-two')),'failed','insufficient-winners cycle fails');
select is((select count(*) from public.election_winners where cycle_id=(select id from cycles where label='insufficient-two')),0::bigint,'insufficient-winners cycle materializes no final winners');
select is((select count(*) from public.get_election_result((select id from cycles where label='insufficient-two')) where final_elected),0::bigint,'insufficient-winners aggregate exposes no false council');

-- Three ballots produce scores 3,2,2,1. The tie at scores 2 fills both remaining seats and is not ambiguous.
select pg_temp.prepare_outcome('inside-tie',3,0);
insert into public.election_ballot_approvals(ballot_id,round_id,candidate_id)
select b.id,b.round_id,c.candidate_id from public.election_ballots b
join lateral (select candidate_id from public.election_candidates where cycle_id=(select id from cycles where label='inside-tie') order by candidate_id limit 3) c on true
where b.round_id=(select round_id from cycles where label='inside-tie') and b.voter_id in ('56000000-0000-4000-8000-000000000006','56000000-0000-4000-8000-000000000007');
insert into public.election_ballot_approvals(ballot_id,round_id,candidate_id)
select b.id,b.round_id,candidate_id from public.election_ballots b
join public.election_candidates c on c.cycle_id=(select id from cycles where label='inside-tie')
where b.round_id=(select round_id from cycles where label='inside-tie') and b.voter_id='56000000-0000-4000-8000-000000000008'
  and c.candidate_id in ('56000000-0000-4000-8000-000000000001','56000000-0000-4000-8000-000000000004');
select is(public.finalize_election_round((select round_id from cycles where label='inside-tie'))::text,'completed','tie wholly inside occupied positions creates no runoff');
select is((select count(*) from public.election_rounds where cycle_id=(select id from cycles where label='inside-tie')),1::bigint,'non-ambiguous 3,2,2,1 score set stays in one round');
select is((select count(*) from public.election_winners where cycle_id=(select id from cycles where label='inside-tie')),3::bigint,'non-ambiguous tie yields three final winners');
select is((select status::text from public.election_cycles where id=(select id from cycles where label='inside-tie')),'completed','non-ambiguous tie completes cycle');

select * from finish();
rollback;
