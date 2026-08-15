import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import type { Community, Membership } from "../domain/community";
import type { GovernanceSnapshot } from "../domain/governance";
import { GovernanceSection } from "./governance-section";

const community: Community = {
  id: "community-a",
  name: "Riverside",
  join_code: "synthetic",
  owner_id: "owner-a",
  governance_state: "managed",
};
const memberships: Membership[] = [
  {
    community_id: community.id,
    user_id: "owner-a",
    role: "member",
    status: "active",
  },
  {
    community_id: community.id,
    user_id: "member-a",
    role: "member",
    status: "active",
  },
];
const base: GovernanceSnapshot = {
  community_id: community.id,
  governance_state: "managed",
  is_owner: false,
  current_membership_role: "member",
  owner_label: "owner@example.test",
  appointed_admins: [],
  council_target: null,
  cycle_id: null,
  cycle_status: null,
  may_commit_founding_transfer: false,
  commit_blocker: null,
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

function setup(snapshot: GovernanceSnapshot, currentUserId = "member-a") {
  const runAction = vi.fn().mockResolvedValue(undefined);
  render(
    <GovernanceSection
      communities={[
        { ...community, governance_state: snapshot.governance_state },
      ]}
      memberships={memberships}
      snapshots={[snapshot]}
      currentUserId={currentUserId}
      pendingActions={[]}
      runAction={runAction}
    />,
  );
  return runAction;
}

describe("GovernanceSection", () => {
  it("lets a managed owner enter reversible preparation", () => {
    const runAction = setup({ ...base, is_owner: true }, "owner-a");
    expect(
      screen.getByRole("heading", { name: "Managed administration" }),
    ).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: "Start democratic preparation" }),
    );
    expect(runAction).toHaveBeenCalledWith(
      "prepare-community-a",
      "begin_democratic_preparation",
      { target_community_id: community.id, requested_seats: 3 },
      expect.stringContaining("reversible"),
    );
  });

  it("does not show owner controls to a managed member", () => {
    setup(base);
    expect(
      screen.queryByRole("button", { name: "Start democratic preparation" }),
    ).not.toBeInTheDocument();
    expect(screen.getByText("Member")).toBeInTheDocument();
  });

  it("identifies the owner and appointed administrators", () => {
    setup(
      {
        ...base,
        is_owner: true,
        appointed_admins: [{ id: "member-a", label: "admin@example.test" }],
      },
      "owner-a",
    );
    expect(screen.getByText("owner@example.test — you")).toBeInTheDocument();
    expect(screen.getByText("admin@example.test")).toBeInTheDocument();
  });

  it.each([0, 1, 2])(
    "blocks founding commitment with %i candidates",
    (count) => {
      setup(
        {
          ...base,
          governance_state: "democratic_preparation",
          is_owner: true,
          council_target: 3,
          cycle_id: "cycle-a",
          cycle_status: "candidacy",
          candidates: Array.from({ length: count }, (_, index) => ({
            id: `candidate-${index}`,
            label: `candidate-${index}@example.test`,
          })),
          commit_blocker: "candidate_minimum",
        },
        "owner-a",
      );
      expect(
        screen.getByRole("button", { name: /Launch election/ }),
      ).toBeDisabled();
      expect(screen.getByText(/At least 3 candidates/)).toHaveAttribute(
        "role",
        "status",
      );
    },
  );

  it("opens an explicit irreversible confirmation with three candidates", () => {
    setup(
      {
        ...base,
        governance_state: "democratic_preparation",
        is_owner: true,
        council_target: 5,
        cycle_id: "cycle-a",
        cycle_status: "candidacy",
        candidates: [
          { id: "a", label: "alex@example.test" },
          { id: "b", label: "blair@example.test" },
          { id: "c", label: "casey@example.test" },
        ],
        may_commit_founding_transfer: true,
      },
      "owner-a",
    );
    fireEvent.click(screen.getByRole("button", { name: /Launch election/ }));
    const dialog = screen.getByRole("alertdialog");
    expect(dialog).toHaveTextContent(
      "cannot be returned to managed administration",
    );
    expect(
      within(dialog).getByRole("button", { name: "Keep current governance" }),
    ).toHaveFocus();
  });

  it("keeps commitment disabled when three candidates exist but the electorate minimum is missing", () => {
    setup(
      {
        ...base,
        governance_state: "democratic_preparation",
        is_owner: true,
        council_target: 3,
        cycle_id: "cycle-a",
        cycle_status: "candidacy",
        candidates: [
          { id: "a", label: "alex@example.test" },
          { id: "b", label: "blair@example.test" },
          { id: "c", label: "casey@example.test" },
        ],
        commit_blocker: "electorate_minimum",
      },
      "owner-a",
    );
    expect(
      screen.getByRole("button", { name: /Launch election/ }),
    ).toBeDisabled();
    expect(screen.getByText(/At least 5 active members/)).toHaveAttribute(
      "role",
      "status",
    );
  });

  it("shows independent stand and withdraw candidacy states", () => {
    const candidacy = {
      ...base,
      governance_state: "democratic_preparation" as const,
      council_target: 3 as const,
      cycle_id: "cycle-a",
      cycle_status: "candidacy" as const,
    };
    const { unmount } = render(
      <GovernanceSection
        communities={[
          { ...community, governance_state: candidacy.governance_state },
        ]}
        memberships={memberships}
        snapshots={[candidacy]}
        currentUserId="member-a"
        pendingActions={[]}
        runAction={vi.fn().mockResolvedValue(undefined)}
      />,
    );
    expect(
      screen.getByRole("button", { name: "Stand as candidate" }),
    ).toBeInTheDocument();
    unmount();
    setup({
      ...candidacy,
      candidates: [{ id: "member-a", label: "member@example.test" }],
      current_user_is_candidate: true,
    });
    expect(
      screen.getByRole("button", { name: "Withdraw candidacy" }),
    ).toBeInTheDocument();
  });

  it("uses labelled approval checkboxes and prevents over-selection", () => {
    setup({
      ...base,
      governance_state: "democratic_transition",
      council_target: 3,
      cycle_id: "cycle-a",
      cycle_status: "voting",
      candidates: [
        { id: "a", label: "alex@example.test" },
        { id: "b", label: "blair@example.test" },
        { id: "c", label: "casey@example.test" },
      ],
      may_commit_founding_transfer: true,
      round_id: "round-a",
      round_number: 1,
      round_status: "voting",
      seats_available: 2,
      current_user_may_vote: true,
    });
    const first = screen.getByLabelText("Approve alex@example.test");
    const second = screen.getByLabelText("Approve blair@example.test");
    const third = screen.getByLabelText("Approve casey@example.test");
    fireEvent.click(first);
    fireEvent.click(second);
    expect(third).toBeDisabled();
    expect(
      screen.getByText("Choose up to 2 candidates.", { exact: false }),
    ).toBeInTheDocument();
  });

  it("confirms a recorded ballot without redisplaying choices", () => {
    setup({
      ...base,
      governance_state: "democratic_transition",
      cycle_id: "cycle-a",
      cycle_status: "voting",
      candidates: [
        { id: "a", label: "alex@example.test" },
        { id: "b", label: "blair@example.test" },
      ],
      round_id: "round-a",
      round_number: 1,
      round_status: "voting",
      seats_available: 2,
      current_user_may_vote: true,
      current_user_ballot_recorded: true,
    });
    expect(screen.getByRole("status")).toHaveTextContent(
      "Your ballot was recorded.",
    );
    expect(screen.queryByText(/You voted for/)).not.toBeInTheDocument();
  });

  it("uses the seats being filled as the reconstitution approval limit", () => {
    setup({
      ...base,
      governance_state: "democratic",
      council_target: 5,
      cycle_id: "cycle-a",
      cycle_status: "voting",
      candidates: [
        { id: "a", label: "alex@example.test" },
        { id: "b", label: "blair@example.test" },
        { id: "c", label: "casey@example.test" },
      ],
      round_id: "round-a",
      round_number: 1,
      round_status: "voting",
      seats_available: 2,
      current_user_may_vote: true,
      active_mandates: 3,
      vacant_seats: 2,
      operational_status: "operational",
      council_took_office_at: "2026-01-01T00:00:00Z",
      council_term_ends_at: "2027-01-01T00:00:00Z",
      latest_election_status: "completed",
      latest_round_status: "completed",
      latest_ballot_count: 4,
      latest_electorate_count: 5,
      latest_quorum_threshold: 3,
    });
    expect(
      screen.getByText("Choose up to 2 candidates.", { exact: false }),
    ).toBeInTheDocument();
  });

  it("shows an operational elected council and its vacancies", () => {
    setup({
      ...base,
      governance_state: "democratic",
      council_target: 5,
      active_mandates: 3,
      elected_members: [
        { id: "member-a", label: "alex@example.test" },
        { id: "member-b", label: "blair@example.test" },
        { id: "member-c", label: "casey@example.test" },
      ],
      council_took_office_at: "2026-01-01T00:00:00Z",
      council_term_ends_at: "2027-01-01T00:00:00Z",
      vacant_seats: 2,
      operational_status: "operational",
      latest_election_status: "completed",
      latest_round_status: "completed",
      latest_ballot_count: 4,
      latest_electorate_count: 5,
      latest_quorum_threshold: 3,
    });
    expect(
      screen.getByRole("heading", { name: "Elected community council" }),
    ).toBeInTheDocument();
    expect(screen.getByText("2", { selector: "dd" })).toBeInTheDocument();
    expect(screen.getByText("alex@example.test — you")).toBeInTheDocument();
    expect(screen.getByText(/4 of 5 eligible members/)).toBeInTheDocument();
  });

  it("offers only a self-resignation with explicit consequences", () => {
    setup({
      ...base,
      governance_state: "democratic",
      council_target: 3,
      active_mandates: 3,
      vacant_seats: 0,
      operational_status: "operational",
      council_took_office_at: "2026-01-01T00:00:00Z",
      council_term_ends_at: "2027-01-01T00:00:00Z",
      current_user_has_mandate: true,
      may_resign: true,
    });
    fireEvent.click(
      screen.getByRole("button", { name: "Resign from council" }),
    );
    expect(screen.getByRole("alertdialog")).toHaveTextContent(
      "your seat becomes vacant",
    );
    expect(screen.queryByText(/resign member/i)).not.toBeInTheDocument();
  });

  it("keeps under-strength and vacant councils democratic with a member reconstitution path", () => {
    const under = {
      ...base,
      governance_state: "democratic" as const,
      council_target: 5 as const,
      active_mandates: 2,
      vacant_seats: 3,
      operational_status: "under_strength" as const,
      council_took_office_at: "2026-01-01T00:00:00Z",
      council_term_ends_at: "2027-01-01T00:00:00Z",
    };
    const { unmount } = render(
      <GovernanceSection
        communities={[{ ...community, governance_state: "democratic" }]}
        memberships={memberships}
        snapshots={[under]}
        currentUserId="member-a"
        pendingActions={[]}
        runAction={vi.fn().mockResolvedValue(undefined)}
      />,
    );
    expect(
      screen.getByText(/Council under-strength/).closest("p"),
    ).toHaveTextContent("temporary democratic caretakers");
    expect(
      screen.getByRole("button", { name: "Open council reconstitution" }),
    ).toBeInTheDocument();
    unmount();
    setup({
      ...under,
      active_mandates: 0,
      vacant_seats: 5,
      operational_status: "vacant",
    });
    expect(screen.getByText(/Council vacant/).closest("p")).toHaveTextContent(
      "Governance remains democratic",
    );
    expect(
      screen.queryByText("Managed administration"),
    ).not.toBeInTheDocument();
  });

  it("explains failed quorum without a false return to managed mode", () => {
    setup({
      ...base,
      governance_state: "democratic_transition",
      cycle_id: "cycle-a",
      cycle_status: "failed",
      round_id: "round-a",
      round_number: 1,
      round_status: "failed_quorum",
      seats_available: 3,
    });
    expect(
      screen.getByText(/quorum was not reached/).closest("p"),
    ).toHaveTextContent("managed administration is not restored");
  });

  it("explains insufficient winners without restoring managed governance", () => {
    setup({
      ...base,
      governance_state: "democratic_transition",
      cycle_id: "cycle-a",
      cycle_status: "failed",
      round_id: "round-a",
      round_number: 1,
      round_status: "insufficient_winners",
      seats_available: 3,
    });
    expect(
      screen.getByText(/No valid founding council/).closest("p"),
    ).toHaveTextContent("transition remains committed");
  });

  it("identifies a runoff and forbids random resolution", () => {
    setup({
      ...base,
      governance_state: "democratic_transition",
      cycle_id: "cycle-a",
      cycle_status: "voting",
      candidates: [
        { id: "a", label: "alex@example.test" },
        { id: "b", label: "blair@example.test" },
      ],
      round_id: "round-b",
      round_number: 2,
      round_status: "voting",
      seats_available: 1,
      current_user_may_vote: true,
    });
    expect(screen.getByText(/Runoff required/).closest("p")).toHaveTextContent(
      "No winner is selected at random",
    );
  });
});
