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
