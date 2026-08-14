begin;
select no_plan();

insert into auth.users (id, instance_id, aud, role, email, encrypted_password) values
 ('d0000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','cancel-owner@example.test',''),
 ('d0000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','cancel-borrower@example.test',''),
 ('d0000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','cancel-member@example.test',''),
 ('d0000000-0000-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','cancel-admin@example.test',''),
 ('d0000000-0000-4000-8000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','cancel-borrower-two@example.test','');
insert into public.communities(id,name,owner_id) values
 ('d1000000-0000-4000-8000-000000000001','Cancellation community','d0000000-0000-4000-8000-000000000004');
insert into public.memberships(community_id,user_id,role,status) values
 ('d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000001','member','active'),
 ('d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','member','active'),
 ('d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000003','member','active'),
 ('d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000004','admin','active'),
 ('d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000005','member','active');
insert into public.items(id,community_id,owner_id,name,category,description,photo_path,is_free,photo_uploaded)
values ('d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000001','Cancellation drill','small_diy','Synthetic cancellation fixture','d2000000-0000-4000-8000-000000000001/photo.jpg',true,true);
insert into public.availabilities(item_id,start_date,end_date)
values ('d2000000-0000-4000-8000-000000000001','2027-01-01','2027-03-31');
insert into public.bookings(id,item_id,borrower_id,start_date,end_date,status) values
 ('d3000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-01-01','2027-01-01','requested'),
 ('d3000000-0000-4000-8000-000000000002','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-01-02','2027-01-02','accepted'),
 ('d3000000-0000-4000-8000-000000000003','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-01-03','2027-01-03','accepted'),
 ('d3000000-0000-4000-8000-000000000004','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-01-04','2027-01-04','requested'),
 ('d3000000-0000-4000-8000-000000000005','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-01-05','2027-01-05','requested'),
 ('d3000000-0000-4000-8000-000000000006','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-01-06','2027-01-06','checked_out'),
 ('d3000000-0000-4000-8000-000000000007','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-01-07','2027-01-07','returned'),
 ('d3000000-0000-4000-8000-000000000008','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-01-08','2027-01-08','refused'),
 ('d3000000-0000-4000-8000-000000000009','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-01-09','2027-01-09','cancelled');

set local role authenticated;
select set_config('request.jwt.claim.sub','d0000000-0000-4000-8000-000000000002',true);
select is((select status::text from public.cancel_booking('d3000000-0000-4000-8000-000000000001')),'cancelled','borrower cancels own requested booking');
select is((select count(*) from public.list_booking_requests() where id='d3000000-0000-4000-8000-000000000001' and status='cancelled'),1::bigint,'cancelled requested booking remains stored in participant history');
select is((select status::text from public.cancel_booking('d3000000-0000-4000-8000-000000000002')),'cancelled','borrower cancels own accepted booking');

select set_config('request.jwt.claim.sub','d0000000-0000-4000-8000-000000000001',true);
select is((select status::text from public.cancel_booking('d3000000-0000-4000-8000-000000000003')),'cancelled','item owner cancels an accepted booking');
select throws_ok($$select * from public.cancel_booking('d3000000-0000-4000-8000-000000000004')$$,'42501','Only the borrower can cancel a requested booking','owner must use Refuse for a requested booking');
select set_config('request.jwt.claim.sub','d0000000-0000-4000-8000-000000000003',true);
select throws_ok($$select * from public.cancel_booking('d3000000-0000-4000-8000-000000000005')$$,'42501','Only the borrower can cancel a requested booking','unrelated member cannot cancel');
select set_config('request.jwt.claim.sub','d0000000-0000-4000-8000-000000000004',true);
select throws_ok($$select * from public.cancel_booking('d3000000-0000-4000-8000-000000000005')$$,'42501','Only the borrower can cancel a requested booking','admin authority alone cannot cancel');
select set_config('request.jwt.claim.sub','d0000000-0000-4000-8000-000000000002',true);
select throws_ok($$select * from public.cancel_booking('d3000000-0000-4000-8000-000000000006')$$,'55000','Booking cannot be cancelled after handover','checked-out booking cannot be cancelled');
select throws_ok($$select * from public.cancel_booking('d3000000-0000-4000-8000-000000000007')$$,'55000','Booking cannot be cancelled in its current state','returned booking cannot be cancelled');
select throws_ok($$select * from public.cancel_booking('d3000000-0000-4000-8000-000000000008')$$,'55000','Booking cannot be cancelled in its current state','refused booking cannot be cancelled');
select throws_ok($$select * from public.cancel_booking('d3000000-0000-4000-8000-000000000001')$$,'55000','Booking cannot be cancelled in its current state','cancelled booking cannot be cancelled again');
reset role;
set local role anon;
select throws_ok($$select * from public.cancel_booking('d3000000-0000-4000-8000-000000000005')$$,'42501',null,'unauthenticated caller cannot cancel');
reset role;
select throws_ok($$update public.bookings set status='accepted' where id='d3000000-0000-4000-8000-000000000001'$$,'55000','Invalid booking status transition','cancelled status is terminal');

