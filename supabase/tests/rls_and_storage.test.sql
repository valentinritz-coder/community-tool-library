begin;

select plan(5);

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

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);

select is(
  (select count(*) from public.rls_validation_notes),
  0::bigint,
  'another authenticated user cannot read the owner row'
);

select lives_ok(
  $$insert into public.rls_validation_notes (id, owner_id, body)
    values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '22222222-2222-4222-8222-222222222222', 'second owner note')$$,
  'the second authenticated user can insert their own row'
);

select * from finish();
rollback;
