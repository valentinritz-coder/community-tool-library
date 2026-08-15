-- Issue #57: privacy-safe, member-scoped read model for the governance UI.
-- Candidate identifiers are returned only as opaque action keys; ballot choices and audit rows
-- are never projected.
create function public.get_community_governance_ui(target_community_id uuid)
returns table(
  community_id uuid,
  governance_state public.community_governance_state,
  is_owner boolean,
  current_membership_role public.membership_role,
  appointed_admin_count integer,
  council_target smallint,
  cycle_id uuid,
  cycle_status public.election_cycle_status,
  candidate_ids uuid[],
  current_user_is_candidate boolean,
  round_id uuid,
  round_number smallint,
  round_status public.election_round_status,
  seats_available smallint,
  current_user_may_vote boolean,
  current_user_ballot_recorded boolean,
  active_mandates integer,
  elected_member_ids uuid[],
  vacant_seats integer,
  operational_status public.council_operational_status,
  current_user_has_mandate boolean,
  may_resign boolean
)
language sql stable security definer set search_path = '' as $$
  with member_community as (
    select c.*, m.role as current_role
    from public.communities c
    join public.memberships m on m.community_id=c.id and m.user_id=auth.uid() and m.status='active'
    where c.id=target_community_id
  ), selected_cycle as (
    select mc.id as community_id, e.*
    from member_community mc
    left join lateral (
      select x.* from public.election_cycles x
      where x.community_id=mc.id and (
        (mc.governance_state<>'democratic' and x.id=mc.active_election_cycle_id)
        or (mc.governance_state='democratic' and x.purpose='reconstitution')
      )
      order by case when x.status in ('candidacy','voting') then 0 else 1 end, x.created_at desc, x.id desc
      limit 1
    ) e on true
  ), selected_round as (
    select sc.community_id, r.*
    from selected_cycle sc
    left join lateral (
      select x.* from public.election_rounds x where x.cycle_id=sc.id
      order by x.round_number desc limit 1
    ) r on true
  )
  select
    mc.id,
    mc.governance_state,
    mc.owner_id=auth.uid(),
    mc.current_role,
    (select count(*)::integer from public.memberships a where a.community_id=mc.id and a.status='active' and a.role='admin'),
    coalesce(ec.target_seats, mc.council_target_size),
    sc.id,
    sc.status,
    case
      when sc.status='candidacy' then coalesce((select array_agg(x.candidate_id order by x.candidate_id) from public.election_candidacies x where x.cycle_id=sc.id), '{}'::uuid[])
      else coalesce((select array_agg(x.candidate_id order by x.candidate_id) from public.election_round_candidates x where x.round_id=sr.id), '{}'::uuid[])
    end,
    exists(select 1 from public.election_candidacies x where x.cycle_id=sc.id and x.candidate_id=auth.uid()),
    sr.id,
    sr.round_number,
    sr.status,
    sr.seats_available,
    sr.status='voting' and exists(select 1 from public.election_electorate x where x.cycle_id=sc.id and x.voter_id=auth.uid()),
    exists(select 1 from public.election_ballots x where x.round_id=sr.id and x.voter_id=auth.uid()),
    case when ec.id is null then null else public.active_elected_mandate_count(mc.id) end,
    coalesce((select array_agg(x.member_id order by x.member_id) from public.elected_council_mandates x where x.community_id=mc.id and x.ended_at is null), '{}'::uuid[]),
    case when ec.id is null then null else public.council_vacant_seat_count(mc.id) end,
    case when ec.id is null then null else public.get_council_operational_status(mc.id) end,
    exists(select 1 from public.elected_council_mandates x where x.community_id=mc.id and x.member_id=auth.uid() and x.ended_at is null),
    mc.governance_state='democratic' and exists(select 1 from public.elected_council_mandates x where x.community_id=mc.id and x.member_id=auth.uid() and x.ended_at is null)
  from member_community mc
  left join selected_cycle sc on sc.community_id=mc.id
  left join selected_round sr on sr.community_id=mc.id
  left join public.elected_councils ec on ec.community_id=mc.id;
$$;

revoke all on function public.get_community_governance_ui(uuid) from public;
grant execute on function public.get_community_governance_ui(uuid) to authenticated;
