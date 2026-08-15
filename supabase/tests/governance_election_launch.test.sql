begin;
select plan(23);
insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
select ('58000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','launch-'||n||'@example.test','' from generate_series(1,8)n;
set local role postgres;
insert into public.communities(id,name,owner_id,governance_state,council_target_size)
values
 ('58100000-0000-4000-8000-000000000001','Retry launch','58000000-0000-4000-8000-000000000001','democratic_transition',3),
 ('58100000-0000-4000-8000-000000000002','Reconstitution launch','58000000-0000-4000-8000-000000000008','democratic',5);
insert into public.memberships(community_id,user_id,role,status,display_name)
select community_id,user_id,case when community_id='58100000-0000-4000-8000-000000000001'
 and user_id='58000000-0000-4000-8000-000000000002' then 'admin'::public.membership_role else 'member' end,
 'active','Launch member '||right(user_id::text,1)
from (select '58100000-0000-4000-8000-000000000001'::uuid community_id,
 ('58000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid user_id from generate_series(1,5)n
 union all select '58100000-0000-4000-8000-000000000002',
 ('58000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,8)n) members;
insert into public.election_cycles(id,community_id,target_seats,status,purpose,completed_at)
values
 ('58200000-0000-4000-8000-000000000001','58100000-0000-4000-8000-000000000002',5,'completed','founding',now()),
 ('58200000-0000-4000-8000-000000000002','58100000-0000-4000-8000-000000000001',3,'candidacy','founding',null);
update public.communities set active_election_cycle_id='58200000-0000-4000-8000-000000000002'
 where id='58100000-0000-4000-8000-000000000001';
insert into public.election_winners(cycle_id,candidate_id,elected_in_round,approval_count)
select '58200000-0000-4000-8000-000000000001',('58000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,1,1
from generate_series(1,3)n;
insert into public.elected_councils(id,community_id,source_cycle_id,target_seats,took_office_at,nominal_term_ends_at)
values('58300000-0000-4000-8000-000000000001','58100000-0000-4000-8000-000000000002',
 '58200000-0000-4000-8000-000000000001',5,now(),now()+interval '12 months');
insert into public.elected_council_mandates(council_id,community_id,member_id,source_cycle_id,took_office_at,nominal_term_ends_at)
select '58300000-0000-4000-8000-000000000001','58100000-0000-4000-8000-000000000002',candidate_id,cycle_id,now(),now()+interval '12 months'
from public.election_winners where cycle_id='58200000-0000-4000-8000-000000000001';
insert into public.election_candidacies(cycle_id,community_id,candidate_id)
select '58200000-0000-4000-8000-000000000002','58100000-0000-4000-8000-000000000001',
 ('58000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,3)n;

set local role authenticated;
select set_config('request.jwt.claim.sub','58000000-0000-4000-8000-000000000001',true);
select ok(not (select may_approve_memberships from public.get_community_governance_ui('58100000-0000-4000-8000-000000000001')),
 'historical owner without caretaker role has no transition controls');
select set_config('request.jwt.claim.sub','58000000-0000-4000-8000-000000000002',true);
select ok((select may_approve_memberships and may_moderate_community from public.get_community_governance_ui('58100000-0000-4000-8000-000000000001')),
 'transition appointed administrator receives caretaker continuity controls');
select set_config('request.jwt.claim.sub','58000000-0000-4000-8000-000000000004',true);
select set_config('test.retry_round',public.launch_current_election('58100000-0000-4000-8000-000000000001','58200000-0000-4000-8000-000000000002')::text,true);
select ok(current_setting('test.retry_round')::uuid is not null,'ordinary active member launches founding retry');
select is((select status::text from public.election_cycles where id='58200000-0000-4000-8000-000000000002'),'voting','retry cycle enters voting');
select is((select seats_available from public.election_rounds where id=current_setting('test.retry_round')::uuid),3::smallint,'retry round fills founding target');
select lives_ok($$select public.submit_election_ballot(current_setting('test.retry_round')::uuid,array['58000000-0000-4000-8000-000000000001'::uuid])$$,'retry ballot submission works');
select throws_ok($$select public.launch_current_election('58100000-0000-4000-8000-000000000001','58200000-0000-4000-8000-000000000002')$$,
 '55000','Authoritative candidacy cycle required','repeated launch creates no second round');
select is((select count(*) from public.election_rounds where cycle_id='58200000-0000-4000-8000-000000000002'),1::bigint,'retry has exactly one first round');
select set_config('request.jwt.claim.sub','58000000-0000-4000-8000-000000000008',true);
select throws_ok($$select public.launch_current_election('58100000-0000-4000-8000-000000000001','58200000-0000-4000-8000-000000000002')$$,
 '42501','Active community membership required','cross-community launch is rejected');

select set_config('request.jwt.claim.sub','58000000-0000-4000-8000-000000000004',true);
select set_config('test.reconstitution_cycle',public.open_council_reconstitution_cycle('58100000-0000-4000-8000-000000000002')::text,true);
select set_config('request.jwt.claim.sub','58000000-0000-4000-8000-000000000004',true);
select public.stand_for_election(current_setting('test.reconstitution_cycle')::uuid);
select set_config('request.jwt.claim.sub','58000000-0000-4000-8000-000000000005',true);
select public.stand_for_election(current_setting('test.reconstitution_cycle')::uuid);
select is((select cycle_seats_to_fill from public.get_community_governance_ui('58100000-0000-4000-8000-000000000002')),2::smallint,'read model projects exactly two vacancies before voting');
select is((select valid_candidate_count from public.get_community_governance_ui('58100000-0000-4000-8000-000000000002')),2,'read model counts eligible reconstitution candidates');
select ok((select may_launch_current_election from public.get_community_governance_ui('58100000-0000-4000-8000-000000000002')),'active member may launch reconstitution');
select set_config('test.reconstitution_round',public.launch_current_election('58100000-0000-4000-8000-000000000002',current_setting('test.reconstitution_cycle')::uuid)::text,true);
select is((select status::text from public.election_cycles where id=current_setting('test.reconstitution_cycle')::uuid),'voting','reconstitution enters voting');
select is((select seats_available from public.election_rounds where id=current_setting('test.reconstitution_round')::uuid),2::smallint,'reconstitution round fills only vacancies');
select lives_ok($$select public.submit_election_ballot(current_setting('test.reconstitution_round')::uuid,array['58000000-0000-4000-8000-000000000004'::uuid,'58000000-0000-4000-8000-000000000005'::uuid])$$,'reconstitution voting works');
select throws_ok($$select public.submit_election_ballot(current_setting('test.reconstitution_round')::uuid,array[
 '58000000-0000-4000-8000-000000000004'::uuid,'58000000-0000-4000-8000-000000000005'::uuid,'58000000-0000-4000-8000-000000000006'::uuid])$$,
 '23505',null,'one voter still gets one ballot per round');
select is((select count(*) from public.election_rounds where cycle_id=current_setting('test.reconstitution_cycle')::uuid),1::bigint,'reconstitution has exactly one first round');

set local role postgres;
select set_config('request.jwt.claim.sub','58000000-0000-4000-8000-000000000001',true);
select ok(public.has_elected_council_authority('58100000-0000-4000-8000-000000000002'),'operational elected councillor has ordinary authority');
set local role authenticated;
select ok((select may_approve_memberships from public.get_community_governance_ui('58100000-0000-4000-8000-000000000002')),
 'operational councillor sees administration controls');
select set_config('request.jwt.claim.sub','58000000-0000-4000-8000-000000000008',true);
select ok(not (select may_approve_memberships from public.get_community_governance_ui('58100000-0000-4000-8000-000000000002')),
 'historical owner not elected receives no democratic controls');
set local role postgres;
update public.elected_council_mandates set ended_at=now(),ended_reason='resignation'
 where community_id='58100000-0000-4000-8000-000000000002' and member_id in
 ('58000000-0000-4000-8000-000000000002','58000000-0000-4000-8000-000000000003');
set local role authenticated;
select set_config('request.jwt.claim.sub','58000000-0000-4000-8000-000000000001',true);
select ok((select may_approve_memberships and not may_manage_appointed_admins from public.get_community_governance_ui('58100000-0000-4000-8000-000000000002')),
 'under-strength elected caretaker sees continuity controls only');
set local role postgres;
update public.elected_council_mandates set ended_at=now(),ended_reason='resignation'
 where community_id='58100000-0000-4000-8000-000000000002' and ended_at is null;
set local role authenticated;
select set_config('request.jwt.claim.sub','58000000-0000-4000-8000-000000000008',true);
select ok(not (select may_approve_memberships or may_moderate_community from public.get_community_governance_ui('58100000-0000-4000-8000-000000000002')),
 'vacant democratic council gives historical owner no fallback controls');
set local role postgres;
-- A stale candidacy is removed from progress and blocks founding launch capability.
update public.memberships set status='pending' where community_id='58100000-0000-4000-8000-000000000001' and user_id='58000000-0000-4000-8000-000000000003';
select is((select count(*) from public.election_candidates where cycle_id='58200000-0000-4000-8000-000000000002'),3::bigint,'frozen authoritative snapshot remains unchanged after launch');
select * from finish();
rollback;
