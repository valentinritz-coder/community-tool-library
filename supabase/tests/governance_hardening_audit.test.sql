begin;
select plan(15);

-- Issue #58: audit the complete browser-facing governance boundary rather than trusting UI
-- capability flags. Internal election storage remains inaccessible even to authenticated actors.
select ok(not has_table_privilege('anon','public.communities','update'),
  'anonymous callers cannot mutate community governance fields');
select ok(not has_table_privilege('authenticated','public.communities','update'),
  'authenticated callers cannot directly mutate community governance fields');
select ok(not has_table_privilege('authenticated','public.election_cycles','select'),
  'browser callers cannot read raw election cycles');
select ok(not has_table_privilege('authenticated','public.election_electorate','select'),
  'browser callers cannot enumerate electorate snapshots');
select ok(not has_table_privilege('authenticated','public.election_ballots','select'),
  'browser callers cannot enumerate voter participation rows');
select ok(not has_table_privilege('authenticated','public.election_ballot_approvals','select'),
  'browser callers cannot read the ballot approval ledger');
select ok(not has_table_privilege('authenticated','public.election_winners','insert'),
  'browser callers cannot manufacture election winners');
select ok(not has_table_privilege('authenticated','public.elected_council_mandates','insert'),
  'browser callers cannot manufacture elected mandates');
select ok(not has_table_privilege('authenticated','public.elected_council_mandates','update'),
  'browser callers cannot end or rewrite mandates directly');
select ok(not has_table_privilege('authenticated','public.council_continuity_history','select'),
  'browser callers cannot read raw resignation audit actors/details');

select ok(not has_function_privilege('authenticated','public.freeze_election_cycle(uuid)','execute')
  and not has_function_privilege('authenticated','public.close_election_round(uuid)','execute')
  and not has_function_privilege('authenticated','public.finalize_election_round(uuid)','execute'),
  'browser roles cannot invoke internal freeze/close/finalization primitives');
select ok(not has_function_privilege('authenticated','public.install_elected_council(uuid,uuid)','execute')
  and not has_function_privilege('authenticated','public.install_reconstitution_winners(uuid,uuid)','execute'),
  'browser roles cannot directly invoke council installation primitives');
select ok(not has_function_privilege('authenticated','public.finalize_foundation_round(uuid)','execute')
  and not has_function_privilege('authenticated','public.finalize_reconstitution_round(uuid)','execute')
  and has_function_privilege('service_role','public.finalize_foundation_round(uuid)','execute')
  and has_function_privilege('service_role','public.finalize_reconstitution_round(uuid)','execute'),
  'only the service boundary receives election orchestration privileges');

select ok(not exists(
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prosecdef
    and (p.proname like '%governance%' or p.proname like '%election%'
      or p.proname like '%council%' or p.proname in ('set_appointed_administrator','set_community_display_name'))
    and not coalesce(p.proconfig,'{}'::text[]) @> array['search_path=']
), 'every governance SECURITY DEFINER function fixes an empty search_path');

select ok(position('approved_candidate' in
  pg_get_function_result('public.get_community_governance_ui(uuid)'::regprocedure))=0
  and position('email' in
  pg_get_functiondef('public.get_community_governance_ui(uuid)'::regprocedure))=0,
  'the member read contract exposes neither approval arrays nor authentication email');

select * from finish();
rollback;