-- Cancellation releases exclusivity through status alone and retains the row.
insert into public.bookings(id,item_id,borrower_id,start_date,end_date,status) values
 ('d3000000-0000-4000-8000-000000000010','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-02-01','2027-02-03','accepted'),
 ('d3000000-0000-4000-8000-000000000011','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000005','2027-02-02','2027-02-04','requested');
set local role authenticated;
select set_config('request.jwt.claim.sub','d0000000-0000-4000-8000-000000000001',true);
select throws_ok($$select * from public.decide_booking('d3000000-0000-4000-8000-000000000011','accepted')$$,'23P01',null,'overlapping request cannot be accepted while accepted booking holds exclusivity');
select is((select status::text from public.cancel_booking('d3000000-0000-4000-8000-000000000010')),'cancelled','owner cancels the accepted exclusive booking');
select is((select status::text from public.decide_booking('d3000000-0000-4000-8000-000000000011','accepted')),'accepted','overlapping request can be accepted after authoritative cancellation');
reset role;
select throws_ok($$insert into public.bookings(id,item_id,borrower_id,start_date,end_date,status) values ('d3000000-0000-4000-8000-000000000012','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-02-03','2027-02-03','checked_out')$$,'23P01',null,'accepted and checked-out overlap protection remains intact');

-- Contact disappears on cancellation; retained evidence keeps its existing boundary.
insert into public.bookings(id,item_id,borrower_id,start_date,end_date,status)
values ('d3000000-0000-4000-8000-000000000013','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-03-01','2027-03-01','accepted');
set local role authenticated;
select set_config('request.jwt.claim.sub','d0000000-0000-4000-8000-000000000002',true);
select is((select count(*) from public.list_accepted_booking_contacts() where booking_id='d3000000-0000-4000-8000-000000000013'),1::bigint,'accepted participant contact is initially visible');
create temporary table cancellation_report as select * from public.create_condition_report('d3000000-0000-4000-8000-000000000013','before','jpg');
select is((select phase::text from cancellation_report),'before','accepted booking can have before-condition evidence');
select lives_ok($$select * from public.cancel_booking('d3000000-0000-4000-8000-000000000013')$$,'accepted booking with evidence can be cancelled');
select is((select count(*) from public.list_accepted_booking_contacts() where booking_id='d3000000-0000-4000-8000-000000000013'),0::bigint,'cancelled booking exposes no accepted-only contact');
select is((select count(*) from public.condition_reports where booking_id='d3000000-0000-4000-8000-000000000013'),1::bigint,'cancellation retains existing condition evidence for participant');
select throws_ok($$select * from public.create_condition_report('d3000000-0000-4000-8000-000000000013','before','jpg')$$,'55000','Condition evidence is not allowed in this booking state','cancelled booking cannot receive new evidence');
select set_config('request.jwt.claim.sub','d0000000-0000-4000-8000-000000000003',true);
select is((select count(*) from public.condition_reports where booking_id='d3000000-0000-4000-8000-000000000013'),0::bigint,'cancellation does not broaden evidence visibility');

-- Real participants retain cleanup authority after membership changes.
reset role;
insert into public.bookings(id,item_id,borrower_id,start_date,end_date,status)
values ('d3000000-0000-4000-8000-000000000014','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','2027-03-02','2027-03-02','accepted');
update public.memberships set status='pending' where user_id='d0000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub','d0000000-0000-4000-8000-000000000002',true);
select is((select status::text from public.cancel_booking('d3000000-0000-4000-8000-000000000014')),'cancelled','actual borrower can cancel after membership becomes inactive');

select * from finish();
rollback;
