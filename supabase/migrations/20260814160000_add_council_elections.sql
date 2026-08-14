create type public.election_cycle_status as enum ('candidacy', 'voting', 'completed', 'failed');
create type public.election_round_status as enum ('voting', 'completed', 'runoff_required', 'failed_quorum', 'insufficient_winners');

create table public.election_cycles (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  target_seats smallint not null check (target_seats in (3, 5)),
  status public.election_cycle_status not null default 'candidacy',
  created_at timestamptz not null default now(),
  frozen_at timestamptz,
  completed_at timestamptz
);

create unique index one_open_election_cycle_per_community
  on public.election_cycles (community_id) where status in ('candidacy', 'voting');

create table public.election_candidacies (
  cycle_id uuid not null references public.election_cycles(id) on delete cascade,
  community_id uuid not null references public.communities(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (cycle_id, candidate_id),
  foreign key (community_id, candidate_id) references public.memberships(community_id, user_id)
);

create table public.election_electorate (
  cycle_id uuid not null references public.election_cycles(id) on delete cascade,
  community_id uuid not null references public.communities(id) on delete cascade,
  voter_id uuid not null references auth.users(id) on delete restrict,
  primary key (cycle_id, voter_id),
  foreign key (community_id, voter_id) references public.memberships(community_id, user_id)
);

create table public.election_candidates (
  cycle_id uuid not null references public.election_cycles(id) on delete cascade,
  community_id uuid not null references public.communities(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete restrict,
  primary key (cycle_id, candidate_id),
  foreign key (cycle_id, candidate_id) references public.election_candidacies(cycle_id, candidate_id)
);

create table public.election_rounds (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references public.election_cycles(id) on delete cascade,
  round_number smallint not null check (round_number > 0),
  seats_available smallint not null check (seats_available between 1 and 5),
  status public.election_round_status not null default 'voting',
  electorate_count integer not null check (electorate_count >= 0),
  ballot_count integer,
  quorum_threshold integer not null check (quorum_threshold >= 3),
  finalized_at timestamptz,
  unique (cycle_id, round_number)
);

create table public.election_round_candidates (
  round_id uuid not null references public.election_rounds(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete restrict,
  primary key (round_id, candidate_id)
);

create table public.election_ballots (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.election_rounds(id) on delete cascade,
  voter_id uuid not null references auth.users(id) on delete restrict,
  submitted_at timestamptz not null default now(),
  unique (round_id, voter_id),
  unique (id, round_id)
);

create table public.election_ballot_approvals (
  ballot_id uuid not null,
  round_id uuid not null,
  candidate_id uuid not null references auth.users(id) on delete restrict,
  primary key (ballot_id, candidate_id),
  foreign key (ballot_id, round_id) references public.election_ballots(id, round_id) on delete cascade,
  foreign key (round_id, candidate_id) references public.election_round_candidates(round_id, candidate_id)
);

create table public.election_candidate_results (
  round_id uuid not null references public.election_rounds(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete restrict,
  approval_count integer not null check (approval_count >= 0),
  is_runoff_candidate boolean not null default false,
  primary key (round_id, candidate_id)
);

create table public.election_winners (
  cycle_id uuid not null references public.election_cycles(id) on delete cascade,
  candidate_id uuid not null references auth.users(id) on delete restrict,
  elected_in_round smallint not null check (elected_in_round > 0),
  approval_count integer not null check (approval_count > 0),
  primary key (cycle_id, candidate_id)
);

create function public.election_quorum_threshold(electorate_count integer)
returns integer language sql immutable set search_path = '' as $$
  select greatest(3, ceil(electorate_count / 5.0)::integer);
$$;

alter table public.election_cycles enable row level security;
alter table public.election_candidacies enable row level security;
alter table public.election_electorate enable row level security;
alter table public.election_candidates enable row level security;
alter table public.election_rounds enable row level security;
alter table public.election_round_candidates enable row level security;
alter table public.election_ballots enable row level security;
alter table public.election_ballot_approvals enable row level security;
alter table public.election_candidate_results enable row level security;
alter table public.election_winners enable row level security;

revoke all on public.election_cycles, public.election_candidacies, public.election_electorate,
  public.election_candidates, public.election_rounds, public.election_round_candidates,
  public.election_ballots, public.election_ballot_approvals, public.election_candidate_results,
  public.election_winners from anon;
revoke all on public.election_cycles, public.election_candidacies, public.election_electorate,
  public.election_candidates, public.election_rounds, public.election_round_candidates,
  public.election_ballots, public.election_ballot_approvals, public.election_candidate_results,
  public.election_winners from authenticated;

-- This internal primitive is intentionally not granted to browser roles. Issue #56 will compose it
-- with the governance-state transition in one transaction.
create function public.create_election_cycle(target_community_id uuid, requested_seats smallint)
returns uuid language plpgsql security definer set search_path = '' as $$
declare new_id uuid;
begin
  if requested_seats not in (3, 5) then
    raise exception 'Council target must be 3 or 5' using errcode = '22023';
  end if;
  if not exists (select 1 from public.communities where id = target_community_id and governance_state in ('democratic_preparation', 'democratic_transition')) then
    raise exception 'Community is not accepting an election cycle' using errcode = '55000';
  end if;
  insert into public.election_cycles(community_id, target_seats) values (target_community_id, requested_seats) returning id into new_id;
  return new_id;
end $$;

create function public.stand_for_election(target_cycle_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare c public.election_cycles;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  select * into c from public.election_cycles where id = target_cycle_id for update;
  if c.id is null or c.status <> 'candidacy' then raise exception 'Candidacies are not open' using errcode = '55000'; end if;
  if not exists (select 1 from public.communities where id = c.community_id and governance_state in ('democratic_preparation', 'democratic_transition')) then
    raise exception 'Community governance is incompatible with candidacy' using errcode = '55000';
  end if;
  if not exists (select 1 from public.memberships where community_id = c.community_id and user_id = auth.uid() and status = 'active') then
    raise exception 'Active community membership required' using errcode = '42501';
  end if;
  insert into public.election_candidacies(cycle_id, community_id, candidate_id) values (c.id, c.community_id, auth.uid());
end $$;

create function public.withdraw_election_candidacy(target_cycle_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare c public.election_cycles;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  select * into c from public.election_cycles where id = target_cycle_id for update;
  if c.id is null or c.status <> 'candidacy' then raise exception 'Candidacies are not open' using errcode = '55000'; end if;
  delete from public.election_candidacies where cycle_id = c.id and candidate_id = auth.uid();
  if not found then raise exception 'Candidacy not found' using errcode = 'P0002'; end if;
end $$;

-- Internal freeze primitive. Locking the cycle serializes it against candidacy and withdrawal.
create function public.freeze_election_cycle(target_cycle_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare c public.election_cycles; candidate_count integer; electorate_count integer; round_id uuid;
begin
  select * into c from public.election_cycles where id = target_cycle_id for update;
  if c.id is null or c.status <> 'candidacy' then raise exception 'Election cycle cannot be frozen' using errcode = '55000'; end if;
  select count(*) into candidate_count from public.election_candidacies where cycle_id = c.id;
  if candidate_count < 3 then raise exception 'At least three candidates are required' using errcode = '55000'; end if;
  insert into public.election_electorate(cycle_id, community_id, voter_id)
    select c.id, c.community_id, m.user_id from public.memberships m where m.community_id = c.community_id and m.status = 'active';
  get diagnostics electorate_count = row_count;
  insert into public.election_candidates(cycle_id, community_id, candidate_id)
    select cycle_id, community_id, candidate_id from public.election_candidacies where cycle_id = c.id;
  update public.election_cycles set status = 'voting', frozen_at = now() where id = c.id;
  insert into public.election_rounds(cycle_id, round_number, seats_available, electorate_count, quorum_threshold)
    values (c.id, 1, c.target_seats, electorate_count, public.election_quorum_threshold(electorate_count)) returning id into round_id;
  insert into public.election_round_candidates(round_id, candidate_id)
    select round_id, candidate_id from public.election_candidates where cycle_id = c.id;
  return round_id;
end $$;

create function public.submit_election_ballot(target_round_id uuid, approved_candidate_ids uuid[])
returns uuid language plpgsql security definer set search_path = '' as $$
declare r public.election_rounds; ballot_id uuid; approval_count integer; distinct_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if approved_candidate_ids is null then raise exception 'Approvals are required' using errcode = '22023'; end if;
  select * into r from public.election_rounds where id = target_round_id for share;
  if r.id is null or r.status <> 'voting' then raise exception 'Voting is closed' using errcode = '55000'; end if;
  if not exists (select 1 from public.election_electorate e where e.cycle_id = r.cycle_id and e.voter_id = auth.uid()) then
    raise exception 'Voter is not in the electorate snapshot' using errcode = '42501';
  end if;
  select count(*), count(distinct x) into approval_count, distinct_count from unnest(approved_candidate_ids) x;
  if approval_count <> distinct_count then
    raise exception 'A ballot cannot contain duplicate approvals' using errcode = '22023';
  end if;
  if cardinality(approved_candidate_ids) > r.seats_available then raise exception 'Too many approvals' using errcode = '22023'; end if;
  if exists (select 1 from unnest(approved_candidate_ids) x where not exists (select 1 from public.election_round_candidates rc where rc.round_id = r.id and rc.candidate_id = x)) then
    raise exception 'Ballot contains an ineligible candidate' using errcode = '22023';
  end if;
  insert into public.election_ballots(round_id, voter_id) values (r.id, auth.uid()) returning id into ballot_id;
  insert into public.election_ballot_approvals(ballot_id, round_id, candidate_id) select ballot_id, r.id, x from unnest(approved_candidate_ids) x;
  return ballot_id;
end $$;

create function public.finalize_election_round(target_round_id uuid)
returns public.election_round_status language plpgsql security definer set search_path = '' as $$
declare r public.election_rounds; c public.election_cycles; ballots integer; electable integer; already_won integer;
  boundary_score integer; above_boundary integer; tied_boundary integer; new_round uuid; final_winners integer;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  select * into r from public.election_rounds where id = target_round_id for update;
  if r.id is null or r.status <> 'voting' then raise exception 'Election round is already finalized' using errcode = '55000'; end if;
  if not exists (select 1 from public.election_electorate where cycle_id = r.cycle_id and voter_id = auth.uid()) then
    raise exception 'Only the frozen electorate can finalize this round' using errcode = '42501';
  end if;
  select * into c from public.election_cycles where id = r.cycle_id for update;
  select count(*) into ballots from public.election_ballots where round_id = r.id;
  if ballots < r.quorum_threshold then
    update public.election_rounds set status='failed_quorum', ballot_count=ballots, finalized_at=now() where id=r.id;
    update public.election_cycles set status='failed', completed_at=now() where id=c.id;
    return 'failed_quorum';
  end if;
  insert into public.election_candidate_results(round_id, candidate_id, approval_count)
    select r.id, rc.candidate_id, count(a.candidate_id)::integer
    from public.election_round_candidates rc left join public.election_ballot_approvals a
      on a.candidate_id=rc.candidate_id and exists (select 1 from public.election_ballots b where b.id=a.ballot_id and b.round_id=r.id)
    where rc.round_id=r.id group by rc.candidate_id;
  select count(*) into electable from public.election_candidate_results where round_id=r.id and approval_count > 0;
  select count(*) into already_won from public.election_winners where cycle_id=c.id;
  if electable <= r.seats_available then
    insert into public.election_winners select c.id, candidate_id, r.round_number, approval_count from public.election_candidate_results where round_id=r.id and approval_count>0;
    select count(*) into final_winners from public.election_winners where cycle_id=c.id;
    if final_winners < 3 then
      update public.election_rounds set status='insufficient_winners',ballot_count=ballots,finalized_at=now() where id=r.id;
      update public.election_cycles set status='failed',completed_at=now() where id=c.id;
      return 'insufficient_winners';
    end if;
    update public.election_rounds set status='completed',ballot_count=ballots,finalized_at=now() where id=r.id;
    update public.election_cycles set status='completed',completed_at=now() where id=c.id;
    return 'completed';
  end if;
  select approval_count into boundary_score from public.election_candidate_results where round_id=r.id and approval_count>0 order by approval_count desc offset r.seats_available-1 limit 1;
  select count(*) into above_boundary from public.election_candidate_results where round_id=r.id and approval_count>boundary_score;
  select count(*) into tied_boundary from public.election_candidate_results where round_id=r.id and approval_count=boundary_score;
  insert into public.election_winners select c.id,candidate_id,r.round_number,approval_count from public.election_candidate_results where round_id=r.id and approval_count>boundary_score;
  if tied_boundary <= r.seats_available-above_boundary then
    insert into public.election_winners select c.id,candidate_id,r.round_number,approval_count from public.election_candidate_results where round_id=r.id and approval_count=boundary_score;
    update public.election_rounds set status='completed',ballot_count=ballots,finalized_at=now() where id=r.id;
    update public.election_cycles set status='completed',completed_at=now() where id=c.id;
    return 'completed';
  end if;
  update public.election_candidate_results set is_runoff_candidate=true where round_id=r.id and approval_count=boundary_score;
  update public.election_rounds set status='runoff_required',ballot_count=ballots,finalized_at=now() where id=r.id;
  insert into public.election_rounds(cycle_id,round_number,seats_available,electorate_count,quorum_threshold)
    values(c.id,r.round_number+1,r.seats_available-above_boundary,r.electorate_count,r.quorum_threshold) returning id into new_round;
  insert into public.election_round_candidates select new_round,candidate_id from public.election_candidate_results where round_id=r.id and is_runoff_candidate;
  return 'runoff_required';
end $$;

create function public.get_election_result(target_cycle_id uuid)
returns table(candidate_id uuid, approval_count integer, elected boolean, runoff_candidate boolean)
language sql stable security definer set search_path = '' as $$
  select cr.candidate_id, cr.approval_count, (w.candidate_id is not null), cr.is_runoff_candidate
  from public.election_candidate_results cr
  join public.election_rounds r on r.id=cr.round_id
  join public.election_cycles c on c.id=r.cycle_id
  left join public.election_winners w on w.cycle_id=c.id and w.candidate_id=cr.candidate_id
  where c.id=target_cycle_id and c.status in ('completed','failed')
    and exists(select 1 from public.memberships m where m.community_id=c.community_id and m.user_id=auth.uid() and m.status='active');
$$;

revoke all on function public.create_election_cycle(uuid, smallint) from public;
revoke all on function public.freeze_election_cycle(uuid) from public;
revoke all on function public.election_quorum_threshold(integer) from public;
revoke all on function public.stand_for_election(uuid) from public;
revoke all on function public.withdraw_election_candidacy(uuid) from public;
revoke all on function public.submit_election_ballot(uuid, uuid[]) from public;
revoke all on function public.finalize_election_round(uuid) from public;
revoke all on function public.get_election_result(uuid) from public;
grant execute on function public.stand_for_election(uuid), public.withdraw_election_candidacy(uuid),
  public.submit_election_ballot(uuid, uuid[]), public.finalize_election_round(uuid),
  public.get_election_result(uuid) to authenticated;
