begin;
select plan(52);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
select ('61000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 '00000000-0000-0000-0000-000000000000','authenticated','authenticated','reconstitution-'||n||'@example.test',''
from generate_series(1,8)n;

set local role postgres;
insert into public.communities(id,name,owner_id,governance_state,council_target_size)
select ('61100000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'Reconstitution lifecycle '||n,
 '61000000-0000-4000-8000-000000000008','democratic',case when n=4 then 5 else 3 end
from generate_series(1,5)n;
insert into public.memberships(community_id,user_id,role,status)
select c.id,u,'member','active' from public.communities c cross join unnest(array[
 '61000000-0000-4000-8000-000000000001'::uuid,'61000000-0000-4000-8000-000000000002',
 '61000000-0000-4000-8000-000000000003','61000000-0000-4000-8000-000000000004',
 '61000000-0000-4000-8000-000000000005','61000000-0000-4000-8000-000000000006',
 '61000000-0000-4000-8000-000000000007','61000000-0000-4000-8000-000000000008'])u
where c.id::text like '61100000-0000-4000-8000-%';
insert into public.election_cycles(id,community_id,target_seats,status,purpose,completed_at)
select ('61200000-0000-4000-8000-'||right(c.id::text,12))::uuid,c.id,c.council_target_size,'completed','founding',now()
from public.communities c where c.id::text like '61100000-0000-4000-8000-%';
insert into public.election_winners(cycle_id,candidate_id,elected_in_round,approval_count)
select e.id,u,1,1 from public.election_cycles e join lateral (
 select u from unnest(array['61000000-0000-4000-8000-000000000001'::uuid,
 '61000000-0000-4000-8000-000000000002','61000000-0000-4000-8000-000000000003']) with ordinality x(u,n)
 where n<=case when right(e.community_id::text,1)='4' then 3 else 1 end) winners on true
where e.id::text like '61200000-0000-4000-8000-%';
insert into public.elected_councils(id,community_id,source_cycle_id,target_seats,took_office_at,nominal_term_ends_at)
select ('61300000-0000-4000-8000-'||right(c.id::text,12))::uuid,c.id,e.id,c.council_target_size,now(),now()+interval '12 months'
from public.communities c join public.election_cycles e on e.community_id=c.id and e.purpose='founding'
where c.id::text like '61100000-0000-4000-8000-%';
insert into public.elected_council_mandates(council_id,community_id,member_id,source_cycle_id,took_office_at,nominal_term_ends_at)
select ec.id,ec.community_id,w.candidate_id,w.cycle_id,now(),now()+interval '12 months'
from public.elected_councils ec join public.election_winners w on w.cycle_id=ec.source_cycle_id
where ec.id::text like '61300000-0000-4000-8000-%';

-- Full path: one existing mandate plus two winners restores a target-three council.
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000004',true);
select set_config('test.full_cycle',public.open_council_reconstitution_cycle('61100000-0000-4000-8000-000000000001')::text,true);
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000002',true);
select lives_ok(format('select public.stand_for_election(%L)',current_setting('test.full_cycle')),'first eligible candidate stands');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000003',true);
select lives_ok(format('select public.stand_for_election(%L)',current_setting('test.full_cycle')),'second eligible candidate stands');
set local role postgres;
select set_config('test.full_round',public.freeze_election_cycle(current_setting('test.full_cycle')::uuid)::text,true);
select is((select seats_available from public.election_rounds where id=current_setting('test.full_round')::uuid),2::smallint,'round fills two vacancies');
select is((select count(*) from public.election_electorate where cycle_id=current_setting('test.full_cycle')::uuid),8::bigint,'active electorate is frozen');
select is((select count(*) from public.election_candidates where cycle_id=current_setting('test.full_cycle')::uuid),2::bigint,'eligible candidates are frozen');
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000001',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L,%L]::uuid[])',current_setting('test.full_round'),
 '61000000-0000-4000-8000-000000000002','61000000-0000-4000-8000-000000000003'),'two approvals are accepted');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000004',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L,%L]::uuid[])',current_setting('test.full_round'),
 '61000000-0000-4000-8000-000000000002','61000000-0000-4000-8000-000000000003'),'second ballot recorded');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000005',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L,%L]::uuid[])',current_setting('test.full_round'),
 '61000000-0000-4000-8000-000000000002','61000000-0000-4000-8000-000000000003'),'quorum ballot recorded');
