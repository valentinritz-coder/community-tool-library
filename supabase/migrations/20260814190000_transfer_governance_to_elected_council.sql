-- Issue #56: make the founding democratic transfer authoritative and irreversible.

alter table public.communities
  add column council_target_size smallint check (council_target_size in (3, 5)),
  add column active_election_cycle_id uuid references public.election_cycles(id) on delete restrict;

-- A deferred invariant permits atomic target changes while making it impossible to commit a
-- community pointer whose community or target differs from the authoritative engine cycle.
create function public.enforce_active_governance_cycle_consistency()
returns trigger language plpgsql set search_path = '' as $$
begin
  if exists (
    select 1 from public.communities c
    left join public.election_cycles e on e.id=c.active_election_cycle_id
    where c.active_election_cycle_id is not null
      and (e.id is null or e.community_id<>c.id or e.target_seats<>c.council_target_size)
  ) then raise exception 'Active governance cycle is inconsistent with community target' using errcode='23514'; end if;
  return null;
end $$;
create constraint trigger communities_active_cycle_consistency
after insert or update of active_election_cycle_id,council_target_size on public.communities
deferrable initially deferred for each row execute function public.enforce_active_governance_cycle_consistency();
create constraint trigger election_cycles_active_cycle_consistency
after update of community_id,target_seats on public.election_cycles
deferrable initially deferred for each row execute function public.enforce_active_governance_cycle_consistency();

create table public.community_governance_history (
  id bigint generated always as identity primary key,
  community_id uuid not null references public.communities(id) on delete cascade,
  from_state public.community_governance_state not null,
  to_state public.community_governance_state not null,
  election_cycle_id uuid references public.election_cycles(id) on delete restrict,
  target_seats smallint check (target_seats in (3, 5)),
  occurred_at timestamptz not null default now(),
  actor_id uuid references auth.users(id) on delete restrict,
  check (
    (from_state = 'managed' and to_state = 'democratic_preparation') or
    (from_state = 'democratic_preparation' and to_state in ('managed', 'democratic_transition')) or
    (from_state = 'democratic_transition' and to_state = 'democratic')
  )
);

create table public.elected_councils (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null unique references public.communities(id) on delete restrict,
  source_cycle_id uuid not null unique references public.election_cycles(id) on delete restrict,
  target_seats smallint not null check (target_seats in (3, 5)),
  took_office_at timestamptz not null,
  nominal_term_ends_at timestamptz not null,
  provenance text not null default 'founding_election' check (provenance = 'founding_election'),
  check (nominal_term_ends_at = took_office_at + interval '12 months')
);

create table public.elected_council_mandates (
  council_id uuid not null references public.elected_councils(id) on delete restrict,
  community_id uuid not null references public.communities(id) on delete restrict,
  member_id uuid not null references auth.users(id) on delete restrict,
  source_cycle_id uuid not null references public.election_cycles(id) on delete restrict,
  took_office_at timestamptz not null,
  nominal_term_ends_at timestamptz not null,
  provenance text not null default 'election_winner' check (provenance = 'election_winner'),
  primary key (council_id, member_id),
  unique (community_id, member_id),
  foreign key (community_id, member_id) references public.memberships(community_id, user_id),
  foreign key (source_cycle_id, member_id) references public.election_winners(cycle_id, candidate_id),
  check (nominal_term_ends_at = took_office_at + interval '12 months')
);

alter table public.community_governance_history enable row level security;
alter table public.elected_councils enable row level security;
alter table public.elected_council_mandates enable row level security;
revoke all on public.community_governance_history, public.elected_councils,
  public.elected_council_mandates from anon, authenticated;

create function public.has_elected_council_authority(target_community_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.communities c
    join public.elected_councils ec on ec.community_id = c.id
    join public.elected_council_mandates m on m.council_id = ec.id
    where c.id = target_community_id
      and c.governance_state = 'democratic'
      and m.member_id = auth.uid()
  );
$$;

create function public.has_temporary_caretaker_authority(target_community_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.communities c
    where c.id = target_community_id
      and c.governance_state = 'democratic_transition'
      and public.is_active_appointed_admin(c.id)
  );
$$;

