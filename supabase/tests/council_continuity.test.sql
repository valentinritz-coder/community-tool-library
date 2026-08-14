begin;
select plan(25);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
select ('60000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 '00000000-0000-0000-0000-000000000000','authenticated','authenticated','continuity-'||n||'@example.test',''
from generate_series(1,7)n;

set local role postgres;
insert into public.communities(id,name,owner_id,governance_state,council_target_size)
values('60100000-0000-4000-8000-000000000001','Continuity fixture','60000000-0000-4000-8000-000000000007','democratic',5);
insert into public.memberships(community_id,user_id,role,status)
select '60100000-0000-4000-8000-000000000001',id,
 case when id='60000000-0000-4000-8000-000000000006' then 'admin'::public.membership_role else 'member' end,'active'
from auth.users where id::text like '60000000-0000-4000-8000-%';
insert into public.election_cycles(id,community_id,target_seats,status,purpose,completed_at)
values('60200000-0000-4000-8000-000000000001','60100000-0000-4000-8000-000000000001',5,'completed','founding',now());
insert into public.election_winners(cycle_id,candidate_id,elected_in_round,approval_count)
select '60200000-0000-4000-8000-000000000001',id,1,1 from auth.users
where id::text between '60000000-0000-4000-8000-000000000001' and '60000000-0000-4000-8000-000000000005';
insert into public.elected_councils(id,community_id,source_cycle_id,target_seats,took_office_at,nominal_term_ends_at)
values('60300000-0000-4000-8000-000000000001','60100000-0000-4000-8000-000000000001',
 '60200000-0000-4000-8000-000000000001',5,now(),now()+interval '12 months');
insert into public.elected_council_mandates(council_id,community_id,member_id,source_cycle_id,took_office_at,nominal_term_ends_at)
select '60300000-0000-4000-8000-000000000001','60100000-0000-4000-8000-000000000001',candidate_id,
 cycle_id,now(),now()+interval '12 months' from public.election_winners where cycle_id='60200000-0000-4000-8000-000000000001';

select is(public.active_elected_mandate_count('60100000-0000-4000-8000-000000000001'),5,'five mandates start active');
select is(public.council_vacant_seat_count('60100000-0000-4000-8000-000000000001'),0,'full council has no vacancy');
select is(public.council_operational_status('60100000-0000-4000-8000-000000000001')::text,'operational','5/5 is operational');

set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',true);
select ok(public.has_elected_council_authority('60100000-0000-4000-8000-000000000001'),'active councillor has council authority');
select ok(to_regprocedure('public.resign_elected_council_mandate(uuid,uuid)') is null,
 'no API exists for resigning a target mandate');
select lives_ok($$select public.resign_elected_council_mandate('60100000-0000-4000-8000-000000000001')$$,'councillor resigns self');
select ok(not public.has_elected_council_authority('60100000-0000-4000-8000-000000000001'),'resignation immediately removes authority');
set local role postgres;
select is((select ended_reason::text from public.elected_council_mandates where member_id='60000000-0000-4000-8000-000000000001'),'resignation','historical mandate records resignation');
select is((select count(*) from public.elected_council_mandates where member_id='60000000-0000-4000-8000-000000000001'),1::bigint,'historical mandate remains stored');
select is((select count(*) from public.council_continuity_history where event='resignation'),1::bigint,'resignation audited once');
select is(public.council_vacant_seat_count('60100000-0000-4000-8000-000000000001'),1,'vacancy is derived');
select is(public.council_operational_status('60100000-0000-4000-8000-000000000001')::text,'operational','4/5 remains operational');
update public.elected_council_mandates set ended_at=now(),ended_reason='resignation' where member_id='60000000-0000-4000-8000-000000000002';
select is(public.council_operational_status('60100000-0000-4000-8000-000000000001')::text,'operational','3/5 remains operational');
update public.elected_council_mandates set ended_at=now(),ended_reason='resignation' where member_id='60000000-0000-4000-8000-000000000003';
select is(public.council_operational_status('60100000-0000-4000-8000-000000000001')::text,'under_strength','2/5 is under strength');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',true);
select ok(public.has_temporary_caretaker_authority('60100000-0000-4000-8000-000000000001'),'remaining councillor has caretaker authority');
select ok(not public.has_elected_council_authority('60100000-0000-4000-8000-000000000001'),'remaining councillor lacks ordinary council authority');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000007',true);
select ok(not public.is_active_community_admin('60100000-0000-4000-8000-000000000001'),'historical owner does not revive');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000006',true);
select ok(not public.is_active_community_admin('60100000-0000-4000-8000-000000000001'),'former appointed admin does not revive');
select lives_ok($$select public.open_council_reconstitution_cycle('60100000-0000-4000-8000-000000000001')$$,'active member opens reconstitution');
set local role postgres;
select is((select target_seats from public.election_cycles where purpose='reconstitution'),3::smallint,'cycle fills exactly three vacancies');
select is((select details->>'seats_available' from public.council_continuity_history where event='reconstitution_opened'),'3','opening is audited with vacancy count');
select set_config('test.reconstitution_cycle',(select id::text from public.election_cycles where purpose='reconstitution'),true);
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',true);
select throws_ok($$select public.stand_for_election(current_setting('test.reconstitution_cycle')::uuid)$$,
 '55000','An active councillor cannot stand for another seat','active councillor cannot seek a second seat');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.stand_for_election(current_setting('test.reconstitution_cycle')::uuid)$$,
 'previously resigned councillor may stand again');
select throws_ok($$select * from public.election_ballots$$,'42501','permission denied for table election_ballots','ballots remain private');
select throws_ok($$select public.install_reconstitution_winners('60100000-0000-4000-8000-000000000001',
 current_setting('test.reconstitution_cycle')::uuid)$$,'42501','permission denied for function install_reconstitution_winners',
 'browser cannot install mandates');

select * from finish();
rollback;
