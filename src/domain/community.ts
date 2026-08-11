export type MembershipRole = "member" | "admin";
export type MembershipStatus = "pending" | "active";

export interface Community {
  id: string;
  name: string;
  join_code: string;
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
): boolean {
  if (membership.status !== "pending" || membership.user_id === currentUserId) {
    return false;
  }

  return memberships.some(
    (candidate) =>
      candidate.community_id === membership.community_id &&
      candidate.user_id === currentUserId &&
      candidate.role === "admin" &&
      candidate.status === "active",
  );
}