-- Every established ordinary-administration caller now resolves authority by governance state.
create or replace function public.is_active_community_admin(target_community_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select case c.governance_state
    when 'managed' then c.owner_id = auth.uid() or public.is_active_appointed_admin(c.id)
    when 'democratic_preparation' then c.owner_id = auth.uid() or public.is_active_appointed_admin(c.id)
    when 'democratic_transition' then public.is_active_appointed_admin(c.id)
    when 'democratic' then public.has_elected_council_authority(c.id)
    else false
  end
  from public.communities c where c.id = target_community_id;
$$;

revoke all on function public.has_elected_council_authority(uuid) from public;
revoke all on function public.has_temporary_caretaker_authority(uuid) from public;
grant execute on function public.has_elected_council_authority(uuid),
  public.has_temporary_caretaker_authority(uuid) to authenticated;

create function public.begin_democratic_preparation(target_community_id uuid, requested_seats integer)
returns uuid language plpgsql security definer set search_path = '' as $$
declare c public.communities; cycle_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if requested_seats not in (3, 5) then raise exception 'Council target must be 3 or 5' using errcode='22023'; end if;
  select * into c from public.communities where id=target_community_id for update;
  if c.id is null or c.owner_id <> auth.uid() then raise exception 'Only the community owner can start democratic preparation' using errcode='42501'; end if;
  if c.governance_state <> 'managed' then raise exception 'Community cannot enter democratic preparation' using errcode='55000'; end if;
  update public.communities set governance_state='democratic_preparation', council_target_size=requested_seats where id=c.id;
  cycle_id := public.create_election_cycle(c.id, requested_seats);
  update public.communities set active_election_cycle_id=cycle_id where id=c.id;
  insert into public.community_governance_history(community_id,from_state,to_state,election_cycle_id,target_seats,actor_id)
    values(c.id,'managed','democratic_preparation',cycle_id,requested_seats,auth.uid());
  return cycle_id;
end $$;

create function public.change_preparation_council_target(target_community_id uuid, requested_seats integer)
returns void language plpgsql security definer set search_path = '' as $$
declare c public.communities; cycle public.election_cycles;
begin
  if requested_seats not in (3, 5) then raise exception 'Council target must be 3 or 5' using errcode='22023'; end if;
  select * into c from public.communities where id=target_community_id for update;
  if c.id is null or c.owner_id <> auth.uid() then raise exception 'Only the community owner can change the council target' using errcode='42501'; end if;
  if c.governance_state <> 'democratic_preparation' then raise exception 'Council target is immutable after commitment' using errcode='55000'; end if;
  select * into cycle from public.election_cycles where id=c.active_election_cycle_id and community_id=c.id for update;
  if cycle.id is null or cycle.status <> 'candidacy' then raise exception 'Preparation candidacy cycle is not open' using errcode='55000'; end if;
  update public.election_cycles set target_seats=requested_seats where id=cycle.id;
  update public.communities set council_target_size=requested_seats where id=c.id;
end $$;

create function public.cancel_democratic_preparation(target_community_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare c public.communities; cycle public.election_cycles;
begin
  select * into c from public.communities where id=target_community_id for update;
  if c.id is null or c.owner_id <> auth.uid() then raise exception 'Only the community owner can cancel democratic preparation' using errcode='42501'; end if;
  if c.governance_state <> 'democratic_preparation' then raise exception 'Democratic transfer can no longer be cancelled' using errcode='55000'; end if;
  select * into cycle from public.election_cycles where id=c.active_election_cycle_id and community_id=c.id for update;
  if cycle.id is null or cycle.status <> 'candidacy' then raise exception 'Preparation candidacy cycle is not cancellable' using errcode='55000'; end if;
  update public.election_cycles set status='failed',completed_at=now() where id=cycle.id;
  update public.communities set governance_state='managed',active_election_cycle_id=null,council_target_size=null where id=c.id;
  insert into public.community_governance_history(community_id,from_state,to_state,election_cycle_id,target_seats,actor_id)
    values(c.id,'democratic_preparation','managed',cycle.id,cycle.target_seats,auth.uid());
end $$;

create function public.commit_democratic_transfer(target_community_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare c public.communities; cycle public.election_cycles; round_id uuid; electorate_count integer;
begin
  select * into c from public.communities where id=target_community_id for update;
  if c.id is null or c.owner_id <> auth.uid() then raise exception 'Only the community owner can commit democratic transfer' using errcode='42501'; end if;
  if c.governance_state <> 'democratic_preparation' then raise exception 'Community is not ready for democratic commitment' using errcode='55000'; end if;
  select * into cycle from public.election_cycles where id=c.active_election_cycle_id and community_id=c.id for update;
  if cycle.id is null or cycle.status <> 'candidacy' or cycle.target_seats <> c.council_target_size then
    raise exception 'Authoritative candidacy cycle is incompatible' using errcode='55000';
  end if;
  round_id := public.freeze_election_cycle(cycle.id);
  select count(*) into electorate_count from public.election_electorate where cycle_id=cycle.id;
  if electorate_count < 5 then raise exception 'At least five electors are required' using errcode='55000'; end if;
  update public.communities set governance_state='democratic_transition' where id=c.id;
  insert into public.community_governance_history(community_id,from_state,to_state,election_cycle_id,target_seats,actor_id)
    values(c.id,'democratic_preparation','democratic_transition',cycle.id,cycle.target_seats,auth.uid());
  return round_id;
end $$;

-- After a failed founding election, every active member can reopen candidacy. This cannot reverse
-- commitment or alter the frozen target, and the community row serializes concurrent retries.
create function public.open_transition_retry_cycle(target_community_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare c public.communities; prior public.election_cycles; cycle_id uuid;
begin
  if auth.uid() is null or not public.is_active_community_member(target_community_id) then raise exception 'Active community membership required' using errcode='42501'; end if;
  select * into c from public.communities where id=target_community_id for update;
  if c.id is null or c.governance_state <> 'democratic_transition' then raise exception 'Community is not awaiting another founding election' using errcode='55000'; end if;
  select * into prior from public.election_cycles where id=c.active_election_cycle_id and community_id=c.id for update;
  if prior.id is null or prior.status <> 'failed' then raise exception 'The current founding election is not terminally failed' using errcode='55000'; end if;
  cycle_id := public.create_election_cycle(c.id,c.council_target_size);
  update public.communities set active_election_cycle_id=cycle_id where id=c.id;
  return cycle_id;
end $$;

-- Internal exactly-once installation boundary. Browser roles deliberately receive no EXECUTE.
create function public.install_elected_council(target_community_id uuid, target_cycle_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare c public.communities; cycle public.election_cycles; winner_count integer; council_id uuid; office_at timestamptz := now();
begin
  select * into c from public.communities where id=target_community_id for update;
  if c.id is null or c.governance_state <> 'democratic_transition' then raise exception 'Community cannot install a council' using errcode='55000'; end if;
  if c.active_election_cycle_id <> target_cycle_id then raise exception 'Election is not authoritative for this community' using errcode='55000'; end if;
  select * into cycle from public.election_cycles where id=target_cycle_id and community_id=c.id for update;
  if cycle.id is null or cycle.status <> 'completed' or cycle.target_seats <> c.council_target_size then raise exception 'A completed matching election is required' using errcode='55000'; end if;
  select count(*) into winner_count from public.election_winners where cycle_id=cycle.id;
  if winner_count < 3 or (cycle.target_seats=3 and winner_count<>3) or (cycle.target_seats=5 and winner_count not between 3 and 5) then
    raise exception 'Election did not produce an installable council' using errcode='55000';
  end if;
  insert into public.elected_councils(community_id,source_cycle_id,target_seats,took_office_at,nominal_term_ends_at)
    values(c.id,cycle.id,cycle.target_seats,office_at,office_at+interval '12 months') returning id into council_id;
  insert into public.elected_council_mandates(council_id,community_id,member_id,source_cycle_id,took_office_at,nominal_term_ends_at)
    select council_id,c.id,w.candidate_id,cycle.id,office_at,office_at+interval '12 months' from public.election_winners w where w.cycle_id=cycle.id;
  update public.communities set governance_state='democratic' where id=c.id;
  insert into public.community_governance_history(community_id,from_state,to_state,election_cycle_id,target_seats,actor_id)
    values(c.id,'democratic_transition','democratic',cycle.id,cycle.target_seats,null);
  return council_id;
end $$;

-- Serialize appointment changes with commitment; authority is rechecked under the same row lock.
create or replace function public.set_appointed_administrator(target_community_id uuid,target_user_id uuid,appointed boolean)
returns public.memberships language plpgsql security definer set search_path = '' as $$
declare c public.communities; changed_membership public.memberships;
begin
  if appointed is null then raise exception 'Appointment decision is required' using errcode='22023'; end if;
  select * into c from public.communities where id=target_community_id for update;
  if c.id is null or c.owner_id <> auth.uid() then raise exception 'Only the community owner can manage appointed administrators' using errcode='42501'; end if;
  if c.governance_state not in ('managed','democratic_preparation') then raise exception 'Appointed administrators can only be managed before democratic transition' using errcode='55000'; end if;
  update public.memberships set role=case when appointed then 'admin'::public.membership_role else 'member'::public.membership_role end
    where community_id=c.id and user_id=target_user_id and status='active' returning * into changed_membership;
  if changed_membership is null then raise exception 'Active community membership not found' using errcode='P0002'; end if;
  return changed_membership;
end $$;

revoke all on function public.begin_democratic_preparation(uuid,integer) from public;
revoke all on function public.change_preparation_council_target(uuid,integer) from public;
revoke all on function public.cancel_democratic_preparation(uuid) from public;
revoke all on function public.commit_democratic_transfer(uuid) from public;
revoke all on function public.open_transition_retry_cycle(uuid) from public;
revoke all on function public.install_elected_council(uuid,uuid) from public;
grant execute on function public.begin_democratic_preparation(uuid,integer),
  public.change_preparation_council_target(uuid,integer),
  public.cancel_democratic_preparation(uuid), public.commit_democratic_transfer(uuid),
  public.open_transition_retry_cycle(uuid) to authenticated;
