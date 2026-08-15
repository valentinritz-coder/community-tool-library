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
export type CommitBlocker = "candidate_minimum" | "electorate_minimum";
export type LaunchBlocker = "candidate_minimum";

export interface GovernancePerson {
  id: string;
  label: string;
}

export interface GovernanceSnapshot {
  community_id: string;
  governance_state: CommunityGovernanceState;
  is_owner: boolean;
  owner_label: string;
  current_membership_role: MembershipRole;
  current_user_label: string;
  appointed_admins: GovernancePerson[];
  may_manage_appointed_admins: boolean;
  may_approve_memberships: boolean;
  may_moderate_community: boolean;
  council_target: CouncilTarget | null;
  may_commit_founding_transfer: boolean;
  commit_blocker: CommitBlocker | null;
  cycle_id: string | null;
  cycle_status: ElectionCycleStatus | null;
  cycle_seats_to_fill: number | null;
  valid_candidate_count: number;
  may_launch_current_election: boolean;
  launch_blocker: LaunchBlocker | null;
  candidates: GovernancePerson[];
  current_user_is_candidate: boolean;
  round_id: string | null;
  round_number: number | null;
  round_status: ElectionRoundStatus | null;
  seats_available: number | null;
  current_user_may_vote: boolean;
  current_user_ballot_recorded: boolean;
  active_mandates: number | null;
  elected_members: GovernancePerson[];
  vacant_seats: number | null;
  operational_status: CouncilOperationalStatus | null;
  current_user_has_mandate: boolean;
  may_resign: boolean;
  council_took_office_at: string | null;
  council_term_ends_at: string | null;
  latest_election_status: ElectionCycleStatus | null;
  latest_round_status: ElectionRoundStatus | null;
  latest_ballot_count: number | null;
  latest_electorate_count: number | null;
  latest_quorum_threshold: number | null;
}

const governanceStates: CommunityGovernanceState[] = [
  "managed",
  "democratic_preparation",
  "democratic_transition",
  "democratic",
];
const cycleStatuses: ElectionCycleStatus[] = [
  "candidacy",
  "voting",
  "completed",
  "failed",
];
const roundStatuses: ElectionRoundStatus[] = [
  "voting",
  "closed",
  "completed",
  "runoff_required",
  "failed_quorum",
  "insufficient_winners",
];
const operationalStatuses: CouncilOperationalStatus[] = [
  "operational",
  "under_strength",
  "vacant",
];
const commitBlockers: CommitBlocker[] = [
  "candidate_minimum",
  "electorate_minimum",
];

function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}

function isNullableNonNegativeInteger(value: unknown): value is number | null {
  return value === null || (Number.isInteger(value) && Number(value) >= 0);
}

function parsePeople(value: unknown, field: string): GovernancePerson[] {
  if (!Array.isArray(value)) throw new Error(`${field} must be a list.`);
  return value.map((person) => {
    if (!person || typeof person !== "object")
      throw new Error(`${field} contains an invalid person.`);
    const record = person as Record<string, unknown>;
    if (
      typeof record.id !== "string" ||
      typeof record.label !== "string" ||
      record.label.trim().length === 0
    )
      throw new Error(`${field} contains an invalid identity.`);
    return { id: record.id, label: record.label };
  });
}

export function canCommitFoundingTransfer(
  snapshot: GovernanceSnapshot,
): boolean {
  return snapshot.may_commit_founding_transfer;
}

