begin;

select plan(27);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password)
values
  ('50000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@example.test', ''),
  ('50000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'member@example.test', ''),
  ('50000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'pending@example.test', ''),
  ('50000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'outsider@example.test', ''),
  ('50000000-0000-4000-8000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'other-owner@example.test', '');

set local role authenticated;
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000001', true);
select public.create_community('Riverside items');
create temporary table item_test_context as
select id as community_id, join_code, null::uuid as item_id, null::text as photo_path
from public.communities;

select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000002', true);
select public.request_to_join_community((select join_code from item_test_context));
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000001', true);
select public.approve_membership((select community_id from item_test_context), '50000000-0000-4000-8000-000000000002');

select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000003', true);
select public.request_to_join_community((select join_code from item_test_context));

select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000005', true);
select public.create_community('Hilltop items');
alter table item_test_context add column other_community_id uuid;
update item_test_context set other_community_id = (
  select id from public.communities where name = 'Hilltop items'
);

select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000001', true);
select lives_ok(
  format(
    'select public.create_item(%L, %L, %L, %L, true, null, %L)',
    (select community_id from item_test_context), 'Cordless screwdriver',
    'small_diy', 'Compact low-power screwdriver', 'jpg'
  ),
  'an active member can create an eligible item'
);
update item_test_context set
  item_id = (select id from public.items),
  photo_path = (select photo_path from public.items);
select is((select owner_id from public.items), '50000000-0000-4000-8000-000000000001'::uuid, 'the database assigns the authenticated owner');

select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  format('select public.create_item(%L, %L, %L, %L, true, null, %L)', (select community_id from item_test_context), 'No user item', 'household', 'Not allowed', 'png'),
  '42501', 'Authentication required', 'unauthenticated item creation is refused'
);

select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000004', true);
select throws_ok(
  format('select public.create_item(%L, %L, %L, %L, true, null, %L)', (select community_id from item_test_context), 'Outsider item', 'household', 'Not allowed', 'png'),
  '42501', 'Active community membership required', 'a non-member cannot create an item'
);
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000003', true);
select throws_ok(
  format('select public.create_item(%L, %L, %L, %L, true, null, %L)', (select community_id from item_test_context), 'Pending item', 'household', 'Not allowed', 'png'),
  '42501', 'Active community membership required', 'a pending member cannot create an item'
);

select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000001', true);
select throws_ok(
  format('insert into public.items (community_id, owner_id, name, category, description, photo_path, is_free) values (%L, %L, %L, %L, %L, %L, true)', (select community_id from item_test_context), '50000000-0000-4000-8000-000000000002', 'Forged', 'household', 'Forged owner', gen_random_uuid()::text || '/photo.jpg'),
  '42501', 'permission denied for table items', 'clients cannot directly forge an owner id'
);
select is((select count(*) from public.items), 1::bigint, 'the owner can read the item');
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.items), 1::bigint, 'an active same-community member can read the item');
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000003', true);
select is((select count(*) from public.items), 0::bigint, 'a pending member cannot read the item');
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000004', true);
select is((select count(*) from public.items), 0::bigint, 'a non-member cannot read the item');
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000005', true);
select is((select count(*) from public.items), 0::bigint, 'an active member of another real community cannot read the item');

select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000001', true);
select lives_ok($$update public.items set description = 'Updated description'$$, 'the owner can edit their item');
select lives_ok($$update public.items set archived = true$$, 'the owner can archive their item');
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000002', true);
select is((with changed as (update public.items set archived = false returning 1) select count(*) from changed), 0::bigint, 'another same-community member cannot modify or unarchive it');
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000005', true);
select is((with changed as (update public.items set description = 'Cross community' returning 1) select count(*) from changed), 0::bigint, 'a member of another community cannot modify it');

select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000001', true);
select throws_ok($$update public.items set owner_id = '50000000-0000-4000-8000-000000000002'$$, '42501', 'Item owner cannot be changed', 'the owner cannot transfer ownership');
select throws_ok(format('update public.items set community_id = %L', (select other_community_id from item_test_context)), '42501', 'Item community cannot be changed', 'the owner cannot move an item to another community');
select throws_ok(format('select public.create_item(%L, %L, %L::public.item_category, %L, true, null, %L)', (select community_id from item_test_context), 'Chainsaw', 'chainsaw', 'High risk', 'jpg'), '22P02', 'invalid input value for enum item_category: "chainsaw"', 'a dangerous category is rejected by the database');
select throws_ok(format('select public.create_item(%L, %L, %L, %L, true, 500, %L)', (select community_id from item_test_context), 'Bad free price', 'household', 'Invalid pricing', 'jpg'), '23514', null, 'a free item cannot have a daily price');
select throws_ok(format('select public.create_item(%L, %L, %L, %L, false, null, %L)', (select community_id from item_test_context), 'Missing price', 'household', 'Invalid pricing', 'jpg'), '23514', null, 'a paid item requires an integer daily price');

select lives_ok(format('insert into storage.objects (bucket_id, name, metadata) values (%L, %L, %L)', 'item-photos', (select photo_path from item_test_context), '{"mimetype":"image/jpeg"}'), 'the item owner can upload its declared photo');
select lives_ok(format('update storage.objects set metadata = %L where name = %L', '{"mimetype":"image/jpeg","updated":true}', (select photo_path from item_test_context)), 'the item owner can replace photo metadata');
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000002', true);
select is((select count(*) from storage.objects where bucket_id = 'item-photos'), 1::bigint, 'an active same-community member can read the photo');
select is((with changed as (update storage.objects set metadata = '{"mimetype":"image/png"}' where name = (select photo_path from item_test_context) returning 1) select count(*) from changed), 0::bigint, 'a non-owner cannot replace the photo');
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000003', true);
select is((select count(*) from storage.objects where bucket_id = 'item-photos'), 0::bigint, 'a pending member cannot read the photo');
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000004', true);
select is((select count(*) from storage.objects where bucket_id = 'item-photos'), 0::bigint, 'a non-member cannot read the photo');
select set_config('request.jwt.claim.sub', '50000000-0000-4000-8000-000000000005', true);
select is((select count(*) from storage.objects where bucket_id = 'item-photos'), 0::bigint, 'a member of another community cannot read the guessed photo path');

select * from finish();
rollback;
