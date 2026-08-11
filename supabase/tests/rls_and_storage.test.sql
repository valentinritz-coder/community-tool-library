begin;

select plan(10);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);

select lives_ok(
  $$insert into public.rls_validation_notes (id, owner_id, body)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111111', 'owner note')$$,
  'an authenticated owner can insert their row'
);

select is(
  (select count(*) from public.rls_validation_notes),
  1::bigint,
  'the owner can read their row'
);

select throws_ok(
  $$insert into public.rls_validation_notes (id, owner_id, body)
    values ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '22222222-2222-4222-8222-222222222222', 'not owned')$$,
  '42501',
  'new row violates row-level security policy for table "rls_validation_notes"',
  'an authenticated user cannot insert a row for another owner'
);

select lives_ok(
  $$insert into storage.objects (bucket_id, name, metadata)
    values ('item-photos', '11111111-1111-4111-8111-111111111111/item-proof.jpg', '{"mimetype":"image/jpeg"}')$$,
  'an authenticated owner can upload within their path'
);

select is(
  (select count(*) from storage.objects where bucket_id = 'item-photos'),
  1::bigint,
  'the owner can read their storage object'
);

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);

select is(
  (select count(*) from public.rls_validation_notes),
  0::bigint,
  'another authenticated user cannot read the owner row'
);

select is(
  (select count(*) from storage.objects where bucket_id = 'item-photos'),
  0::bigint,
  'another authenticated user cannot read the owner object'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name, metadata)
    values ('item-photos', '11111111-1111-4111-8111-111111111111/cross-user.jpg', '{"mimetype":"image/jpeg"}')$$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'another authenticated user cannot upload within the owner path'
);

select lives_ok(
  $$insert into public.rls_validation_notes (id, owner_id, body)
    values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '22222222-2222-4222-8222-222222222222', 'second owner note')$$,
  'the second authenticated user can insert their own row'
);

select lives_ok(
  $$insert into storage.objects (bucket_id, name, metadata)
    values ('item-photos', '22222222-2222-4222-8222-222222222222/item-proof.png', '{"mimetype":"image/png"}')$$,
  'the second authenticated user can upload within their own path'
);

select * from finish();
rollback;