export function parseGovernanceSnapshot(value: unknown): GovernanceSnapshot {
  if (!value || typeof value !== "object")
    throw new Error("Governance information is unavailable.");
  const row = value as Record<string, unknown>;
  const governanceState = row.governance_state;
  const councilTarget = row.council_target;
  const cycleStatus = row.cycle_status;
  const roundStatus = row.round_status;
  const operationalStatus = row.operational_status;
  const commitBlocker = row.commit_blocker;
  const latestElectionStatus = row.latest_election_status;
  const latestRoundStatus = row.latest_round_status;

  if (
    typeof row.community_id !== "string" ||
    typeof governanceState !== "string" ||
    !governanceStates.includes(governanceState as CommunityGovernanceState) ||
    typeof row.is_owner !== "boolean" ||
    typeof row.owner_label !== "string" ||
    typeof row.current_user_label !== "string" ||
    row.current_user_label.trim().length === 0 ||
    !["member", "admin"].includes(String(row.current_membership_role)) ||
    !(councilTarget === null || councilTarget === 3 || councilTarget === 5) ||
    typeof row.may_commit_founding_transfer !== "boolean" ||
    typeof row.may_manage_appointed_admins !== "boolean" ||
    typeof row.may_approve_memberships !== "boolean" ||
    typeof row.may_moderate_community !== "boolean" ||
    !(
      commitBlocker === null ||
      (typeof commitBlocker === "string" &&
        commitBlockers.includes(commitBlocker as CommitBlocker))
    ) ||
    !isNullableString(row.cycle_id) ||
    !isNullableNonNegativeInteger(row.cycle_seats_to_fill) ||
    !isNullableNonNegativeInteger(row.valid_candidate_count) ||
    row.valid_candidate_count === null ||
    typeof row.may_launch_current_election !== "boolean" ||
    !(
      row.launch_blocker === null || row.launch_blocker === "candidate_minimum"
    ) ||
    !(
      cycleStatus === null ||
      (typeof cycleStatus === "string" &&
        cycleStatuses.includes(cycleStatus as ElectionCycleStatus))
    ) ||
    typeof row.current_user_is_candidate !== "boolean" ||
    !isNullableString(row.round_id) ||
    !isNullableNonNegativeInteger(row.round_number) ||
    !(
      roundStatus === null ||
      (typeof roundStatus === "string" &&
        roundStatuses.includes(roundStatus as ElectionRoundStatus))
    ) ||
    !isNullableNonNegativeInteger(row.seats_available) ||
    typeof row.current_user_may_vote !== "boolean" ||
    typeof row.current_user_ballot_recorded !== "boolean" ||
    !isNullableNonNegativeInteger(row.active_mandates) ||
    !isNullableNonNegativeInteger(row.vacant_seats) ||
    !(
      operationalStatus === null ||
      (typeof operationalStatus === "string" &&
        operationalStatuses.includes(
          operationalStatus as CouncilOperationalStatus,
        ))
    ) ||
    typeof row.current_user_has_mandate !== "boolean" ||
    typeof row.may_resign !== "boolean" ||
    !isNullableString(row.council_took_office_at) ||
    !isNullableString(row.council_term_ends_at) ||
    !(
      latestElectionStatus === null ||
      (typeof latestElectionStatus === "string" &&
        cycleStatuses.includes(latestElectionStatus as ElectionCycleStatus))
    ) ||
    !(
      latestRoundStatus === null ||
      (typeof latestRoundStatus === "string" &&
        roundStatuses.includes(latestRoundStatus as ElectionRoundStatus))
    ) ||
    !isNullableNonNegativeInteger(row.latest_ballot_count) ||
    !isNullableNonNegativeInteger(row.latest_electorate_count) ||
    !isNullableNonNegativeInteger(row.latest_quorum_threshold)
  )
    throw new Error("Governance information has an invalid shape.");

  const snapshot: GovernanceSnapshot = {
    community_id: row.community_id,
    governance_state: governanceState as CommunityGovernanceState,
    is_owner: row.is_owner,
    owner_label: row.owner_label,
    current_membership_role: row.current_membership_role as MembershipRole,
    current_user_label: row.current_user_label,
    appointed_admins: parsePeople(row.appointed_admins, "appointed_admins"),
    may_manage_appointed_admins: row.may_manage_appointed_admins,
    may_approve_memberships: row.may_approve_memberships,
    may_moderate_community: row.may_moderate_community,
    council_target: councilTarget,
    may_commit_founding_transfer: row.may_commit_founding_transfer,
    commit_blocker: commitBlocker as CommitBlocker | null,
    cycle_id: row.cycle_id,
    cycle_status: cycleStatus as ElectionCycleStatus | null,
    cycle_seats_to_fill: row.cycle_seats_to_fill,
    valid_candidate_count: row.valid_candidate_count,
    may_launch_current_election: row.may_launch_current_election,
    launch_blocker: row.launch_blocker as LaunchBlocker | null,
    candidates: parsePeople(row.candidates, "candidates"),
    current_user_is_candidate: row.current_user_is_candidate,
    round_id: row.round_id,
    round_number: row.round_number,
    round_status: roundStatus as ElectionRoundStatus | null,
    seats_available: row.seats_available,
    current_user_may_vote: row.current_user_may_vote,
    current_user_ballot_recorded: row.current_user_ballot_recorded,
    active_mandates: row.active_mandates,
    elected_members: parsePeople(row.elected_members, "elected_members"),
    vacant_seats: row.vacant_seats,
    operational_status: operationalStatus as CouncilOperationalStatus | null,
    current_user_has_mandate: row.current_user_has_mandate,
    may_resign: row.may_resign,
    council_took_office_at: row.council_took_office_at,
    council_term_ends_at: row.council_term_ends_at,
    latest_election_status: latestElectionStatus as ElectionCycleStatus | null,
    latest_round_status: latestRoundStatus as ElectionRoundStatus | null,
    latest_ballot_count: row.latest_ballot_count,
    latest_electorate_count: row.latest_electorate_count,
    latest_quorum_threshold: row.latest_quorum_threshold,
  };

  if (
    snapshot.governance_state === "democratic" &&
    (snapshot.council_target === null ||
      snapshot.active_mandates === null ||
      snapshot.vacant_seats === null ||
      snapshot.operational_status === null ||
      snapshot.council_took_office_at === null ||
      snapshot.council_term_ends_at === null)
  )
    throw new Error("Democratic council information is incomplete.");
  if (
    snapshot.cycle_status === "voting" &&
    (snapshot.round_id === null ||
      snapshot.round_status !== "voting" ||
      snapshot.seats_available === null)
  )
    throw new Error("Voting round information is incomplete.");
  return snapshot;
}