set local role service_role;
select is(public.finalize_reconstitution_round(current_setting('test.full_round')::uuid)::text,'completed','authoritative finalization completes');
set local role postgres;
select is(public.active_elected_mandate_count('61100000-0000-4000-8000-000000000001'),3,'existing plus two new mandates are active');
select is((select count(*) from public.elected_council_mandates where community_id='61100000-0000-4000-8000-000000000001'
 and source_cycle_id=current_setting('test.full_cycle')::uuid),2::bigint,'exactly two new mandates installed');
select is((select count(*) from public.elected_council_mandates where community_id='61100000-0000-4000-8000-000000000001'
 and member_id='61000000-0000-4000-8000-000000000001' and ended_at is null),1::bigint,'existing mandate is preserved');
select is((select count(*) from public.elected_councils where community_id='61100000-0000-4000-8000-000000000001'),1::bigint,'existing council institution is preserved');
select is(public.council_operational_status('61100000-0000-4000-8000-000000000001')::text,'operational','three active restores operation');
select is((select governance_state::text from public.communities where id='61100000-0000-4000-8000-000000000001'),'democratic','reconstitution remains democratic');

-- Failed quorum preserves the single active mandate and permits a later member-driven cycle.
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000004',true);
select set_config('test.failed_cycle',public.open_council_reconstitution_cycle('61100000-0000-4000-8000-000000000002')::text,true);
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000002',true);
select lives_ok(format('select public.stand_for_election(%L)',current_setting('test.failed_cycle')),'failed-cycle candidate stands');
set local role postgres;
select set_config('test.failed_round',public.freeze_election_cycle(current_setting('test.failed_cycle')::uuid)::text,true);
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000004',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L]::uuid[])',current_setting('test.failed_round'),
 '61000000-0000-4000-8000-000000000002'),'one sub-quorum ballot records');
set local role service_role;
select is(public.finalize_reconstitution_round(current_setting('test.failed_round')::uuid)::text,'failed_quorum','sub-quorum reconstitution fails');
set local role postgres;
select is(public.active_elected_mandate_count('61100000-0000-4000-8000-000000000002'),1,'failed quorum preserves existing mandate');
select is(public.council_vacant_seat_count('61100000-0000-4000-8000-000000000002'),2,'failed quorum preserves vacancies');
select is((select governance_state::text from public.communities where id='61100000-0000-4000-8000-000000000002'),'democratic','failed quorum remains democratic');
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000005',true);
select lives_ok($$select public.open_council_reconstitution_cycle('61100000-0000-4000-8000-000000000002')$$,'later reconstitution remains accessible');

-- A partial positive result installs one winner and correctly remains under strength.
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000004',true);
select set_config('test.partial_cycle',public.open_council_reconstitution_cycle('61100000-0000-4000-8000-000000000003')::text,true);
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000002',true);
select lives_ok(format('select public.stand_for_election(%L)',current_setting('test.partial_cycle')),'partial-result candidate stands');
set local role postgres;
select set_config('test.partial_round',public.freeze_election_cycle(current_setting('test.partial_cycle')::uuid)::text,true);
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000004',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L]::uuid[])',current_setting('test.partial_round'),'61000000-0000-4000-8000-000000000002'),'partial ballot one');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000005',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L]::uuid[])',current_setting('test.partial_round'),'61000000-0000-4000-8000-000000000002'),'partial ballot two');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000006',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L]::uuid[])',current_setting('test.partial_round'),'61000000-0000-4000-8000-000000000002'),'partial ballot reaches quorum');
set local role service_role;
select is(public.finalize_reconstitution_round(current_setting('test.partial_round')::uuid)::text,'completed','one positive winner is a valid partial fill');
set local role postgres;
select is(public.active_elected_mandate_count('61100000-0000-4000-8000-000000000003'),2,'partial fill produces two active mandates total');
select is(public.council_operational_status('61100000-0000-4000-8000-000000000003')::text,'under_strength','partial fill remains under strength');

-- A target-five council with two vacancies enforces max approvals = two.
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000004',true);
select set_config('test.max_cycle',public.open_council_reconstitution_cycle('61100000-0000-4000-8000-000000000004')::text,true);
select lives_ok(format('select public.stand_for_election(%L)',current_setting('test.max_cycle')),'first max-approval candidate stands');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000005',true);
select lives_ok(format('select public.stand_for_election(%L)',current_setting('test.max_cycle')),'second max-approval candidate stands');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000006',true);
select lives_ok(format('select public.stand_for_election(%L)',current_setting('test.max_cycle')),'third max-approval candidate stands');
set local role postgres;
select set_config('test.max_round',public.freeze_election_cycle(current_setting('test.max_cycle')::uuid)::text,true);
select is((select seats_available from public.election_rounds where id=current_setting('test.max_round')::uuid),2::smallint,'target five with three active exposes two seats');
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000007',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L,%L]::uuid[])',current_setting('test.max_round'),
 '61000000-0000-4000-8000-000000000004','61000000-0000-4000-8000-000000000005'),'two approvals are allowed for two vacancies');
