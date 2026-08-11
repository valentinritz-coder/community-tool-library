import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { CommunityPage } from "./community-page";

const unsubscribe = vi.fn();
vi.mock("../infrastructure/supabase-browser", () => ({
  getSupabaseBrowserClient: () => ({
    auth: {
      getSession: vi.fn().mockResolvedValue({ data: { session: null } }),
      onAuthStateChange: vi.fn(() => ({
        data: { subscription: { unsubscribe } },
      })),
    },
  }),
}));

describe("CommunityPage", () => {
  beforeEach(() => unsubscribe.mockClear());

  it("provides labelled authentication controls", async () => {
    render(<CommunityPage />);
    expect(
      screen.getByRole("heading", { level: 1, name: "Your community" }),
    ).toBeInTheDocument();
    expect(screen.getByLabelText("Email address")).toHaveAttribute(
      "type",
      "email",
    );
    expect(screen.getByLabelText("Password")).toHaveAttribute(
      "type",
      "password",
    );
    expect(screen.getByRole("button", { name: "Sign in" })).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Create account" }),
    ).toBeInTheDocument();
  });

  it("provides a keyboard-accessible skip link and live feedback region", () => {
    render(<CommunityPage />);
    expect(
      screen.getByRole("link", { name: "Skip to main content" }),
    ).toHaveAttribute("href", "#main");
    expect(screen.getByRole("main")).toHaveAttribute("id", "main");
    expect(screen.getByRole("status")).toHaveAttribute("aria-live", "polite");
  });
});
