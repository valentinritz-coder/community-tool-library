begin;
select plan(62);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
select ('60000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 '00000000-0000-0000-0000-000000000000','authenticated','authenticated','continuity-'||n||'@example.test',''
from generate_series(1,7)n;
insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
values('60000000-0000-4000-8000-000000000008','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','continuity-outsider@example.test','');

set local role postgres;
insert into public.communities(id,name,owner_id,governance_state,council_target_size)
values('60100000-0000-4000-8000-000000000001','Continuity fixture','60000000-0000-4000-8000-000000000007','democratic',5);
insert into public.memberships(community_id,user_id,role,status)
select '60100000-0000-4000-8000-000000000001',id,
 case when id='60000000-0000-4000-8000-000000000006' then 'admin'::public.membership_role else 'member' end,'active'
from auth.users where id=any(array[
 '60000000-0000-4000-8000-000000000001'::uuid,'60000000-0000-4000-8000-000000000002',
 '60000000-0000-4000-8000-000000000003','60000000-0000-4000-8000-000000000004',
 '60000000-0000-4000-8000-000000000005','60000000-0000-4000-8000-000000000006',
 '60000000-0000-4000-8000-000000000007']);
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
select is(public.get_council_operational_status('60100000-0000-4000-8000-000000000001')::text,'operational','5/5 is operational');

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
select is(public.get_council_operational_status('60100000-0000-4000-8000-000000000001')::text,'operational','4/5 remains operational');
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000002',true);
select set_config('test.one_vacancy_cycle',public.open_council_reconstitution_cycle(
 '60100000-0000-4000-8000-000000000001')::text,true);
select ok(current_setting('test.one_vacancy_cycle')::uuid is not null,'active member opens a one-vacancy cycle');
set local role postgres;
select is((select target_seats from public.election_cycles where id=current_setting('test.one_vacancy_cycle')::uuid),
 1::smallint,'four active mandates produce one election seat');
update public.election_cycles set status='failed',completed_at=now()
where id=current_setting('test.one_vacancy_cycle')::uuid;
update public.elected_council_mandates set ended_at=now(),ended_reason='resignation' where member_id='60000000-0000-4000-8000-000000000002';
select is(public.get_council_operational_status('60100000-0000-4000-8000-000000000001')::text,'operational','3/5 remains operational');
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',true);
select set_config('test.two_vacancy_cycle',public.open_council_reconstitution_cycle(
 '60100000-0000-4000-8000-000000000001')::text,true);
select ok(current_setting('test.two_vacancy_cycle')::uuid is not null,'active member opens a two-vacancy cycle');
set local role postgres;
select is((select target_seats from public.election_cycles where id=current_setting('test.two_vacancy_cycle')::uuid),
 2::smallint,'three active mandates produce two election seats');
update public.election_cycles set status='failed',completed_at=now()
where id=current_setting('test.two_vacancy_cycle')::uuid;
update public.elected_council_mandates set ended_at=now(),ended_reason='resignation' where member_id='60000000-0000-4000-8000-000000000003';
select is(public.get_council_operational_status('60100000-0000-4000-8000-000000000001')::text,'under_strength','2/5 is under strength');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',true);
select ok(public.has_temporary_caretaker_authority('60100000-0000-4000-8000-000000000001'),'remaining councillor has caretaker authority');
select ok(not public.has_elected_council_authority('60100000-0000-4000-8000-000000000001'),'remaining councillor lacks ordinary council authority');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000007',true);
select ok(not public.is_active_community_admin('60100000-0000-4000-8000-000000000001'),'historical owner does not revive');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000006',true);
select ok(not public.is_active_community_admin('60100000-0000-4000-8000-000000000001'),'former appointed admin does not revive');
select set_config('test.three_vacancy_cycle',public.open_council_reconstitution_cycle(
 '60100000-0000-4000-8000-000000000001')::text,true);
select throws_ok($$select public.open_council_reconstitution_cycle('60100000-0000-4000-8000-000000000001')$$,
 '55000','A community election cycle is already active','second sequential opener is rejected deterministically');
set local role postgres;
select is((select target_seats from public.election_cycles where id=current_setting('test.three_vacancy_cycle')::uuid),
 3::smallint,'cycle fills exactly three vacancies');
select is((select details->>'seats_available' from public.council_continuity_history
 where election_cycle_id=current_setting('test.three_vacancy_cycle')::uuid and event='reconstitution_opened'),
 '3','opening is audited with vacancy count');
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',true);
select is((select count(*) from public.get_council_continuity('60100000-0000-4000-8000-000000000001')),1::bigint,
 'active member can read continuity contract');
select is((select reconstitution_status::text from public.get_council_continuity('60100000-0000-4000-8000-000000000001')),
 'candidacy','continuity contract exposes current aggregate cycle status');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000008',true);
select is((select count(*) from public.get_council_continuity('60100000-0000-4000-8000-000000000001')),0::bigint,
 'non-member cannot read continuity contract');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',true);
select throws_ok($$select public.stand_for_election(current_setting('test.three_vacancy_cycle')::uuid)$$,
 '55000','An active councillor cannot stand for another seat','active councillor cannot seek a second seat');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000001',true);
select lives_ok($$select public.stand_for_election(current_setting('test.three_vacancy_cycle')::uuid)$$,
 'previously resigned councillor may stand again');
select throws_ok($$select * from public.election_ballots$$,'42501','permission denied for table election_ballots','ballots remain private');
select throws_ok($$select public.install_reconstitution_winners('60100000-0000-4000-8000-000000000001',
 current_setting('test.three_vacancy_cycle')::uuid)$$,'42501','permission denied for function install_reconstitution_winners',
 'browser cannot install mandates');

-- One remaining councillor is a caretaker, not an ordinary administrator.
set local role postgres;
update public.election_cycles set status='failed',completed_at=now()
where id=current_setting('test.three_vacancy_cycle')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',true);
select is((select reconstitution_status::text from public.get_council_continuity('60100000-0000-4000-8000-000000000001')),
 'failed','continuity contract deterministically falls back to a terminal cycle');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000004',true);
select lives_ok($$select public.resign_elected_council_mandate('60100000-0000-4000-8000-000000000001')$$,
 'fourth councillor resigns self');
set local role postgres;
select is(public.active_elected_mandate_count('60100000-0000-4000-8000-000000000001'),1,'one mandate remains active');
select is(public.get_council_operational_status('60100000-0000-4000-8000-000000000001')::text,'under_strength','one active is under strength');
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000005',true);
select ok(public.has_temporary_caretaker_authority('60100000-0000-4000-8000-000000000001'),'last councillor is caretaker');
select ok(public.has_community_continuity_authority('60100000-0000-4000-8000-000000000001'),'last councillor has narrow continuity authority');
select ok(not public.has_elected_council_authority('60100000-0000-4000-8000-000000000001'),'last councillor lacks ordinary council authority');
select ok(not public.is_active_community_admin('60100000-0000-4000-8000-000000000001'),'last councillor is not ordinary admin');
select lives_ok($$select * from public.list_moderation_reports('60100000-0000-4000-8000-000000000001')$$,
 'caretaker may perform classified moderation continuity');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',true);
select set_config('test.one_active_cycle',public.open_council_reconstitution_cycle(
 '60100000-0000-4000-8000-000000000001')::text,true);
select ok(current_setting('test.one_active_cycle')::uuid is not null,
 'ordinary active member can open reconstitution with one councillor');
set local role postgres;
select is((select target_seats from public.election_cycles where id=current_setting('test.one_active_cycle')::uuid),
 4::smallint,'one-active reconstitution targets four vacancies');

-- Zero councillors remains democratic and member-driven, with no historical authority revival.
set local role postgres;
update public.election_cycles set status='failed',completed_at=now()
where id=current_setting('test.one_active_cycle')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000005',true);
select lives_ok($$select public.resign_elected_council_mandate('60100000-0000-4000-8000-000000000001')$$,
 'last councillor can resign');
set local role postgres;
select is(public.active_elected_mandate_count('60100000-0000-4000-8000-000000000001'),0,'zero mandates remain active');
select is(public.get_council_operational_status('60100000-0000-4000-8000-000000000001')::text,'vacant','zero active is vacant');
select is(public.council_vacant_seat_count('60100000-0000-4000-8000-000000000001'),5,'all target seats are vacant');
select is((select governance_state::text from public.get_council_continuity('60100000-0000-4000-8000-000000000001')),
 'democratic','governance remains democratic');
set local role authenticated;
select ok(not public.has_temporary_caretaker_authority('60100000-0000-4000-8000-000000000001'),'no elected caretaker remains');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000007',true);
select ok(not public.is_active_community_admin('60100000-0000-4000-8000-000000000001'),'owner is not restored at zero');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000006',true);
select ok(not public.is_active_community_admin('60100000-0000-4000-8000-000000000001'),'former admin is not restored at zero');
select set_config('request.jwt.claim.sub','60000000-0000-4000-8000-000000000003',true);
select set_config('test.zero_active_cycle',public.open_council_reconstitution_cycle(
 '60100000-0000-4000-8000-000000000001')::text,true);
select ok(current_setting('test.zero_active_cycle')::uuid is not null,
 'ordinary active member opens reconstitution at zero');
set local role postgres;
select is((select target_seats from public.election_cycles where id=current_setting('test.zero_active_cycle')::uuid),
 5::smallint,'zero-active reconstitution targets all five vacancies');

-- Purpose-dependent constraints preserve the founding 3/5 invariant for privileged writes.
set local role postgres;
select lives_ok($$insert into public.election_cycles(community_id,target_seats,purpose,status,completed_at)
 values('60100000-0000-4000-8000-000000000001',3,'founding','failed',now())$$,'founding target three is allowed');
select lives_ok($$insert into public.election_cycles(community_id,target_seats,purpose,status,completed_at)
 values('60100000-0000-4000-8000-000000000001',5,'founding','failed',now())$$,'founding target five is allowed');
select throws_ok($$insert into public.election_cycles(community_id,target_seats,purpose,status,completed_at)
 values('60100000-0000-4000-8000-000000000001',1,'founding','failed',now())$$,'23514',null,'founding target one is rejected');
select throws_ok($$insert into public.election_cycles(community_id,target_seats,purpose,status,completed_at)
 values('60100000-0000-4000-8000-000000000001',2,'founding','failed',now())$$,'23514',null,'founding target two is rejected');
select throws_ok($$insert into public.election_cycles(community_id,target_seats,purpose,status,completed_at)
 values('60100000-0000-4000-8000-000000000001',4,'founding','failed',now())$$,'23514',null,'founding target four is rejected');
select ok(not has_function_privilege('authenticated','public.close_election_round(uuid)','EXECUTE'),
 'browser cannot close election rounds');
select ok(not has_function_privilege('authenticated','public.finalize_election_round(uuid)','EXECUTE'),
 'browser cannot finalize election rounds');
select ok(not has_function_privilege('authenticated','public.install_reconstitution_winners(uuid,uuid)','EXECUTE'),
 'browser cannot install reconstitution winners');
select ok(not has_function_privilege('authenticated','public.finalize_reconstitution_round(uuid)','EXECUTE'),
 'browser cannot invoke reconstitution finalization');

select * from finish();
rollback;
