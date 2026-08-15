import { describe, expect, it } from "vitest";

import { parseGovernanceSnapshot } from "./governance";

const validSnapshot = {
  community_id: "community-a",
  governance_state: "managed",
  is_owner: true,
  owner_label: "owner@example.test",
  current_membership_role: "member",
  appointed_admins: [{ id: "admin-a", label: "admin@example.test" }],
  council_target: null,
  may_commit_founding_transfer: false,
  commit_blocker: null,
  cycle_id: null,
  cycle_status: null,
  candidates: [],
  current_user_is_candidate: false,
  round_id: null,
  round_number: null,
  round_status: null,
  seats_available: null,
  current_user_may_vote: false,
  current_user_ballot_recorded: false,
  active_mandates: null,
  elected_members: [],
  vacant_seats: null,
  operational_status: null,
  current_user_has_mandate: false,
  may_resign: false,
  council_took_office_at: null,
  council_term_ends_at: null,
  latest_election_status: null,
  latest_round_status: null,
  latest_ballot_count: null,
  latest_electorate_count: null,
  latest_quorum_threshold: null,
};

describe("parseGovernanceSnapshot", () => {
  it("constructs a fully validated snapshot with readable identities", () => {
    expect(parseGovernanceSnapshot(validSnapshot)).toEqual(validSnapshot);
  });

  it.each([
    ["council_target", 4],
    ["cycle_status", "unknown"],
    ["round_status", "ranked"],
    ["seats_available", -1],
    ["current_user_may_vote", "yes"],
    ["current_user_ballot_recorded", 1],
    ["active_mandates", -1],
    ["vacant_seats", "2"],
    ["operational_status", "managed"],
    ["current_user_has_mandate", null],
    ["may_resign", "false"],
    ["appointed_admins", [{ id: "admin-a", label: "" }]],
    ["latest_ballot_count", -1],
  ])("rejects an invalid %s field", (field, invalidValue) => {
    expect(() =>
      parseGovernanceSnapshot({ ...validSnapshot, [field]: invalidValue }),
    ).toThrow(/invalid|must/i);
  });

  it("requires complete council and term information in democratic mode", () => {
    expect(() =>
      parseGovernanceSnapshot({
        ...validSnapshot,
        governance_state: "democratic",
        council_target: 5,
        active_mandates: 3,
        vacant_seats: 2,
        operational_status: "operational",
      }),
    ).toThrow("Democratic council information is incomplete.");
  });
});
