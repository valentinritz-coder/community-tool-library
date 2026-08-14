create type public.community_governance_state as enum (
  'managed',
  'democratic_preparation',
  'democratic_transition',
  'democratic'
);

alter table public.communities
  add column owner_id uuid references auth.users(id) on delete restrict,
  add column governance_state public.community_governance_state not null default 'managed';

-- The historical API atomically created exactly one active admin for every community.
-- Abort rather than guessing when privileged/manual writes have violated that invariant.
do $$
begin
  if exists (
    select c.id
    from public.communities c
    left join public.memberships m
      on m.community_id = c.id and m.role = 'admin' and m.status = 'active'
    group by c.id
    having count(m.user_id) <> 1
  ) then
    raise exception 'Cannot backfill community ownership: every community must have exactly one historical active admin';
  end if;
end;
$$;

update public.communities c
set owner_id = m.user_id
from public.memberships m
where m.community_id = c.id
  and m.role = 'admin'
  and m.status = 'active';

alter table public.communities alter column owner_id set not null;

create function public.is_community_owner(target_community_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.communities
    where id = target_community_id and owner_id = auth.uid()
  );
$$;

create function public.is_active_appointed_admin(target_community_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.memberships
    where community_id = target_community_id
      and user_id = auth.uid()
      and status = 'active'
      and role = 'admin'
  );
$$;

create function public.has_managed_administration_authority(target_community_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.communities c
    where c.id = target_community_id
      and c.governance_state in ('managed', 'democratic_preparation')
      and (
        c.owner_id = auth.uid()
        or public.is_active_appointed_admin(c.id)
      )
  );
$$;

-- Preserve the established helper contract for ordinary administration callers.
create or replace function public.is_active_community_admin(target_community_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_managed_administration_authority(target_community_id);
$$;

revoke all on function public.is_community_owner(uuid) from public;
revoke all on function public.is_active_appointed_admin(uuid) from public;
revoke all on function public.has_managed_administration_authority(uuid) from public;
grant execute on function public.is_community_owner(uuid) to authenticated;
grant execute on function public.is_active_appointed_admin(uuid) to authenticated;
grant execute on function public.has_managed_administration_authority(uuid) to authenticated;

create or replace function public.create_community(community_name text)
returns public.communities
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_community public.communities;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if char_length(btrim(community_name)) not between 2 and 80 then
    raise exception 'Community name must contain between 2 and 80 characters' using errcode = '22023';
  end if;

  insert into public.communities (name, owner_id, governance_state)
  values (btrim(community_name), auth.uid(), 'managed')
  returning * into new_community;

  insert into public.memberships (community_id, user_id, role, status)
  values (new_community.id, auth.uid(), 'admin', 'active');
  return new_community;
end;
$$;

create function public.set_appointed_administrator(
  target_community_id uuid,
  target_user_id uuid,
  appointed boolean
)
returns public.memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  changed_membership public.memberships;
begin
  if appointed is null then
    raise exception 'Appointment decision is required' using errcode = '22023';
  end if;
  if not public.is_community_owner(target_community_id) then
    raise exception 'Only the community owner can manage appointed administrators' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.communities
    where id = target_community_id
      and governance_state in ('managed', 'democratic_preparation')
  ) then
    raise exception 'Appointed administrators can only be managed before democratic transition' using errcode = '55000';
  end if;

  update public.memberships
  set role = case when appointed then 'admin'::public.membership_role else 'member'::public.membership_role end
  where community_id = target_community_id
    and user_id = target_user_id
    and status = 'active'
  returning * into changed_membership;

  if changed_membership is null then
    raise exception 'Active community membership not found' using errcode = 'P0002';
  end if;
  return changed_membership;
end;
$$;

revoke all on function public.set_appointed_administrator(uuid, uuid, boolean) from public;
grant execute on function public.set_appointed_administrator(uuid, uuid, boolean) to authenticated;
