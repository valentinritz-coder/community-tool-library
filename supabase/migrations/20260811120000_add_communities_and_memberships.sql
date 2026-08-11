create type public.membership_role as enum ('member', 'admin');
create type public.membership_status as enum ('pending', 'active');

create table public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 80),
  join_code uuid not null unique default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table public.memberships (
  community_id uuid not null references public.communities(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.membership_role not null default 'member',
  status public.membership_status not null default 'pending',
  created_at timestamptz not null default now(),
  primary key (community_id, user_id)
);

alter table public.communities enable row level security;
alter table public.memberships enable row level security;

revoke all on public.communities, public.memberships from anon, authenticated;
grant select on public.communities, public.memberships to authenticated;

create function public.is_active_community_member(target_community_id uuid)
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
  );
$$;

create function public.is_active_community_admin(target_community_id uuid)
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

revoke all on function public.is_active_community_member(uuid) from public;
revoke all on function public.is_active_community_admin(uuid) from public;
grant execute on function public.is_active_community_member(uuid) to authenticated;
grant execute on function public.is_active_community_admin(uuid) to authenticated;

create policy "active members can read their communities"
on public.communities for select to authenticated
using ((select public.is_active_community_member(id)));

create policy "users can read their own or administered memberships"
on public.memberships for select to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_active_community_admin(community_id))
);

create function public.create_community(community_name text)
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

  insert into public.communities (name)
  values (btrim(community_name))
  returning * into new_community;

  insert into public.memberships (community_id, user_id, role, status)
  values (new_community.id, auth.uid(), 'admin', 'active');

  return new_community;
end;
$$;

create function public.request_to_join_community(requested_join_code uuid)
returns public.memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_community_id uuid;
  requested_membership public.memberships;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select id into target_community_id
  from public.communities
  where join_code = requested_join_code;

  if target_community_id is null then
    raise exception 'Invalid community join code' using errcode = '22023';
  end if;

  insert into public.memberships (community_id, user_id)
  values (target_community_id, auth.uid())
  on conflict (community_id, user_id) do nothing;

  select * into requested_membership
  from public.memberships
  where community_id = target_community_id and user_id = auth.uid();

  return requested_membership;
end;
$$;

create function public.approve_membership(target_community_id uuid, target_user_id uuid)
returns public.memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  approved_membership public.memberships;
begin
  if not public.is_active_community_admin(target_community_id) then
    raise exception 'Only an active community admin can approve memberships' using errcode = '42501';
  end if;

  update public.memberships
  set status = 'active'
  where community_id = target_community_id
    and user_id = target_user_id
    and role = 'member'
    and status = 'pending'
  returning * into approved_membership;

  if approved_membership is null then
    raise exception 'Pending membership not found' using errcode = 'P0002';
  end if;

  return approved_membership;
end;
$$;

revoke all on function public.create_community(text) from public;
revoke all on function public.request_to_join_community(uuid) from public;
revoke all on function public.approve_membership(uuid, uuid) from public;
grant execute on function public.create_community(text) to authenticated;
grant execute on function public.request_to_join_community(uuid) to authenticated;
grant execute on function public.approve_membership(uuid, uuid) to authenticated;
