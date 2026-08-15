-- Issue #57: privacy-safe, member-scoped read model for the governance UI.
-- A deliberately small community-facing identity. It is optional so historical accounts remain
-- eligible; the read model supplies a stable opaque fallback without exposing auth credentials.
alter table public.memberships add column display_name text
  check (display_name is null or char_length(btrim(display_name)) between 2 and 80);

-- Continuity actors need the same membership queue visibility as the approve boundary they are
-- allowed to invoke. This does not grant visibility to ordinary members or historical roles.
drop policy "users can read their own or administered memberships" on public.memberships;
create policy "users can read their own or continuity-authorized memberships"
on public.memberships for select to authenticated
using (user_id=(select auth.uid()) or (select public.has_community_continuity_authority(community_id)));

-- Candidate and office-holder identities are public only inside their community. Ballot choices
-- and audit rows are never projected.
create function public.get_community_governance_ui(target_community_id uuid)
returns table(
  community_id uuid,
  governance_state public.community_governance_state,
  is_owner boolean,
  owner_label text,
  current_membership_role public.membership_role,
  current_user_label text,
  appointed_admins jsonb,
  may_manage_appointed_admins boolean,
  may_approve_memberships boolean,
  may_moderate_community boolean,
  council_target smallint,
  may_commit_founding_transfer boolean,
  commit_blocker text,
  cycle_id uuid,
  cycle_status public.election_cycle_status,
  cycle_seats_to_fill smallint,
  valid_candidate_count integer,
  may_launch_current_election boolean,
  launch_blocker text,
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
      c.active_election_cycle_id as authoritative_cycle_id, m.role as viewer_membership_role,
      coalesce(nullif(btrim(m.display_name),''),
        'Community member • '||upper(right(replace(m.user_id::text,'-',''),4))) as viewer_label
    from public.communities c
    join public.memberships m on m.community_id=c.id and m.user_id=auth.uid() and m.status='active'
    where auth.uid() is not null and c.id=target_community_id
  ), selected_cycle as (
    select mc.community_key, cycle_row.id as selected_cycle_id,
      cycle_row.status as selected_cycle_status,
      cycle_row.target_seats as selected_cycle_seats,
      cycle_row.purpose as selected_cycle_purpose
    from member_community mc
    left join lateral (
      select x.id, x.status, x.target_seats, x.purpose, x.created_at
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
    coalesce(nullif(btrim(owner_membership.display_name),''),
      'Community member • '||upper(right(replace(mc.community_owner_id::text,'-',''),4))),
    mc.viewer_membership_role,
    mc.viewer_label,
    coalesce((select jsonb_agg(jsonb_build_object('id', a.user_id, 'label',
      coalesce(nullif(btrim(a.display_name),''),'Community member • '||upper(right(replace(a.user_id::text,'-',''),4))))
      order by coalesce(a.display_name,a.user_id::text), a.user_id)
      from public.memberships a
      where a.community_id=mc.community_key and a.status='active' and a.role='admin'), '[]'::jsonb),
    mc.community_owner_id=auth.uid() and mc.community_governance_state in ('managed','democratic_preparation'),
    public.has_community_continuity_authority(mc.community_key),
    public.has_community_continuity_authority(mc.community_key),
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
    sc.selected_cycle_seats,
    (select count(*)::integer from public.election_candidacies candidacy
      join public.memberships candidate_membership on candidate_membership.community_id=candidacy.community_id
        and candidate_membership.user_id=candidacy.candidate_id and candidate_membership.status='active'
      where candidacy.cycle_id=sc.selected_cycle_id
        and (sc.selected_cycle_purpose='founding' or not exists(select 1 from public.elected_council_mandates mandate
          where mandate.community_id=mc.community_key and mandate.member_id=candidacy.candidate_id and mandate.ended_at is null))),
    sc.selected_cycle_status='candidacy'
      and ((sc.selected_cycle_purpose='founding' and mc.community_governance_state='democratic_transition')
        or (sc.selected_cycle_purpose='reconstitution' and mc.community_governance_state='democratic')) and
      (select count(*) from public.election_candidacies candidacy
       join public.memberships candidate_membership on candidate_membership.community_id=candidacy.community_id
        and candidate_membership.user_id=candidacy.candidate_id and candidate_membership.status='active'
       where candidacy.cycle_id=sc.selected_cycle_id
        and (sc.selected_cycle_purpose='founding' or not exists(select 1 from public.elected_council_mandates mandate
          where mandate.community_id=mc.community_key and mandate.member_id=candidacy.candidate_id and mandate.ended_at is null)))
      >= case when sc.selected_cycle_purpose='founding' then 3 else 1 end,
    case when sc.selected_cycle_status<>'candidacy'
      or not ((sc.selected_cycle_purpose='founding' and mc.community_governance_state='democratic_transition')
        or (sc.selected_cycle_purpose='reconstitution' and mc.community_governance_state='democratic')) then null
      when (select count(*) from public.election_candidacies candidacy
       join public.memberships candidate_membership on candidate_membership.community_id=candidacy.community_id
        and candidate_membership.user_id=candidacy.candidate_id and candidate_membership.status='active'
       where candidacy.cycle_id=sc.selected_cycle_id
        and (sc.selected_cycle_purpose='founding' or not exists(select 1 from public.elected_council_mandates mandate
          where mandate.community_id=mc.community_key and mandate.member_id=candidacy.candidate_id and mandate.ended_at is null)))
       < case when sc.selected_cycle_purpose='founding' then 3 else 1 end then 'candidate_minimum'
      else null end,
    case when sc.selected_cycle_status='candidacy' then coalesce((select jsonb_agg(
      jsonb_build_object('id', candidacy.candidate_id, 'label',coalesce(nullif(btrim(candidate_membership.display_name),''),
        'Community member • '||upper(right(replace(candidacy.candidate_id::text,'-',''),4))))
      order by coalesce(candidate_membership.display_name,candidacy.candidate_id::text), candidacy.candidate_id)
      from public.election_candidacies candidacy join public.memberships candidate_membership
        on candidate_membership.community_id=candidacy.community_id and candidate_membership.user_id=candidacy.candidate_id
          and candidate_membership.status='active'
      where candidacy.cycle_id=sc.selected_cycle_id and (sc.selected_cycle_purpose='founding' or not exists(
        select 1 from public.elected_council_mandates mandate where mandate.community_id=mc.community_key
          and mandate.member_id=candidacy.candidate_id and mandate.ended_at is null))), '[]'::jsonb)
    else coalesce((select jsonb_agg(jsonb_build_object('id', candidate.candidate_id, 'label',
      coalesce(nullif(btrim(candidate_membership.display_name),''),'Community member • '||upper(right(replace(candidate.candidate_id::text,'-',''),4))))
      order by coalesce(candidate_membership.display_name,candidate.candidate_id::text), candidate.candidate_id)
      from public.election_round_candidates candidate join public.memberships candidate_membership
        on candidate_membership.community_id=mc.community_key and candidate_membership.user_id=candidate.candidate_id
      where candidate.round_id=sr.selected_round_id), '[]'::jsonb) end,
    exists(select 1 from public.election_candidacies c where c.cycle_id=sc.selected_cycle_id and c.candidate_id=auth.uid()),
    sr.selected_round_id, sr.selected_round_number, sr.selected_round_status, sr.selected_seats_available,
    sr.selected_round_status='voting' and exists(select 1 from public.election_electorate e
      where e.cycle_id=sc.selected_cycle_id and e.voter_id=auth.uid()),
    exists(select 1 from public.election_ballots b where b.round_id=sr.selected_round_id and b.voter_id=auth.uid()),
    case when ec.id is null then null else public.active_elected_mandate_count(mc.community_key) end,
    coalesce((select jsonb_agg(jsonb_build_object('id', mandate.member_id, 'label',
      coalesce(nullif(btrim(member_membership.display_name),''),'Community member • '||upper(right(replace(mandate.member_id::text,'-',''),4))))
      order by coalesce(member_membership.display_name,mandate.member_id::text), mandate.member_id)
      from public.elected_council_mandates mandate join public.memberships member_membership
        on member_membership.community_id=mandate.community_id and member_membership.user_id=mandate.member_id
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
  left join public.memberships owner_membership on owner_membership.community_id=mc.community_key
    and owner_membership.user_id=mc.community_owner_id
  left join selected_cycle sc on sc.community_key=mc.community_key
  left join selected_round sr on sr.community_key=mc.community_key
  left join public.elected_councils ec on ec.community_id=mc.community_key
  left join latest_election le on le.community_key=mc.community_key;
$$;

revoke all on function public.get_community_governance_ui(uuid) from public;
grant execute on function public.get_community_governance_ui(uuid) to authenticated;

-- Narrow member-accessible boundary for advancing an already-authoritative candidacy cycle. The
-- internal freeze primitive remains unavailable to browser roles.
create function public.launch_current_election(target_community_id uuid,target_cycle_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare community_row public.communities; cycle_row public.election_cycles; round_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into community_row from public.communities where id=target_community_id for update;
  if community_row.id is null or not exists(select 1 from public.memberships membership
    where membership.community_id=community_row.id and membership.user_id=auth.uid() and membership.status='active') then
    raise exception 'Active community membership required' using errcode='42501'; end if;
  select * into cycle_row from public.election_cycles where id=target_cycle_id and community_id=community_row.id for update;
  if cycle_row.id is null or cycle_row.status<>'candidacy' then
    raise exception 'Authoritative candidacy cycle required' using errcode='55000'; end if;
  if cycle_row.purpose='founding' then
    if community_row.governance_state<>'democratic_transition' or community_row.active_election_cycle_id<>cycle_row.id then
      raise exception 'Founding retry is not authoritative' using errcode='55000'; end if;
  elsif cycle_row.purpose='reconstitution' then
    if community_row.governance_state<>'democratic' or exists(select 1 from public.election_cycles other
      where other.community_id=community_row.id and other.id<>cycle_row.id and other.status in ('candidacy','voting')) then
      raise exception 'Reconstitution cycle is not authoritative' using errcode='55000'; end if;
  else raise exception 'Unsupported election purpose' using errcode='55000'; end if;
  round_id:=public.freeze_election_cycle(cycle_row.id);
  return round_id;
end $$;
revoke all on function public.launch_current_election(uuid,uuid) from public;
grant execute on function public.launch_current_election(uuid,uuid) to authenticated;

-- A community-facing identity belongs to the membership, not to the authentication account. This
-- narrow boundary lets an active member update only their own label without exposing auth data or
-- making a label an eligibility requirement.
create function public.set_community_display_name(target_community_id uuid, requested_display_name text)
returns text language plpgsql security definer set search_path='' as $$
declare normalized_display_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;
  normalized_display_name:=btrim(requested_display_name);
  if normalized_display_name is null or char_length(normalized_display_name) not between 2 and 80 then
    raise exception 'Display name must contain between 2 and 80 characters' using errcode='22023';
  end if;
  update public.memberships
    set display_name=normalized_display_name
    where community_id=target_community_id and user_id=auth.uid() and status='active';
  if not found then
    raise exception 'Active community membership required' using errcode='42501';
  end if;
  return normalized_display_name;
end $$;
revoke all on function public.set_community_display_name(uuid,text) from public;
grant execute on function public.set_community_display_name(uuid,text) to authenticated;