select throws_ok(format('select public.submit_election_ballot(%L,array[%L,%L,%L]::uuid[])',current_setting('test.max_round'),
 '61000000-0000-4000-8000-000000000004','61000000-0000-4000-8000-000000000005','61000000-0000-4000-8000-000000000006'),
 '22023','Too many approvals','three approvals are rejected for two vacancies');

-- A tie at the last vacancy produces a one-seat runoff and no random winner.
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000002',true);
select set_config('test.runoff_cycle',public.open_council_reconstitution_cycle('61100000-0000-4000-8000-000000000005')::text,true);
select lives_ok(format('select public.stand_for_election(%L)',current_setting('test.runoff_cycle')),'runoff leading candidate stands');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000003',true);
select lives_ok(format('select public.stand_for_election(%L)',current_setting('test.runoff_cycle')),'runoff tied candidate one stands');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000004',true);
select lives_ok(format('select public.stand_for_election(%L)',current_setting('test.runoff_cycle')),'runoff tied candidate two stands');
set local role postgres;
select set_config('test.runoff_round',public.freeze_election_cycle(current_setting('test.runoff_cycle')::uuid)::text,true);
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000001',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L,%L]::uuid[])',current_setting('test.runoff_round'),'61000000-0000-4000-8000-000000000002','61000000-0000-4000-8000-000000000003'),'runoff ballot one');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000005',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L,%L]::uuid[])',current_setting('test.runoff_round'),'61000000-0000-4000-8000-000000000002','61000000-0000-4000-8000-000000000004'),'runoff ballot two');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000006',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L,%L]::uuid[])',current_setting('test.runoff_round'),'61000000-0000-4000-8000-000000000002','61000000-0000-4000-8000-000000000003'),'runoff ballot three');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000007',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L,%L]::uuid[])',current_setting('test.runoff_round'),'61000000-0000-4000-8000-000000000002','61000000-0000-4000-8000-000000000004'),'runoff ballot four');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000008',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L]::uuid[])',current_setting('test.runoff_round'),'61000000-0000-4000-8000-000000000002'),'runoff ballot five');
set local role service_role;
select is(public.finalize_reconstitution_round(current_setting('test.runoff_round')::uuid)::text,'runoff_required','last-seat tie requires runoff');
set local role postgres;
select set_config('test.runoff_final_round',(select id::text from public.election_rounds where cycle_id=current_setting('test.runoff_cycle')::uuid and round_number=2),true);
select is((select seats_available from public.election_rounds where id=current_setting('test.runoff_final_round')::uuid),1::smallint,'runoff fills only tied last seat');
select is((select count(*) from public.election_round_candidates where round_id=current_setting('test.runoff_final_round')::uuid),2::bigint,'runoff contains only tied candidates');
select is((select count(*) from public.elected_council_mandates where source_cycle_id=current_setting('test.runoff_cycle')::uuid),0::bigint,'unresolved runoff installs no mandate');
set local role authenticated;
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000001',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L]::uuid[])',current_setting('test.runoff_final_round'),'61000000-0000-4000-8000-000000000003'),'final runoff ballot one');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000005',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L]::uuid[])',current_setting('test.runoff_final_round'),'61000000-0000-4000-8000-000000000003'),'final runoff ballot two');
select set_config('request.jwt.claim.sub','61000000-0000-4000-8000-000000000006',true);
select lives_ok(format('select public.submit_election_ballot(%L,array[%L]::uuid[])',current_setting('test.runoff_final_round'),'61000000-0000-4000-8000-000000000003'),'final runoff quorum ballot');
set local role service_role;
select is(public.finalize_reconstitution_round(current_setting('test.runoff_final_round')::uuid)::text,'completed','resolved runoff completes and installs');
set local role postgres;
select is((select count(*) from public.elected_council_mandates where source_cycle_id=current_setting('test.runoff_cycle')::uuid),2::bigint,'provisional and runoff winners fill two vacancies');

select * from finish();
rollback;
