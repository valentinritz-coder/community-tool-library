begin;
select plan(42);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password) values
('90000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','admin@example.test',''),
('90000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@example.test',''),
('90000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','pending-member@example.test',''),
('90000000-0000-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','outsider@example.test',''),
('90000000-0000-4000-8000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','other-admin@example.test',''),
('90000000-0000-4000-8000-000000000006','00000000-0000-0000-0000-000000000000','authenticated','authenticated','pending-admin@example.test','');

set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
select public.create_community('Moderation community');
select public.create_community('Other community');
create temporary table ctx as select
 (select id from public.communities where name = 'Moderation community') c1,
 (select join_code from public.communities where name = 'Moderation community') j1,
 (select id from public.communities where name = 'Other community') c2,
 (select join_code from public.communities where name = 'Other community') j2,
 null::uuid item1, null::uuid item2, null::uuid booking1, null::uuid item_report,
 null::uuid counterparty_report;

select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select public.request_to_join_community((select j1 from ctx));
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
select public.request_to_join_community((select j1 from ctx));
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000006',true);
select public.request_to_join_community((select j1 from ctx));
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000005',true);
select public.request_to_join_community((select j2 from ctx));

set local role postgres;
update public.memberships set status='active' where user_id in
 ('90000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000005');
update public.memberships set role='admin' where user_id in
 ('90000000-0000-4000-8000-000000000005','90000000-0000-4000-8000-000000000006');
insert into public.items(id,community_id,owner_id,name,category,description,photo_path,is_free,photo_uploaded) values
('91000000-0000-4000-8000-000000000001',(select c1 from ctx),'90000000-0000-4000-8000-000000000001','Drill','small_diy','A drill','91000000-0000-4000-8000-000000000001/photo.jpg',true,true),
('91000000-0000-4000-8000-000000000002',(select c2 from ctx),'90000000-0000-4000-8000-000000000005','Saw','small_diy','A saw','91000000-0000-4000-8000-000000000002/photo.jpg',true,true);
update ctx set item1='91000000-0000-4000-8000-000000000001', item2='91000000-0000-4000-8000-000000000002';
insert into public.bookings(item_id,borrower_id,start_date,end_date,status)
select item1,'90000000-0000-4000-8000-000000000002',current_date,current_date,'accepted' from ctx;
update ctx set booking1=(select id from public.bookings);

set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select lives_ok(format('select public.submit_item_report(%L,''inappropriate'',%L)',item1,'  short note  '),'active member reports visible item') from ctx;
set local role postgres;
update ctx set item_report=(select id from public.moderation_reports where target_type='item');
select is((select note from public.moderation_reports where id=(select item_report from ctx)),'short note','note is trimmed server-side');
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',null)',item1),'23505','An open report already exists for this target','open item duplicate is rejected') from ctx;
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',null)',item2),'42501','Item is not visible to this reporter','cross-community item is rejected') from ctx;
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',%L)',item1,'   '),'22023','Note cannot be blank','blank note is rejected') from ctx;
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',%L)',item1,repeat('x',501)),'22023','Note must be 500 characters or fewer','long note is rejected') from ctx;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',null)',item1),'42501','Item is not visible to this reporter','pending member cannot report an item') from ctx;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000004',true);
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',null)',item1),'42501','Item is not visible to this reporter','non-member cannot report an item') from ctx;
select set_config('request.jwt.claim.sub','',true);
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',null)',item1),'42501','Authentication required','anonymous caller cannot report an item') from ctx;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);

select ok(public.submit_counterparty_report((select booking1 from ctx),'other',null) is not null,'active participant receives the created counterparty report UUID');
set local role postgres;
update ctx set counterparty_report=(select id from public.moderation_reports where target_type='counterparty');
select is((select count(*) from public.moderation_reports where id=(select counterparty_report from ctx)),1::bigint,'valid counterparty submission creates exactly one report');
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select throws_ok(format('select public.submit_counterparty_report(%L,''other'',null)',booking1),'23505','An open report already exists for this target','open counterparty duplicate is rejected') from ctx;
select throws_ok('select public.submit_counterparty_report(gen_random_uuid(),''other'',null)','42501','Only a booking participant can report its counterparty','arbitrary booking is rejected');
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000004',true);
select throws_ok(format('select public.submit_counterparty_report(%L,''other'',null)',booking1),'42501','Only a booking participant can report its counterparty','non-member cannot report a counterparty') from ctx;
select set_config('request.jwt.claim.sub','',true);
select throws_ok(format('select public.submit_counterparty_report(%L,''other'',null)',booking1),'42501','Authentication required','anonymous caller cannot report a counterparty') from ctx;
set local role postgres;
update public.memberships set status='pending' where user_id='90000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select throws_ok(format('select public.submit_counterparty_report(%L,''unsafe'',null)',booking1),'42501','Only a booking participant can report its counterparty','inactive participant cannot create a counterparty report') from ctx;
set local role postgres;
update public.memberships set status='active' where user_id='90000000-0000-4000-8000-000000000002';

