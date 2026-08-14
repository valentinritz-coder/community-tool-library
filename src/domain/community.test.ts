import { describe, expect, it } from "vitest";

import {
  canApproveMembership,
  canManageAppointedAdministrator,
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
    expect(canApproveMembership(pendingMember, "admin", [admin])).toBe(true);
    expect(
      canApproveMembership(pendingMember, "requester", [pendingMember]),
    ).toBe(false);
    expect(
      canApproveMembership(pendingMember, "member", [
        { ...admin, user_id: "member", role: "member" },
      ]),
    ).toBe(false);
    expect(
      canApproveMembership(pendingMember, "other-admin", [
        { ...admin, community_id: "community-b", user_id: "other-admin" },
      ]),
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
});
