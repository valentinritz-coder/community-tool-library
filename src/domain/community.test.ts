import { describe, expect, it } from "vitest";

import { canApproveMembership, type Membership } from "./community";

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
