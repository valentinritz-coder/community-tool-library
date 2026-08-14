-- LOCAL DEMO ONLY. Loaded explicitly by `npm run demo:local`; never by `db reset`.
-- All identifiers and identities are synthetic. Dates are relative to the load date.
begin;

do $$
begin
  if exists (select 1 from public.communities where id = 'd1000000-0000-4000-8000-000000000001') then
    raise exception 'Demo dataset already exists; run npm run supabase:reset before reloading it';
  end if;
end $$;

insert into auth.users
  (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at,
   raw_app_meta_data, raw_user_meta_data, confirmation_token, recovery_token, email_change,
   email_change_token_new)
values
  ('d0000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-admin@example.test',crypt('demo-local-only', gen_salt('bf')),now(),now(),now(),'{"provider":"email","providers":["email"]}','{}','','','',''),
  ('d0000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-owner@example.test',crypt('demo-local-only', gen_salt('bf')),now(),now(),now(),'{"provider":"email","providers":["email"]}','{}','','','',''),
  ('d0000000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-borrower@example.test',crypt('demo-local-only', gen_salt('bf')),now(),now(),now(),'{"provider":"email","providers":["email"]}','{}','','','',''),
  ('d0000000-0000-4000-8000-000000000004','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-member@example.test',crypt('demo-local-only', gen_salt('bf')),now(),now(),now(),'{"provider":"email","providers":["email"]}','{}','','','',''),
  ('d0000000-0000-4000-8000-000000000005','00000000-0000-0000-0000-000000000000','authenticated','authenticated','demo-pending@example.test',crypt('demo-local-only', gen_salt('bf')),now(),now(),now(),'{"provider":"email","providers":["email"]}','{}','','','','');

insert into auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select id, id::text, id, jsonb_build_object('sub', id::text, 'email', email), 'email', now(), now(), now()
from auth.users where id::text like 'd0000000-0000-4000-8000-00000000000%';

insert into public.communities (id, name, join_code, owner_id, governance_state, created_at) values
 ('d1000000-0000-4000-8000-000000000001','Example Test Tool Circle','d1000000-0000-4000-8000-000000000099','d0000000-0000-4000-8000-000000000001','managed',now());
insert into public.memberships (community_id,user_id,role,status,created_at) values
 ('d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000001','admin','active',now()),
 ('d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','member','active',now()),
 ('d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000003','member','active',now()),
 ('d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000004','member','active',now());

insert into public.items (id,community_id,owner_id,name,category,description,photo_path,is_free,price_per_day_cents,photo_uploaded,created_at) values
 ('d2000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','Compact drill','small_diy','Synthetic low-risk drill listing.','d2000000-0000-4000-8000-000000000001/photo.jpg',true,null,true,now()-interval '4 days'),
 ('d2000000-0000-4000-8000-000000000002','d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000002','Folding step stool','household','Synthetic household listing.','d2000000-0000-4000-8000-000000000002/photo.png',false,300,true,now()-interval '3 days'),
 ('d2000000-0000-4000-8000-000000000003','d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000004','Hand trowel set','garden','Synthetic garden hand-tool listing.','d2000000-0000-4000-8000-000000000003/photo.webp',true,null,true,now()-interval '2 days'),
 ('d2000000-0000-4000-8000-000000000004','d1000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000004','Picnic set','leisure','Synthetic leisure listing for moderation review.','d2000000-0000-4000-8000-000000000004/photo.jpg',true,null,true,now()-interval '1 day');
insert into public.availabilities (id,item_id,start_date,end_date) values
 ('d3000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001',current_date+1,current_date+45),
 ('d3000000-0000-4000-8000-000000000002','d2000000-0000-4000-8000-000000000002',current_date+2,current_date+45),
 ('d3000000-0000-4000-8000-000000000003','d2000000-0000-4000-8000-000000000003',current_date+1,current_date+45),
 ('d3000000-0000-4000-8000-000000000004','d2000000-0000-4000-8000-000000000004',current_date+1,current_date+45);

insert into public.bookings (id,item_id,borrower_id,start_date,end_date,status,created_at) values
 ('d4000000-0000-4000-8000-000000000001','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000003',current_date+3,current_date+3,'requested',now()),
 ('d4000000-0000-4000-8000-000000000002','d2000000-0000-4000-8000-000000000002','d0000000-0000-4000-8000-000000000003',current_date+5,current_date+6,'accepted',now()-interval '1 day'),
 ('d4000000-0000-4000-8000-000000000003','d2000000-0000-4000-8000-000000000003','d0000000-0000-4000-8000-000000000002',current_date+8,current_date+8,'refused',now()-interval '2 days'),
 ('d4000000-0000-4000-8000-000000000004','d2000000-0000-4000-8000-000000000001','d0000000-0000-4000-8000-000000000004',current_date-4,current_date-4,'returned',now()-interval '5 days'),
 ('d4000000-0000-4000-8000-000000000005','d2000000-0000-4000-8000-000000000003','d0000000-0000-4000-8000-000000000003',current_date-1,current_date+1,'checked_out',now()-interval '2 days');
insert into public.condition_reports (id,booking_id,phase,photo_path,mime_type,author_id,created_at) values
 ('d5000000-0000-4000-8000-000000000001','d4000000-0000-4000-8000-000000000004','before','d4000000-0000-4000-8000-000000000004/before/d5000000-0000-4000-8000-000000000001.jpg','image/jpeg','d0000000-0000-4000-8000-000000000004',now()-interval '2 days'),
 ('d5000000-0000-4000-8000-000000000002','d4000000-0000-4000-8000-000000000004','after','d4000000-0000-4000-8000-000000000004/after/d5000000-0000-4000-8000-000000000002.jpg','image/jpeg','d0000000-0000-4000-8000-000000000002',now()-interval '1 day');
insert into public.moderation_reports (id,community_id,target_type,item_id,reporter_id,reason,note,created_at) values
 ('d6000000-0000-4000-8000-000000000001','d1000000-0000-4000-8000-000000000001','item','d2000000-0000-4000-8000-000000000004','d0000000-0000-4000-8000-000000000003','misleading','Synthetic report for the demo moderation queue.',now());

commit;
