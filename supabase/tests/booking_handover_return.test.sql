begin;
select no_plan();

insert into auth.users (id, instance_id, aud, role, email, encrypted_password) values
 ('b0000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','lifecycle-owner@example.test',''),
 ('b0000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','lifecycle-borrower@example.test',''),
 ('b0000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','lifecycle-member@example.test',''),
 ('b0000000-0000-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','lifecycle-admin@example.test',''),
 ('b0000000-0000-4000-8000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','lifecycle-pending@example.test',''),
 ('b0000000-0000-4000-8000-000000000006','00000000-0000-0000-0000-000000000000','authenticated','authenticated','lifecycle-outsider@example.test',''),
 ('b0000000-0000-4000-8000-000000000007','00000000-0000-0000-0000-000000000000','authenticated','authenticated','lifecycle-cross-admin@example.test','');
insert into public.communities(id,name) values
 ('b1000000-0000-4000-8000-000000000001','Lifecycle community'),
 ('b1000000-0000-4000-8000-000000000002','Other lifecycle community');
insert into public.memberships values
 ('b1000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001','member','active',now()),
 ('b1000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000002','member','active',now()),
 ('b1000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000003','member','active',now()),
 ('b1000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000004','admin','active',now()),
 ('b1000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000005','member','pending',now()),
 ('b1000000-0000-4000-8000-000000000002','b0000000-0000-4000-8000-000000000007','admin','active',now());
insert into public.items(id,community_id,owner_id,name,category,description,photo_path,is_free,photo_uploaded)
values ('b2000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001','Lifecycle drill','small_diy','Synthetic lifecycle fixture','b2000000-0000-4000-8000-000000000001/photo.jpg',true,true);
insert into public.bookings(id,item_id,borrower_id,start_date,end_date,status) values
 ('b3000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000002','2026-11-01','2026-11-01','accepted'),
 ('b3000000-0000-4000-8000-000000000002','b2000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000002','2026-11-02','2026-11-02','accepted'),
 ('b3000000-0000-4000-8000-000000000003','b2000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000002','2026-11-03','2026-11-03','requested'),
 ('b3000000-0000-4000-8000-000000000004','b2000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000002','2026-11-04','2026-11-04','refused');

set local role authenticated;
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000002',true);
select is((select status::text from public.record_handover('b3000000-0000-4000-8000-000000000001')),'checked_out','borrower records handover');
select throws_ok($$select * from public.record_handover('b3000000-0000-4000-8000-000000000001')$$,'55000','Booking is not in the required state','repeated handover is rejected');
select is((select status::text from public.record_return('b3000000-0000-4000-8000-000000000001')),'returned','borrower records return');
select throws_ok($$select * from public.record_return('b3000000-0000-4000-8000-000000000001')$$,'55000','Booking is not in the required state','repeated return is rejected');
select throws_ok($$select * from public.record_handover('b3000000-0000-4000-8000-000000000003')$$,'55000','Booking is not in the required state','requested to checked out is rejected');
select throws_ok($$select * from public.record_return('b3000000-0000-4000-8000-000000000003')$$,'55000','Booking is not in the required state','requested to returned is rejected');
select throws_ok($$select * from public.record_return('b3000000-0000-4000-8000-000000000002')$$,'55000','Booking is not in the required state','accepted to returned is rejected');
select throws_ok($$select * from public.record_handover('b3000000-0000-4000-8000-000000000004')$$,'55000','Booking is not in the required state','refused to checked out is rejected');
select throws_ok($$select * from public.record_return('b3000000-0000-4000-8000-000000000004')$$,'55000','Booking is not in the required state','refused to returned is rejected');
select throws_ok($$update public.bookings set status='checked_out' where id='b3000000-0000-4000-8000-000000000002'$$,'42501',null,'client cannot update status directly');

select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000003',true);
select throws_ok($$select * from public.record_handover('b3000000-0000-4000-8000-000000000002')$$,'42501','Only transaction participants can record this lifecycle action','unrelated active member cannot transition');
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000004',true);
select throws_ok($$select * from public.record_handover('b3000000-0000-4000-8000-000000000002')$$,'42501','Only transaction participants can record this lifecycle action','non-participant admin cannot transition');
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000005',true);
select throws_ok($$select * from public.record_handover('b3000000-0000-4000-8000-000000000002')$$,'42501','Only transaction participants can record this lifecycle action','pending member cannot transition');
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000006',true);
select throws_ok($$select * from public.record_handover('b3000000-0000-4000-8000-000000000002')$$,'42501','Only transaction participants can record this lifecycle action','non-member cannot transition');
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000007',true);
select throws_ok($$select * from public.record_handover('b3000000-0000-4000-8000-000000000002')$$,'42501','Only transaction participants can record this lifecycle action','cross-community admin cannot transition');

