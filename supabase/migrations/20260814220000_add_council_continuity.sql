-- Issue #60: preserve democratic authority through resignations and council vacancies.

create type public.election_purpose as enum ('founding', 'reconstitution');
create type public.council_operational_status as enum ('operational', 'under_strength', 'vacant');
create type public.council_mandate_end_reason as enum ('resignation');
create type public.council_continuity_event as enum ('resignation', 'reconstitution_opened', 'mandates_installed');

alter table public.election_cycles
  add column purpose public.election_purpose not null default 'founding';
alter table public.election_cycles drop constraint election_cycles_target_seats_check;
alter table public.election_cycles add constraint election_cycles_purpose_target_check check (
  (purpose = 'founding' and target_seats in (3, 5))
  or (purpose = 'reconstitution' and target_seats between 1 and 5)
);

-- Mandates are historical records. The partial index, rather than a lifetime key, prevents a
-- member holding two seats while allowing a resigned member to win a later election.
alter table public.elected_council_mandates drop constraint elected_council_mandates_pkey;
alter table public.elected_council_mandates
  add column id uuid not null default gen_random_uuid(),
  add column ended_at timestamptz,
  add column ended_reason public.council_mandate_end_reason,
  add primary key (id),
  add check ((ended_at is null) = (ended_reason is null));
create unique index one_active_elected_mandate_per_member
  on public.elected_council_mandates(community_id, member_id) where ended_at is null;

create table public.council_continuity_history (
  id bigint generated always as identity primary key,
  community_id uuid not null references public.communities(id) on delete restrict,
  council_id uuid not null references public.elected_councils(id) on delete restrict,
  event public.council_continuity_event not null,
  mandate_id uuid references public.elected_council_mandates(id) on delete restrict,
  election_cycle_id uuid references public.election_cycles(id) on delete restrict,
  actor_id uuid references auth.users(id) on delete restrict,
  occurred_at timestamptz not null default now(),
  details jsonb not null default '{}'::jsonb,
  check (
    (event='resignation' and mandate_id is not null and election_cycle_id is null) or
    (event in ('reconstitution_opened','mandates_installed') and mandate_id is null and election_cycle_id is not null)
  )
);
alter table public.council_continuity_history enable row level security;
revoke all on public.council_continuity_history from anon, authenticated;

create function public.active_elected_mandate_count(target_community_id uuid)
returns integer language sql stable security definer set search_path='' as $$
  select count(*)::integer from public.elected_council_mandates
  where community_id=target_community_id and ended_at is null;
$$;

create function public.get_council_operational_status(target_community_id uuid)
returns public.council_operational_status language sql stable security definer set search_path='' as $$
  select case
    when public.active_elected_mandate_count(target_community_id)>=3 then 'operational'::public.council_operational_status
    when public.active_elected_mandate_count(target_community_id)>0 then 'under_strength'::public.council_operational_status
    else 'vacant'::public.council_operational_status end;
$$;

create function public.council_vacant_seat_count(target_community_id uuid)
returns integer language sql stable security definer set search_path='' as $$
  select greatest(0, least(ec.target_seats::integer,
    ec.target_seats::integer-public.active_elected_mandate_count(target_community_id)))
  from public.elected_councils ec where ec.community_id=target_community_id;
$$;

