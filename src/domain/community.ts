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

export function canManageAppointedAdministrator(
  community: Community,
  currentUserId: string,
  membership: Membership,
): boolean {
  return (
    community.owner_id === currentUserId &&
    (community.governance_state === "managed" ||
      community.governance_state === "democratic_preparation") &&
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
  communities: Community[] = [],
): boolean {
  if (membership.status !== "pending" || membership.user_id === currentUserId) {
    return false;
  }

  const community = communities.find(
    (candidate) => candidate.id === membership.community_id,
  );
  const managedOwner =
    community?.owner_id === currentUserId &&
    (community.governance_state === "managed" ||
      community.governance_state === "democratic_preparation");

  return (
    managedOwner ||
    memberships.some(
      (candidate) =>
        candidate.community_id === membership.community_id &&
        candidate.user_id === currentUserId &&
        candidate.role === "admin" &&
        candidate.status === "active",
    )
  );
}
