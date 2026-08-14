import { describe, expect, it } from "vitest";

import {
  canApproveMembership,
  canManageAppointedAdministrator,
  hasManagedAdministrationAuthority,
  type Community,
  type Membership,
} from "./community";

const admin: Membership = {
  community_id: "community-a",
  user_id: "admin",
  role: "admin",
  status: "active",
};

const pendingMember: Membership = {
  community_id: "community-a",
  user_id: "requester",
  role: "member",
  status: "pending",
};

describe("canApproveMembership", () => {
  it("only offers approval to another active admin in the same community", () => {
    expect(
      canApproveMembership(pendingMember, "admin", [admin], [community]),
    ).toBe(true);
    expect(
      canApproveMembership(
        pendingMember,
        "requester",
        [pendingMember],
        [community],
      ),
    ).toBe(false);
    expect(
      canApproveMembership(
        pendingMember,
        "member",
        [{ ...admin, user_id: "member", role: "member" }],
        [community],
      ),
    ).toBe(false);
    expect(
      canApproveMembership(
        pendingMember,
        "other-admin",
        [{ ...admin, community_id: "community-b", user_id: "other-admin" }],
        [community],
      ),
    ).toBe(false);
  });
});

const community: Community = {
  id: "community-a",
  name: "Riverside",
  join_code: "synthetic-code",
  owner_id: "owner",
  governance_state: "managed",
};

describe("managed governance controls", () => {
  it("offers ordinary membership approval to the owner independently of admin role", () => {
    expect(canApproveMembership(pendingMember, "owner", [], [community])).toBe(
      true,
    );
  });

  it("only offers appointment controls to the owner for active members", () => {
    expect(
      canManageAppointedAdministrator(community, "owner", {
        ...pendingMember,
        status: "active",
      }),
    ).toBe(true);
    expect(canManageAppointedAdministrator(community, "admin", admin)).toBe(
      false,
    );
    expect(
      canManageAppointedAdministrator(community, "owner", pendingMember),
    ).toBe(false);
  });

  it("removes owner and appointed-admin managed authority after commitment", () => {
    for (const governance_state of [
      "democratic_transition",
      "democratic",
    ] as const) {
      const transitioned = { ...community, governance_state };
      expect(hasManagedAdministrationAuthority(transitioned, "owner", [])).toBe(
        false,
      );
      expect(
        hasManagedAdministrationAuthority(transitioned, "admin", [admin]),
      ).toBe(false);
      expect(
        canApproveMembership(pendingMember, "admin", [admin], [transitioned]),
      ).toBe(false);
    }
  });
});
