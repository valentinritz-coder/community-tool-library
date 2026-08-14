export type MembershipRole = "member" | "admin";
export type MembershipStatus = "pending" | "active";
export type CommunityGovernanceState =
  | "managed"
  | "democratic_preparation"
  | "democratic_transition"
  | "democratic";

export interface Community {
  id: string;
  name: string;
  join_code: string;
  owner_id: string;
  governance_state: CommunityGovernanceState;
}

export function hasManagedAdministrationAuthority(
  community: Community,
  currentUserId: string,
  memberships: Membership[],
): boolean {
  const managedAdministrationIsActive =
    community.governance_state === "managed" ||
    community.governance_state === "democratic_preparation";

  return (
    managedAdministrationIsActive &&
    (community.owner_id === currentUserId ||
      memberships.some(
        (membership) =>
          membership.community_id === community.id &&
          membership.user_id === currentUserId &&
          membership.role === "admin" &&
          membership.status === "active",
      ))
  );
}

export function canManageAppointedAdministrator(
  community: Community,
  currentUserId: string,
  membership: Membership,
): boolean {
  return (
    hasManagedAdministrationAuthority(community, currentUserId, []) &&
    membership.community_id === community.id &&
    membership.status === "active"
  );
}

export interface Membership {
  community_id: string;
  user_id: string;
  role: MembershipRole;
  status: MembershipStatus;
}

export function canApproveMembership(
  membership: Membership,
  currentUserId: string,
  memberships: Membership[],
  communities: Community[],
): boolean {
  if (membership.status !== "pending" || membership.user_id === currentUserId) {
    return false;
  }

  const community = communities.find(
    (candidate) => candidate.id === membership.community_id,
  );
  return community
    ? hasManagedAdministrationAuthority(community, currentUserId, memberships)
    : false;
}