create or replace function public.has_elected_council_authority(target_community_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select public.active_elected_mandate_count(target_community_id)>=3 and exists (
    select 1 from public.communities c join public.elected_council_mandates m on m.community_id=c.id
    where c.id=target_community_id and c.governance_state='democratic'
      and m.member_id=auth.uid() and m.ended_at is null);
$$;

create or replace function public.has_temporary_caretaker_authority(target_community_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists (
    select 1 from public.communities c where c.id=target_community_id and (
      (c.governance_state='democratic_transition' and public.is_active_appointed_admin(c.id)) or
      (c.governance_state='democratic' and public.active_elected_mandate_count(c.id) between 1 and 2
        and exists (select 1 from public.elected_council_mandates m
          where m.community_id=c.id and m.member_id=auth.uid() and m.ended_at is null))));
$$;

-- Ordinary administration deliberately excludes under-strength democratic caretakers.
create or replace function public.is_active_community_admin(target_community_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists (
    select 1 from public.communities c where c.id=target_community_id and case c.governance_state
      when 'managed' then c.owner_id=auth.uid() or public.is_active_appointed_admin(c.id)
      when 'democratic_preparation' then c.owner_id=auth.uid() or public.is_active_appointed_admin(c.id)
      when 'democratic_transition' then public.is_active_appointed_admin(c.id)
      when 'democratic' then public.has_elected_council_authority(c.id)
      else false end);
$$;

-- Caretakers receive only the explicitly classified continuity operations below. Keeping this
-- separate from is_active_community_admin prevents booking overrides and other ordinary council
-- powers from leaking to an under-strength council.
create function public.has_community_continuity_authority(target_community_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select public.is_active_community_admin(target_community_id)
    or public.has_temporary_caretaker_authority(target_community_id);
$$;

create or replace function public.approve_membership(target_community_id uuid,target_user_id uuid)
returns public.memberships language plpgsql security definer set search_path='' as $$
declare approved_membership public.memberships;
begin
  if not public.has_community_continuity_authority(target_community_id) then
    raise exception 'Community continuity authority required' using errcode='42501'; end if;
  update public.memberships set status='active' where community_id=target_community_id
    and user_id=target_user_id and role='member' and status='pending' returning * into approved_membership;
  if approved_membership is null then raise exception 'Pending membership not found' using errcode='P0002'; end if;
  return approved_membership;
end $$;

create or replace function public.list_moderation_reports(target_community_id uuid)
returns table(id uuid,target_type public.moderation_target_type,target_label text,item_id uuid,
  reason public.moderation_reason,note text,status public.moderation_status,created_at timestamptz,action_taken text)
language plpgsql stable security definer set search_path='' as $$
begin
  if not public.has_community_continuity_authority(target_community_id) then
    raise exception 'Community continuity authority required' using errcode='42501'; end if;
  return query select r.id,r.target_type,
    case when r.target_type='item' then coalesce(i.name,'Item') else 'Transaction counterparty' end,
    r.item_id,r.reason,r.note,r.status,r.created_at,r.action_taken
  from public.moderation_reports r left join public.items i on i.id=r.item_id
  where r.community_id=target_community_id order by r.created_at desc;
end $$;

create or replace function public.handle_moderation_report(target_report_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  update public.moderation_reports set status='handled',handled_at=now(),handled_by=auth.uid(),action_taken='reviewed'
  where id=target_report_id and status='open' and public.has_community_continuity_authority(community_id);
  if not found then
    if exists(select 1 from public.moderation_reports where id=target_report_id and status='handled'
      and public.has_community_continuity_authority(community_id)) then
      raise exception 'Report is already handled' using errcode='22023'; end if;
    raise exception 'Community continuity authority required' using errcode='42501';
  end if;
end $$;

create or replace function public.hide_reported_item(target_report_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare report_item uuid;
begin
  update public.moderation_reports set status='handled',handled_at=now(),handled_by=auth.uid(),action_taken='item hidden'
  where id=target_report_id and target_type='item' and status='open'
    and public.has_community_continuity_authority(community_id) returning item_id into report_item;
  if report_item is null then
    if exists(select 1 from public.moderation_reports where id=target_report_id and target_type='item' and status='handled'
      and public.has_community_continuity_authority(community_id)) then
      raise exception 'Report is already handled' using errcode='22023'; end if;
    raise exception 'Community continuity authority and open item report required' using errcode='42501';
  end if;
  update public.items set moderation_hidden=true where id=report_item;
end $$;

create function public.resign_elected_council_mandate(target_community_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare c public.communities; m public.elected_council_mandates;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  -- Global continuity lock order starts with community, then council/mandate rows.
  select * into c from public.communities where id=target_community_id for update;
  if c.id is null or c.governance_state<>'democratic' then
    raise exception 'Community is not democratically governed' using errcode='55000';
  end if;
  select * into m from public.elected_council_mandates
    where community_id=c.id and member_id=auth.uid() and ended_at is null for update;
  if m.id is null then raise exception 'No active elected mandate held by current user' using errcode='42501'; end if;
  if m.ended_at is not null then raise exception 'Mandate is no longer active' using errcode='55000'; end if;
  update public.elected_council_mandates set ended_at=now(),ended_reason='resignation' where id=m.id;
  insert into public.council_continuity_history(community_id,council_id,event,mandate_id,actor_id)
    values(c.id,m.council_id,'resignation',m.id,auth.uid());
end $$;

-- Any active member can deterministically open candidacy for precisely the seats vacant while the
-- community lock is held. No owner, administrator, caretaker or councillor discretion is needed.
create function public.open_council_reconstitution_cycle(target_community_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.communities; ec public.elected_councils; vacancies integer; cycle_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into c from public.communities where id=target_community_id for update;
  if c.id is null or c.governance_state<>'democratic' then raise exception 'Community is not awaiting democratic reconstitution' using errcode='55000'; end if;
  if not exists(select 1 from public.memberships where community_id=c.id and user_id=auth.uid() and status='active') then
    raise exception 'Active community membership required' using errcode='42501';
  end if;
  select * into ec from public.elected_councils where community_id=c.id for update;
  vacancies := ec.target_seats-public.active_elected_mandate_count(c.id);
  if vacancies<=0 then raise exception 'Council has no vacant seats' using errcode='55000'; end if;
  if exists(select 1 from public.election_cycles where community_id=c.id and status in ('candidacy','voting')) then
    raise exception 'A community election cycle is already active' using errcode='55000'; end if;
  insert into public.election_cycles(community_id,target_seats,purpose)
    values(c.id,vacancies,'reconstitution') returning id into cycle_id;
  insert into public.council_continuity_history(community_id,council_id,event,election_cycle_id,actor_id,details)
    values(c.id,ec.id,'reconstitution_opened',cycle_id,auth.uid(),jsonb_build_object('seats_available',vacancies));
  return cycle_id;
end $$;

-- Candidacy remains individual, but an active councillor cannot occupy another simultaneous seat.
create or replace function public.stand_for_election(target_cycle_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare c public.election_cycles;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into c from public.election_cycles where id=target_cycle_id for update;
  if c.id is null or c.status<>'candidacy' then raise exception 'Candidacies are not open' using errcode='55000'; end if;
  if not exists(select 1 from public.communities where id=c.community_id and
    ((c.purpose='founding' and governance_state in ('democratic_preparation','democratic_transition')) or
     (c.purpose='reconstitution' and governance_state='democratic'))) then
    raise exception 'Community governance is incompatible with candidacy' using errcode='55000';
  end if;
  if not exists(select 1 from public.memberships where community_id=c.community_id and user_id=auth.uid() and status='active') then
    raise exception 'Active community membership required' using errcode='42501';
  end if;
  if c.purpose='reconstitution' and exists(select 1 from public.elected_council_mandates
    where community_id=c.community_id and member_id=auth.uid() and ended_at is null) then
    raise exception 'An active councillor cannot stand for another seat' using errcode='55000';
  end if;
  insert into public.election_candidacies(cycle_id,community_id,candidate_id) values(c.id,c.community_id,auth.uid());
end $$;

create or replace function public.freeze_election_cycle(target_cycle_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.election_cycles; candidate_count integer; electorate_count integer; round_id uuid;
begin
  select * into c from public.election_cycles where id=target_cycle_id for update;
  if c.id is null or c.status<>'candidacy' then raise exception 'Election cycle cannot be frozen' using errcode='55000'; end if;
  perform 1 from public.memberships where community_id=c.community_id and status='active' order by user_id for share;
  insert into public.election_candidates(cycle_id,community_id,candidate_id)
    select ec.cycle_id,ec.community_id,ec.candidate_id from public.election_candidacies ec
    join public.memberships m on m.community_id=ec.community_id and m.user_id=ec.candidate_id and m.status='active'
    where ec.cycle_id=c.id and (c.purpose='founding' or not exists(select 1 from public.elected_council_mandates cm
      where cm.community_id=c.community_id and cm.member_id=ec.candidate_id and cm.ended_at is null));
  get diagnostics candidate_count=row_count;
  if candidate_count < (case when c.purpose='founding' then 3 else 1 end) then
    if c.purpose='founding' then
      raise exception 'At least three active candidates are required' using errcode='55000';
    end if;
    raise exception 'At least one active eligible candidate is required' using errcode='55000';
  end if;
  insert into public.election_electorate(cycle_id,community_id,voter_id)
    select c.id,c.community_id,m.user_id from public.memberships m where m.community_id=c.community_id and m.status='active';
  get diagnostics electorate_count=row_count;
  update public.election_cycles set status='voting',frozen_at=now() where id=c.id;
  insert into public.election_rounds(cycle_id,round_number,seats_available,electorate_count,quorum_threshold)
    values(c.id,1,c.target_seats,electorate_count,public.election_quorum_threshold(electorate_count)) returning id into round_id;
  insert into public.election_round_candidates select round_id,candidate_id from public.election_candidates where cycle_id=c.id;
  return round_id;
end $$;

-- Reconstitution accepts any positive winner set; the founding minimum remains three.
create or replace function public.finalize_election_round(target_round_id uuid)
returns public.election_round_status language plpgsql security definer set search_path='' as $$
declare r public.election_rounds; c public.election_cycles; ballots integer; electable integer;
  boundary_score integer; above_boundary integer; tied_boundary integer; new_round uuid; final_winners integer;
begin
  select * into r from public.election_rounds where id=target_round_id for update;
  if r.id is null or r.status<>'closed' then raise exception 'Election round is not closed and finalizable' using errcode='55000'; end if;
  select * into c from public.election_cycles where id=r.cycle_id for update;
  select count(*) into ballots from public.election_ballots where round_id=r.id;
  if ballots<r.quorum_threshold then
    update public.election_rounds set status='failed_quorum',ballot_count=ballots,finalized_at=now() where id=r.id;
    update public.election_cycles set status='failed',completed_at=now() where id=c.id; return 'failed_quorum';
  end if;
  insert into public.election_candidate_results(round_id,candidate_id,approval_count)
    select r.id,rc.candidate_id,count(a.candidate_id)::integer from public.election_round_candidates rc
    left join public.election_ballot_approvals a on a.candidate_id=rc.candidate_id and exists
      (select 1 from public.election_ballots b where b.id=a.ballot_id and b.round_id=r.id)
    where rc.round_id=r.id group by rc.candidate_id;
  select count(*) into electable from public.election_candidate_results where round_id=r.id and approval_count>0;
  if electable<=r.seats_available then
    select count(*)+electable into final_winners from public.election_provisional_winners where cycle_id=c.id;
    if final_winners < (case when c.purpose='founding' then 3 else 1 end) then
      update public.election_rounds set status='insufficient_winners',ballot_count=ballots,finalized_at=now() where id=r.id;
      update public.election_cycles set status='failed',completed_at=now() where id=c.id; return 'insufficient_winners';
    end if;
    insert into public.election_winners select cycle_id,candidate_id,carried_from_round,approval_count
      from public.election_provisional_winners where cycle_id=c.id union all
      select c.id,candidate_id,r.round_number,approval_count from public.election_candidate_results where round_id=r.id and approval_count>0;
    update public.election_rounds set status='completed',ballot_count=ballots,finalized_at=now() where id=r.id;
    update public.election_cycles set status='completed',completed_at=now() where id=c.id; return 'completed';
  end if;
  select approval_count into boundary_score from public.election_candidate_results where round_id=r.id and approval_count>0
    order by approval_count desc offset r.seats_available-1 limit 1;
  select count(*) into above_boundary from public.election_candidate_results where round_id=r.id and approval_count>boundary_score;
  select count(*) into tied_boundary from public.election_candidate_results where round_id=r.id and approval_count=boundary_score;
  insert into public.election_provisional_winners select c.id,candidate_id,r.round_number,approval_count
    from public.election_candidate_results where round_id=r.id and approval_count>boundary_score;
  if tied_boundary<=r.seats_available-above_boundary then
    insert into public.election_winners select cycle_id,candidate_id,carried_from_round,approval_count
      from public.election_provisional_winners where cycle_id=c.id union all
      select c.id,candidate_id,r.round_number,approval_count from public.election_candidate_results where round_id=r.id and approval_count=boundary_score;
    update public.election_rounds set status='completed',ballot_count=ballots,finalized_at=now() where id=r.id;
    update public.election_cycles set status='completed',completed_at=now() where id=c.id; return 'completed';
  end if;
  update public.election_candidate_results set is_runoff_candidate=true where round_id=r.id and approval_count=boundary_score;
  update public.election_rounds set status='runoff_required',ballot_count=ballots,finalized_at=now() where id=r.id;
  insert into public.election_rounds(cycle_id,round_number,seats_available,electorate_count,quorum_threshold)
    values(c.id,r.round_number+1,r.seats_available-above_boundary,r.electorate_count,r.quorum_threshold) returning id into new_round;
  insert into public.election_round_candidates select new_round,candidate_id from public.election_candidate_results
    where round_id=r.id and is_runoff_candidate; return 'runoff_required';
end $$;

create function public.install_reconstitution_winners(target_community_id uuid,target_cycle_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare c public.communities; ec public.elected_councils; cycle public.election_cycles; vacancies integer; winners integer; installed integer;
begin
  -- Stable global order: community -> council -> cycle -> mandate rows.
  select * into c from public.communities where id=target_community_id for update;
  if c.id is null or c.governance_state<>'democratic' then raise exception 'Community is not democratic' using errcode='55000'; end if;
  select * into ec from public.elected_councils where community_id=c.id for update;
  select * into cycle from public.election_cycles where id=target_cycle_id and community_id=c.id for update;
  if cycle.id is null or cycle.purpose<>'reconstitution' or cycle.status<>'completed' then
    raise exception 'Completed reconstitution election required' using errcode='55000'; end if;
  if exists(select 1 from public.council_continuity_history where election_cycle_id=cycle.id and event='mandates_installed') then
    raise exception 'Reconstitution winners already installed' using errcode='55000'; end if;
  vacancies:=ec.target_seats-public.active_elected_mandate_count(c.id);
  select count(*) into winners from public.election_winners where cycle_id=cycle.id;
  if winners<1 or winners>vacancies then raise exception 'Election winners exceed current vacancies' using errcode='55000'; end if;
  if exists(select 1 from public.election_winners w join public.elected_council_mandates m
    on m.community_id=c.id and m.member_id=w.candidate_id and m.ended_at is null where w.cycle_id=cycle.id) then
    raise exception 'Winner already holds an active mandate' using errcode='55000'; end if;
  insert into public.elected_council_mandates(council_id,community_id,member_id,source_cycle_id,took_office_at,nominal_term_ends_at)
    select ec.id,c.id,w.candidate_id,cycle.id,now(),now()+interval '12 months' from public.election_winners w where w.cycle_id=cycle.id;
  get diagnostics installed=row_count;
  insert into public.council_continuity_history(community_id,council_id,event,election_cycle_id,details)
    values(c.id,ec.id,'mandates_installed',cycle.id,jsonb_build_object('mandates_installed',installed));
  return installed;
end $$;

create function public.finalize_reconstitution_round(target_round_id uuid)
returns public.election_round_status language plpgsql security definer set search_path='' as $$
declare r public.election_rounds; cycle public.election_cycles; c public.communities;
  ec public.elected_councils; result public.election_round_status;
begin
  select * into r from public.election_rounds where id=target_round_id;
  select * into cycle from public.election_cycles where id=r.cycle_id;
  select * into c from public.communities where id=cycle.community_id for update;
  if c.governance_state<>'democratic' or cycle.purpose<>'reconstitution' then raise exception 'Round is not a reconstitution election' using errcode='55000'; end if;
  select * into ec from public.elected_councils where community_id=c.id for update;
  select * into cycle from public.election_cycles where id=cycle.id and community_id=c.id for update;
  select * into r from public.election_rounds where id=target_round_id and cycle_id=cycle.id for update;
  perform public.close_election_round(r.id);
  result:=public.finalize_election_round(r.id);
  if result='completed' then perform public.install_reconstitution_winners(c.id,cycle.id); end if;
  return result;
end $$;

-- Minimal privacy-safe contract for #57; it exposes mandates and aggregate lifecycle, never ballots.
create function public.get_council_continuity(target_community_id uuid)
returns table(governance_state public.community_governance_state,target_seats smallint,active_mandates integer,
  vacant_seats integer,operational_status public.council_operational_status,current_user_has_mandate boolean,
  may_resign boolean,reconstitution_cycle_id uuid,reconstitution_status public.election_cycle_status)
language sql stable security definer set search_path='' as $$
  select c.governance_state,ec.target_seats,public.active_elected_mandate_count(c.id),
    public.council_vacant_seat_count(c.id),public.get_council_operational_status(c.id),
    exists(select 1 from public.elected_council_mandates m where m.community_id=c.id and m.member_id=auth.uid() and m.ended_at is null),
    c.governance_state='democratic' and exists(select 1 from public.elected_council_mandates m where m.community_id=c.id and m.member_id=auth.uid() and m.ended_at is null),
    e.id,e.status from public.communities c join public.elected_councils ec on ec.community_id=c.id
    left join lateral (select x.id,x.status from public.election_cycles x where x.community_id=c.id and x.purpose='reconstitution'
      order by x.created_at desc limit 1) e on true
  where c.id=target_community_id and exists(select 1 from public.memberships m
    where m.community_id=c.id and m.user_id=auth.uid() and m.status='active');
$$;

revoke all on function public.active_elected_mandate_count(uuid) from public;
revoke all on function public.get_council_operational_status(uuid) from public;
revoke all on function public.council_vacant_seat_count(uuid) from public;
revoke all on function public.has_community_continuity_authority(uuid) from public;
revoke all on function public.resign_elected_council_mandate(uuid) from public;
revoke all on function public.open_council_reconstitution_cycle(uuid) from public;
revoke all on function public.install_reconstitution_winners(uuid,uuid) from public;
revoke all on function public.finalize_reconstitution_round(uuid) from public;
revoke all on function public.get_council_continuity(uuid) from public;
grant execute on function public.resign_elected_council_mandate(uuid),
  public.open_council_reconstitution_cycle(uuid),public.get_council_continuity(uuid),
  public.has_community_continuity_authority(uuid) to authenticated;
grant execute on function public.finalize_reconstitution_round(uuid) to service_role;