select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000001',true);
select is((select status::text from public.record_handover('b3000000-0000-4000-8000-000000000002')),'checked_out','owner records handover');
reset role;
update public.memberships set status='pending' where community_id='b1000000-0000-4000-8000-000000000001' and user_id='b0000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000002',true);
select is((select status::text from public.record_return('b3000000-0000-4000-8000-000000000002')),'returned','participant can finish checked-out exchange after membership becomes inactive');
select is((select count(*) from public.list_booking_requests() where id='b3000000-0000-4000-8000-000000000002' and status='returned'),1::bigint,'returned history remains visible to borrower');
select is((select count(*) from public.list_accepted_booking_contacts()),0::bigint,'returned history does not retain counterparty email after membership changes');
reset role;

-- Evidence has immutable metadata; only the RPC can create it in the matching phase.
insert into public.bookings(id,item_id,borrower_id,start_date,end_date,status) values
 ('b3000000-0000-4000-8000-000000000010','b2000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000002','2026-11-10','2026-11-10','accepted');
set local role authenticated;
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000002',true);
create temporary table before_report as select * from public.create_condition_report('b3000000-0000-4000-8000-000000000010','before','jpg');
select is((select phase::text from before_report),'before','before evidence is reserved while accepted');
select throws_ok($$select * from public.create_condition_report('b3000000-0000-4000-8000-000000000010','after','jpg')$$,'55000','Condition evidence is not allowed in this booking state','after evidence is rejected while accepted');
create temporary table mismatched_report as select * from public.create_condition_report('b3000000-0000-4000-8000-000000000010','before','jpg');
select throws_ok(
  format('insert into storage.objects(bucket_id,name,metadata) values (%L,%L,%L)','condition-photos',(select photo_path from mismatched_report),'{"mimetype":"image/png"}'),
  '42501', null, 'storage rejects MIME metadata that does not match the reserved extension'
);
select throws_ok(
  $$insert into storage.objects(bucket_id,name,metadata) values ('condition-photos','b3000000-0000-4000-8000-000000000099/before/ffffffff-ffff-4fff-8fff-ffffffffffff.jpg','{"mimetype":"image/jpeg"}')$$,
  '42501', null, 'storage rejects a forged booking and report path'
);
select lives_ok(format('insert into storage.objects(bucket_id,name,metadata) values (%L,%L,%L)','condition-photos',(select photo_path from before_report),'{"mimetype":"image/jpeg"}'),'participant uploads exact reserved before path');
select is((select count(*) from public.condition_reports),2::bigint,'borrower reads condition reports for the booking');
select throws_ok($$select author_id from public.condition_reports$$,'42501',null,'condition report projection does not expose raw author UUIDs');
select lives_ok($$select * from public.record_handover('b3000000-0000-4000-8000-000000000010')$$,'handover advances evidence phase');
select throws_ok($$select * from public.create_condition_report('b3000000-0000-4000-8000-000000000010','before','png')$$,'55000','Condition evidence is not allowed in this booking state','late before evidence is rejected');
create temporary table after_report as select * from public.create_condition_report('b3000000-0000-4000-8000-000000000010','after','png');
select is((select phase::text from after_report),'after','after evidence is reserved while checked out');
select lives_ok(format('insert into storage.objects(bucket_id,name,metadata) values (%L,%L,%L)','condition-photos',(select photo_path from after_report),'{"mimetype":"image/png"}'),'participant uploads exact reserved after path');
select lives_ok($$select * from public.record_return('b3000000-0000-4000-8000-000000000010')$$,'return makes transaction historical');
select throws_ok($$select * from public.create_condition_report('b3000000-0000-4000-8000-000000000010','after','png')$$,'55000','Condition evidence is not allowed in this booking state','late after evidence is rejected');
select throws_ok($$update public.condition_reports set phase='after'$$,'42501',null,'participants cannot rewrite evidence metadata');
select throws_ok($$delete from public.condition_reports$$,'42501',null,'participants cannot delete historical evidence');
select is((select count(*) from storage.objects where bucket_id='condition-photos'),2::bigint,'borrower reads both private photos');
create temporary table original_condition_object as
  select name, metadata from storage.objects
  where bucket_id='condition-photos' and name=(select photo_path from before_report);
