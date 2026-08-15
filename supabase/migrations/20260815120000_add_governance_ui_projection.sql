-- Issue #57: privacy-safe, member-scoped read model for the governance UI.
-- Candidates and office holders are community-public roles, identified by the only established
-- product identity available today (auth email). Ballot choices and audit rows are never projected.
create function public.get_community_governance_ui(target_community_id uuid)
returns table(
  community_id uuid,
  governance_state public.community_governance_state,
  is_owner boolean,
  owner_label text,
  current_membership_role public.membership_role,
  appointed_admins jsonb,
  council_target smallint,
  may_commit_founding_transfer boolean,
  commit_blocker text,
  cycle_id uuid,
  cycle_status public.election_cycle_status,
  candidates jsonb,
  current_user_is_candidate boolean,
  round_id uuid,
  round_number smallint,
  round_status public.election_round_status,
  seats_available smallint,
  current_user_may_vote boolean,
  current_user_ballot_recorded boolean,
  active_mandates integer,
  elected_members jsonb,
  vacant_seats integer,
  operational_status public.council_operational_status,
  current_user_has_mandate boolean,
  may_resign boolean,
  council_took_office_at timestamptz,
  council_term_ends_at timestamptz,
  latest_election_status public.election_cycle_status,
  latest_round_status public.election_round_status,
  latest_ballot_count integer,
  latest_electorate_count integer,
  latest_quorum_threshold integer
)
language sql stable security definer set search_path = '' as $$
  with member_community as (
    select c.id as community_key, c.governance_state as community_governance_state,
      c.owner_id as community_owner_id, c.council_target_size as configured_council_target,
      c.active_election_cycle_id as authoritative_cycle_id, m.role as viewer_membership_role
    from public.communities c
    join public.memberships m on m.community_id=c.id and m.user_id=auth.uid() and m.status='active'
    where auth.uid() is not null and c.id=target_community_id
  ), selected_cycle as (
    select mc.community_key, cycle_row.id as selected_cycle_id,
      cycle_row.status as selected_cycle_status
    from member_community mc
    left join lateral (
      select x.id, x.status, x.created_at
      from public.election_cycles x
      where x.community_id=mc.community_key and (
        (mc.community_governance_state<>'democratic' and x.id=mc.authoritative_cycle_id)
        or (mc.community_governance_state='democratic' and x.purpose='reconstitution')
      )
      order by case when x.status in ('candidacy','voting') then 0 else 1 end,
        x.created_at desc, x.id desc limit 1
    ) cycle_row on true
  ), selected_round as (
    select sc.community_key, round_row.id as selected_round_id,
      round_row.round_number as selected_round_number,
      round_row.status as selected_round_status,
      round_row.seats_available as selected_seats_available
    from selected_cycle sc
    left join lateral (
      select x.id, x.round_number, x.status, x.seats_available
      from public.election_rounds x where x.cycle_id=sc.selected_cycle_id
      order by x.round_number desc limit 1
    ) round_row on true
  ), latest_election as (
    select mc.community_key, election_row.status as latest_cycle_status,
      election_row.round_status as latest_election_round_status,
      election_row.ballot_count as latest_election_ballots,
      election_row.electorate_count as latest_election_electorate,
      election_row.quorum_threshold as latest_election_quorum
    from member_community mc
    left join lateral (
      select cycle.status, round_summary.status as round_status,
        coalesce(round_summary.ballot_count,
          (select count(*)::integer from public.election_ballots b where b.round_id=round_summary.id)) as ballot_count,
        round_summary.electorate_count, round_summary.quorum_threshold, cycle.completed_at, cycle.created_at
      from public.election_cycles cycle
      left join lateral (
        select r.id, r.status, r.ballot_count, r.electorate_count, r.quorum_threshold
        from public.election_rounds r where r.cycle_id=cycle.id
        order by r.round_number desc limit 1
      ) round_summary on true
      where cycle.community_id=mc.community_key and cycle.status in ('completed','failed')
      order by cycle.completed_at desc nulls last, cycle.created_at desc, cycle.id desc limit 1
    ) election_row on true
  )
  select
    mc.community_key,
    mc.community_governance_state,
    mc.community_owner_id=auth.uid(),
    owner_user.email::text,
    mc.viewer_membership_role,
    coalesce((select jsonb_agg(jsonb_build_object('id', a.user_id, 'label', admin_user.email::text)
      order by admin_user.email::text, a.user_id)
      from public.memberships a join auth.users admin_user on admin_user.id=a.user_id
      where a.community_id=mc.community_key and a.status='active' and a.role='admin'), '[]'::jsonb),
    coalesce(ec.target_seats, mc.configured_council_target),
    mc.community_governance_state='democratic_preparation'
      and mc.community_owner_id=auth.uid() and sc.selected_cycle_status='candidacy'
      and (select count(*) from public.election_candidacies c join public.memberships m
        on m.community_id=c.community_id and m.user_id=c.candidate_id and m.status='active'
        where c.cycle_id=sc.selected_cycle_id)>=3
      and (select count(*) from public.memberships m where m.community_id=mc.community_key and m.status='active')>=5,
    case when mc.community_governance_state<>'democratic_preparation' or mc.community_owner_id<>auth.uid()
      then null
      when (select count(*) from public.election_candidacies c join public.memberships m
        on m.community_id=c.community_id and m.user_id=c.candidate_id and m.status='active'
        where c.cycle_id=sc.selected_cycle_id)<3 then 'candidate_minimum'
      when (select count(*) from public.memberships m where m.community_id=mc.community_key and m.status='active')<5
        then 'electorate_minimum'
      else null end,
    sc.selected_cycle_id,
    sc.selected_cycle_status,
    case when sc.selected_cycle_status='candidacy' then coalesce((select jsonb_agg(
      jsonb_build_object('id', candidacy.candidate_id, 'label', candidate_user.email::text)
      order by candidate_user.email::text, candidacy.candidate_id)
      from public.election_candidacies candidacy join auth.users candidate_user on candidate_user.id=candidacy.candidate_id
      where candidacy.cycle_id=sc.selected_cycle_id), '[]'::jsonb)
    else coalesce((select jsonb_agg(jsonb_build_object('id', candidate.candidate_id, 'label', candidate_user.email::text)
      order by candidate_user.email::text, candidate.candidate_id)
      from public.election_round_candidates candidate join auth.users candidate_user on candidate_user.id=candidate.candidate_id
      where candidate.round_id=sr.selected_round_id), '[]'::jsonb) end,
    exists(select 1 from public.election_candidacies c where c.cycle_id=sc.selected_cycle_id and c.candidate_id=auth.uid()),
    sr.selected_round_id, sr.selected_round_number, sr.selected_round_status, sr.selected_seats_available,
    sr.selected_round_status='voting' and exists(select 1 from public.election_electorate e
      where e.cycle_id=sc.selected_cycle_id and e.voter_id=auth.uid()),
    exists(select 1 from public.election_ballots b where b.round_id=sr.selected_round_id and b.voter_id=auth.uid()),
    case when ec.id is null then null else public.active_elected_mandate_count(mc.community_key) end,
    coalesce((select jsonb_agg(jsonb_build_object('id', mandate.member_id, 'label', member_user.email::text)
      order by member_user.email::text, mandate.member_id)
      from public.elected_council_mandates mandate join auth.users member_user on member_user.id=mandate.member_id
      where mandate.community_id=mc.community_key and mandate.ended_at is null), '[]'::jsonb),
    case when ec.id is null then null else public.council_vacant_seat_count(mc.community_key) end,
    case when ec.id is null then null else public.get_council_operational_status(mc.community_key) end,
    exists(select 1 from public.elected_council_mandates mandate
      where mandate.community_id=mc.community_key and mandate.member_id=auth.uid() and mandate.ended_at is null),
    mc.community_governance_state='democratic' and exists(select 1 from public.elected_council_mandates mandate
      where mandate.community_id=mc.community_key and mandate.member_id=auth.uid() and mandate.ended_at is null),
    ec.took_office_at, ec.nominal_term_ends_at,
    le.latest_cycle_status, le.latest_election_round_status, le.latest_election_ballots,
    le.latest_election_electorate, le.latest_election_quorum
  from member_community mc
  join auth.users owner_user on owner_user.id=mc.community_owner_id
  left join selected_cycle sc on sc.community_key=mc.community_key
  left join selected_round sr on sr.community_key=mc.community_key
  left join public.elected_councils ec on ec.community_id=mc.community_key
  left join latest_election le on le.community_key=mc.community_key;
$$;

revoke all on function public.get_community_governance_ui(uuid) from public;
grant execute on function public.get_community_governance_ui(uuid) to authenticated;
