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
  appointed_admin_count: 0,
  council_target: null,
  cycle_id: null,
  cycle_status: null,
  candidate_ids: [],
  current_user_is_candidate: false,
  round_id: null,
  round_number: null,
  round_status: null,
  seats_available: null,
  current_user_may_vote: false,
  current_user_ballot_recorded: false,
  active_mandates: null,
  elected_member_ids: [],
  vacant_seats: null,
  operational_status: null,
  current_user_has_mandate: false,
  may_resign: false,
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
          candidate_ids: Array.from(
            { length: count },
            (_, index) => `candidate-${index}`,
          ),
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
        candidate_ids: ["a", "b", "c"],
      },
      "owner-a",
    );
    fireEvent.click(screen.getByRole("button", { name: /Launch election/ }));
    const dialog = screen.getByRole("alertdialog");
    expect(dialog).toHaveTextContent(
      "cannot be returned to managed administration",
    );
    expect(
      within(dialog).getByRole("button", {
        name: "Launch election and commit transfer",
      }),
    ).toHaveFocus();
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
      candidate_ids: ["member-a"],
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
      candidate_ids: ["a", "b", "c"],
      round_id: "round-a",
      round_number: 1,
      round_status: "voting",
      seats_available: 2,
      current_user_may_vote: true,
    });
    const first = screen.getByLabelText("Approve Candidate 1");
    const second = screen.getByLabelText("Approve Candidate 2");
    const third = screen.getByLabelText("Approve Candidate 3");
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
      candidate_ids: ["a", "b"],
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

  it("shows an operational elected council and its vacancies", () => {
    setup({
      ...base,
      governance_state: "democratic",
      council_target: 5,
      active_mandates: 3,
      elected_member_ids: ["member-a", "member-b", "member-c"],
      vacant_seats: 2,
      operational_status: "operational",
    });
    expect(
      screen.getByRole("heading", { name: "Elected community council" }),
    ).toBeInTheDocument();
    expect(screen.getByText("2", { selector: "dd" })).toBeInTheDocument();
    expect(screen.getByText("Council member 1 — you")).toBeInTheDocument();
  });

  it("offers only a self-resignation with explicit consequences", () => {
    setup({
      ...base,
      governance_state: "democratic",
      council_target: 3,
      active_mandates: 3,
      vacant_seats: 0,
      operational_status: "operational",
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

  it("identifies a runoff and forbids random resolution", () => {
    setup({
      ...base,
      governance_state: "democratic_transition",
      cycle_id: "cycle-a",
      cycle_status: "voting",
      candidate_ids: ["a", "b"],
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