select lives_ok(
  $$update storage.objects set metadata='{"mimetype":"image/webp"}' where bucket_id='condition-photos' and name=(select name from original_condition_object)$$,
  'an unauthorized Storage update may complete while RLS affects no rows'
);
select is(
  (select metadata from storage.objects where bucket_id='condition-photos' and name=(select name from original_condition_object)),
  (select metadata from original_condition_object),
  'participants cannot rewrite condition photo objects'
);
select lives_ok(
  $$delete from storage.objects where bucket_id='condition-photos' and name=(select name from original_condition_object)$$,
  'an unauthorized Storage delete may complete while RLS affects no rows'
);
select is(
  (select count(*) from storage.objects where bucket_id='condition-photos' and name=(select name from original_condition_object)),
  1::bigint,
  'participants cannot delete condition photo objects'
);

select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000001',true);
select is((select count(*) from public.condition_reports),3::bigint,'other booking participant reads all reports');
select is((select count(*) from storage.objects where bucket_id='condition-photos'),2::bigint,'owner reads both photos');
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000004',true);
select is((select count(*) from public.condition_reports),3::bigint,'active same-community admin can read evidence');
select is((select count(*) from storage.objects where bucket_id='condition-photos'),2::bigint,'active same-community admin can read photos');
select throws_ok($$select * from public.create_condition_report('b3000000-0000-4000-8000-000000000010','after','jpg')$$,'42501','Only transaction participants can add condition evidence','admin cannot upload evidence');
select throws_ok(
  format('insert into storage.objects(bucket_id,name,metadata) values (%L,%L,%L)','condition-photos',(select photo_path from mismatched_report),'{"mimetype":"image/jpeg"}'),
  '42501', null, 'same-community admin cannot upload a participant condition photo'
);
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000003',true);
select is((select count(*) from public.condition_reports),0::bigint,'unrelated member cannot read evidence');
select is((select count(*) from storage.objects where bucket_id='condition-photos'),0::bigint,'unrelated member cannot read photos');
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000007',true);
select is((select count(*) from public.condition_reports),0::bigint,'cross-community admin cannot read evidence');
select is((select count(*) from storage.objects where bucket_id='condition-photos'),0::bigint,'cross-community admin cannot read photos');
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000005',true);
select is((select count(*) from public.condition_reports),0::bigint,'pending unrelated member cannot read evidence');
select is((select count(*) from storage.objects where bucket_id='condition-photos'),0::bigint,'pending unrelated member cannot read photos');
select set_config('request.jwt.claim.sub','b0000000-0000-4000-8000-000000000006',true);
select is((select count(*) from public.condition_reports),0::bigint,'non-member cannot read evidence');
select is((select count(*) from public.list_booking_requests() where status='returned'),0::bigint,'unrelated user sees no returned history');
reset role;
set local role anon;
select throws_ok(
  $$select count(*) from public.condition_reports$$,
  '42501',
  'permission denied for table condition_reports',
  'anon has no condition report table privilege'
);
select is((select count(*) from storage.objects where bucket_id='condition-photos'),0::bigint,'anon cannot read condition photos');
select throws_ok(
  $$insert into storage.objects(bucket_id,name,metadata) values ('condition-photos','b3000000-0000-4000-8000-000000000010/before/ffffffff-ffff-4fff-8fff-ffffffffffff.jpg','{"mimetype":"image/jpeg"}')$$,
  '42501', null, 'anon cannot upload condition photos'
);
select throws_ok($$select * from public.record_handover('b3000000-0000-4000-8000-000000000010')$$,'42501',null,'anon cannot call lifecycle RPC');
select throws_ok($$select * from public.create_condition_report('b3000000-0000-4000-8000-000000000010','after','jpg')$$,'42501',null,'anon cannot create evidence');
reset role;

select is((select file_size_limit from storage.buckets where id='condition-photos'),5242880::bigint,'condition photo bucket enforces the 5 MB upload limit');
select is((select allowed_mime_types from storage.buckets where id='condition-photos'),array['image/jpeg','image/png','image/webp']::text[],'condition photo bucket allows only the three supported MIME types');

select throws_ok($$update public.bookings set status='checked_out' where id='b3000000-0000-4000-8000-000000000010'$$,'55000','Invalid booking status transition','returned cannot become checked out');
select throws_ok($$update public.bookings set status='accepted' where id='b3000000-0000-4000-8000-000000000010'$$,'55000','Invalid booking status transition','returned cannot become accepted');
select * from finish();
rollback;
