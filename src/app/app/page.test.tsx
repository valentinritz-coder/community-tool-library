import { describe, expect, it } from "vitest";

import { CommunityPage } from "../../ui/community-page";

import ApplicationPage from "./page";

describe("ApplicationPage", () => {
  it("keeps the existing application available without duplicating it", () => {
    expect(ApplicationPage().type).toBe(CommunityPage);
  });
});
