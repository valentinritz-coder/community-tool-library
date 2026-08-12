import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { CommunityPage } from "./community-page";

const unsubscribe = vi.fn();
const getSession = vi.fn();
const signInWithPassword = vi.fn();
const rpc = vi.fn();
const communityQuery = {
  select: vi.fn(() => communityQuery),
  order: vi.fn().mockResolvedValue({ data: [], error: null }),
};
vi.mock("../infrastructure/supabase-browser", () => ({
  getSupabaseBrowserClient: () => ({
    from: vi.fn((table: string) =>
      table === "memberships"
        ? {
            select: vi.fn().mockResolvedValue({ data: [], error: null }),
          }
        : communityQuery,
    ),
    rpc,
    auth: {
      getSession,
      signInWithPassword,
      getUser: vi.fn().mockResolvedValue({ data: { user: null } }),
      onAuthStateChange: vi.fn(() => ({
        data: { subscription: { unsubscribe } },
      })),
    },
  }),
}));

describe("CommunityPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    getSession.mockResolvedValue({ data: { session: null } });
    signInWithPassword.mockResolvedValue({ error: null });
    rpc.mockResolvedValue({ error: null });
    communityQuery.order.mockResolvedValue({ data: [], error: null });
  });

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

  it("exposes an asynchronous authentication error as an alert", async () => {
    signInWithPassword.mockResolvedValue({
      error: new Error("Email or password is incorrect."),
    });
    render(<CommunityPage />);

    fireEvent.change(screen.getByLabelText("Email address"), {
      target: { value: "member@example.test" },
    });
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "synthetic-password" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Sign in" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Email or password is incorrect.",
    );
  });

  it("marks a community operation busy and prevents a duplicate request", async () => {
    getSession.mockResolvedValue({
      data: { session: { user: { id: "admin-a" } } },
    });
    let resolveRpc: ((value: { error: null }) => void) | undefined;
    rpc.mockImplementation(
      () =>
        new Promise<{ error: null }>((resolve) => {
          resolveRpc = resolve;
        }),
    );
    render(<CommunityPage />);
    const button = await screen.findByRole("button", {
      name: "Create community",
    });
    const form = button.closest("form");
    expect(form).not.toBeNull();
    fireEvent.change(screen.getByLabelText("Community name"), {
      target: { value: "Riverside" },
    });

    fireEvent.click(button);
    fireEvent.submit(form!);

    expect(button).toBeDisabled();
    expect(form).toHaveAttribute("aria-busy", "true");
    expect(rpc).toHaveBeenCalledTimes(1);
    resolveRpc?.({ error: null });
    await waitFor(() => expect(button).not.toBeDisabled());
  });
});
