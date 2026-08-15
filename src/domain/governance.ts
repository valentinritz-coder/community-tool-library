import type { CommunityGovernanceState, MembershipRole } from "./community";

export type CouncilTarget = 3 | 5;
export type CouncilOperationalStatus =
  | "operational"
  | "under_strength"
  | "vacant";
export type ElectionCycleStatus =
  | "candidacy"
  | "voting"
  | "completed"
  | "failed";
export type ElectionRoundStatus =
  | "voting"
  | "closed"
  | "completed"
  | "runoff_required"
  | "failed_quorum"
  | "insufficient_winners";

export interface GovernanceSnapshot {
  community_id: string;
  governance_state: CommunityGovernanceState;
  is_owner: boolean;
  current_membership_role: MembershipRole;
  appointed_admin_count: number;
  council_target: CouncilTarget | null;
  cycle_id: string | null;
  cycle_status: ElectionCycleStatus | null;
  candidate_ids: string[];
  current_user_is_candidate: boolean;
  round_id: string | null;
  round_number: number | null;
  round_status: ElectionRoundStatus | null;
  seats_available: number | null;
  current_user_may_vote: boolean;
  current_user_ballot_recorded: boolean;
  active_mandates: number | null;
  elected_member_ids: string[];
  vacant_seats: number | null;
  operational_status: CouncilOperationalStatus | null;
  current_user_has_mandate: boolean;
  may_resign: boolean;
}

export function canCommitFoundingTransfer(
  snapshot: GovernanceSnapshot,
): boolean {
  return (
    snapshot.governance_state === "democratic_preparation" &&
    snapshot.is_owner &&
    snapshot.candidate_ids.length >= 3
  );
}

export function candidateLabel(index: number): string {
  return `Candidate ${index + 1}`;
}

export function parseGovernanceSnapshot(value: unknown): GovernanceSnapshot {
  if (!value || typeof value !== "object") {
    throw new Error("Governance information is unavailable.");
  }
  const row = value as Partial<GovernanceSnapshot>;
  const governanceStates: CommunityGovernanceState[] = [
    "managed",
    "democratic_preparation",
    "democratic_transition",
    "democratic",
  ];
  if (
    typeof row.community_id !== "string" ||
    !row.governance_state ||
    !governanceStates.includes(row.governance_state) ||
    typeof row.is_owner !== "boolean" ||
    (row.current_membership_role !== "member" &&
      row.current_membership_role !== "admin") ||
    typeof row.appointed_admin_count !== "number" ||
    !Array.isArray(row.candidate_ids) ||
    !row.candidate_ids.every((id) => typeof id === "string") ||
    !Array.isArray(row.elected_member_ids) ||
    !row.elected_member_ids.every((id) => typeof id === "string")
  )
    throw new Error("Governance information has an invalid shape.");
  return row as GovernanceSnapshot;
}
