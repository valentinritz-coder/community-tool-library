begin;
select plan(23);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password) values
('90000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','admin@example.test',''),
('90000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','member@example.test',''),
('90000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','pending@example.test',''),
('90000000-0000-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','outsider@example.test',''),
('90000000-0000-4000-8000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','other-admin@example.test','');
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
select public.create_community('Moderation community');
select public.create_community('Other community');
create temporary table ctx as select
 max(id) filter(where name='Moderation community') c1,
 max(join_code) filter(where name='Moderation community') j1,
 max(id) filter(where name='Other community') c2,
 max(join_code) filter(where name='Other community') j2,
 null::uuid item1, null::uuid item2, null::uuid booking1, null::uuid report1 from public.communities;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select public.request_to_join_community((select j1 from ctx));
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
select public.request_to_join_community((select j1 from ctx));
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000005',true);
select public.request_to_join_community((select j2 from ctx));
set local role postgres;
update public.memberships set status='active' where user_id in ('90000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000005');
update public.memberships set role='admin' where user_id='90000000-0000-4000-8000-000000000005';
insert into public.items(id,community_id,owner_id,name,category,description,photo_path,is_free,photo_uploaded)
values ('91000000-0000-4000-8000-000000000001',(select c1 from ctx),'90000000-0000-4000-8000-000000000001','Drill','small_diy','A drill','91000000-0000-4000-8000-000000000001/photo.jpg',true,true);
insert into public.items(id,community_id,owner_id,name,category,description,photo_path,is_free,photo_uploaded)
select '91000000-0000-4000-8000-000000000002',c2,'90000000-0000-4000-8000-000000000005','Saw','small_diy','A saw','91000000-0000-4000-8000-000000000002/photo.jpg',true,true from ctx;
update ctx set item1=(select id from public.items where name='Drill'), item2=(select id from public.items where name='Saw');
insert into public.bookings(item_id,borrower_id,start_date,end_date,status) select item1,'90000000-0000-4000-8000-000000000002',current_date,current_date,'accepted' from ctx;
update ctx set booking1=(select id from public.bookings);
set local role authenticated;
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select lives_ok(format('select public.submit_item_report(%L,''inappropriate'',%L)',(select item1 from ctx),'  short note  '),'active member reports visible item');
update ctx set report1=(select id from public.moderation_reports);
select is((select note from public.moderation_reports),'short note','note is trimmed server-side');
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',null)',(select item1 from ctx)),'23505','An open report already exists for this target','open item duplicate is rejected');
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',null)',(select item2 from ctx)),'42501','Item is not visible to this reporter','cross-community item is rejected');
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',%L)',(select item1 from ctx),'   '),'22023','Note cannot be blank','blank note is rejected');
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',%L)',(select item1 from ctx),repeat('x',501)),'22023','Note must be 500 characters or fewer','long note is rejected');
select lives_ok(format('select public.submit_counterparty_report(%L,''other'',null)',(select booking1 from ctx)),'booking participant reports counterparty');
select throws_ok('select public.submit_counterparty_report(gen_random_uuid(),''other'',null)','42501','Only a booking participant can report its counterparty','arbitrary booking is rejected');
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000003',true);
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',null)',(select item1 from ctx)),'42501','Item is not visible to this reporter','pending member cannot report');
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000004',true);
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',null)',(select item1 from ctx)),'42501','Item is not visible to this reporter','non-member cannot report');
select set_config('request.jwt.claim.sub','',true);
select throws_ok(format('select public.submit_item_report(%L,''unsafe'',null)',(select item1 from ctx)),'42501','Authentication required','anonymous caller cannot report');
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select throws_ok(format('select * from public.list_moderation_reports(%L)',(select c1 from ctx)),'42501','Active same-community admin required','normal member cannot list reports');
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000005',true);
select throws_ok(format('select * from public.list_moderation_reports(%L)',(select c1 from ctx)),'42501','Active same-community admin required','cross-community admin cannot list reports');
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.list_moderation_reports((select c1 from ctx))),2::bigint,'same-community admin sees reports');
select is((select count(*) from information_schema.columns where table_schema='public' and table_name='moderation_reports' and column_name in ('reporter_id','target_user_id')),2::bigint,'sensitive identifiers exist only in inaccessible raw table');
select lives_ok(format('select public.handle_moderation_report(%L)',(select report1 from ctx)),'admin handles report');
select throws_ok(format('select public.handle_moderation_report(%L)',(select report1 from ctx)),'22023','Report is already handled','repeated handling is clearly rejected');
select lives_ok(format('select public.submit_item_report(%L,''unsafe'',null)',(select item1 from ctx)),'new report is allowed after handling');
select lives_ok(format('select public.hide_reported_item(%L)',(select id from public.moderation_reports where item_id=(select item1 from ctx) and status='open')),'admin hides reported item');
select is((select moderation_hidden from public.items where id=(select item1 from ctx)),true,'item has independent moderation state');
select is((select count(*) from public.browse_community_inventory((select c1 from ctx))),0::bigint,'hidden item disappears from browse');
select set_config('request.jwt.claim.sub','90000000-0000-4000-8000-000000000002',true);
select is(public.can_read_inventory_photo((select photo_path from public.items where id=(select item1 from ctx))),false,'hidden item photo is unreadable');
select throws_ok(format('select public.hide_reported_item(%L)',(select report1 from ctx)),'42501','Active same-community admin and item report required','member cannot hide item');
rollback;