set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.list_moderation_reports((select c1 from ctx))),2::bigint,'active same-community admin sees reports');
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select throws_ok(format('select * from public.list_moderation_reports(%L)',c1),'42501','Community continuity authority required','normal member cannot list reports') from ctx;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000005',true);
select throws_ok(format('select * from public.list_moderation_reports(%L)',c1),'42501','Community continuity authority required','cross-community admin cannot list reports') from ctx;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000006',true);
select throws_ok(format('select * from public.list_moderation_reports(%L)',c1),'42501','Community continuity authority required','pending admin cannot list reports') from ctx;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
select throws_ok(format('select * from public.list_moderation_reports(%L)',c1),'42501','Community continuity authority required','pending member cannot list reports') from ctx;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000004',true);
select throws_ok(format('select * from public.list_moderation_reports(%L)',c1),'42501','Community continuity authority required','non-member cannot list reports') from ctx;
select set_config('request.jwt.claim.sub','',true);
select throws_ok(format('select * from public.list_moderation_reports(%L)',c1),'42501','Community continuity authority required','anonymous caller cannot list reports') from ctx;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select throws_like('select * from public.moderation_reports','%permission denied%','raw moderation reports are not client-readable');
select ok(pg_get_function_result('public.list_moderation_reports(uuid)'::regprocedure) not like '%reporter_id%','admin projection omits reporter_id');
select ok(pg_get_function_result('public.list_moderation_reports(uuid)'::regprocedure) not like '%target_user_id%','admin projection omits target_user_id');
select ok(pg_get_function_result('public.list_moderation_reports(uuid)'::regprocedure) not like '%handled_by%','admin projection omits handled_by');

select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000005',true);
select throws_ok(format('select public.hide_reported_item(%L)',item_report),'42501','Community continuity authority and open item report required','cross-community admin cannot hide an item') from ctx;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000006',true);
select throws_ok(format('select public.hide_reported_item(%L)',item_report),'42501','Community continuity authority and open item report required','pending admin cannot hide an item') from ctx;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select throws_ok(format('select public.hide_reported_item(%L)',item_report),'42501','Community continuity authority and open item report required','normal member cannot hide an item') from ctx;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
select lives_ok(format('select public.hide_reported_item(%L)',item_report),'same-community active admin hides an item') from ctx;
set local role postgres;
select is((select status::text||':'||action_taken from public.moderation_reports where id=(select item_report from ctx)),'handled:item hidden','hide atomically records handled and item hidden');
select is((select handled_by from public.moderation_reports where id=(select item_report from ctx)),'90000000-0000-4000-8000-000000000001'::uuid,'hide records the acting admin');
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
select throws_ok(format('select public.hide_reported_item(%L)',item_report),'22023','Report is already handled','handled report cannot be reused to hide') from ctx;
select throws_ok(format('select public.handle_moderation_report(%L)',item_report),'22023','Report is already handled','handle cannot race after hide') from ctx;
select is((select moderation_hidden from public.items where id=(select item1 from ctx)),true,'item has independent moderation state');
select is((select count(*) from public.browse_community_inventory((select c1 from ctx))),0::bigint,'hidden item disappears from browse');
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select is(public.can_read_inventory_photo((select photo_path from public.items where id=(select item1 from ctx))),false,'hidden item photo is inaccessible at the Storage policy boundary');
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
select throws_like(format('update public.items set moderation_hidden=false where id=%L',(select item1 from ctx)),'%permission denied%','owner cannot clear moderation_hidden through client privileges');

select lives_ok(format('select public.handle_moderation_report(%L)',counterparty_report),'admin handles counterparty report') from ctx;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select ok(public.submit_counterparty_report((select booking1 from ctx),'unsafe',null) is not null,'counterparty can be reported again after handling');
select throws_ok(format('select public.handle_moderation_report(%L)',(select counterparty_report from ctx)),'42501','Community continuity authority required','member cannot handle report');

rollback;
