import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { PasswordResetPage } from "./password-reset-page";

const updateUser = vi.fn();
const signOut = vi.fn();
const unsubscribe = vi.fn();
let authListener: ((event: string) => void) | undefined;

vi.mock("../infrastructure/supabase-browser", () => ({
  getSupabaseBrowserClient: () => ({
    auth: {
      updateUser,
      signOut,
      onAuthStateChange: vi.fn((listener: (event: string) => void) => {
        authListener = listener;
        return { data: { subscription: { unsubscribe } } };
      }),
    },
  }),
}));

describe("PasswordResetPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.history.replaceState({}, "", "/reset-password");
    updateUser.mockResolvedValue({ error: null });
    signOut.mockResolvedValue({ error: null });
  });

  function openRecoveryForm() {
    render(<PasswordResetPage />);
    authListener?.("PASSWORD_RECOVERY");
  }

  it("shows the labelled form only for a password recovery event", async () => {
    openRecoveryForm();
    expect(await screen.findByLabelText("New password")).toHaveAttribute(
      "autocomplete",
      "new-password",
    );
    expect(screen.getByLabelText("Confirm new password")).toBeInTheDocument();
  });

  it("keeps checking briefly when the initial session arrives before recovery", () => {
    render(<PasswordResetPage />);
    authListener?.("INITIAL_SESSION");
    expect(
      screen.getByText("Checking your password reset link…"),
    ).toBeInTheDocument();
    expect(
      screen.queryByText("Reset link unavailable"),
    ).not.toBeInTheDocument();
  });

  it("rejects mismatched confirmation without updating the user", async () => {
    openRecoveryForm();
    fireEvent.change(await screen.findByLabelText("New password"), {
      target: { value: "new-password" },
    });
    fireEvent.change(screen.getByLabelText("Confirm new password"), {
      target: { value: "different-password" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Change password" }));
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "The passwords do not match.",
    );
    expect(updateUser).not.toHaveBeenCalled();
  });

  it("enforces the same six-character minimum used for account creation", async () => {
    openRecoveryForm();
    const password = await screen.findByLabelText("New password");
    fireEvent.change(password, { target: { value: "short" } });
    fireEvent.change(screen.getByLabelText("Confirm new password"), {
      target: { value: "short" },
    });
    fireEvent.submit(password.closest("form")!);
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Password must be at least 6 characters.",
    );
    expect(updateUser).not.toHaveBeenCalled();
  });

  it("reports update failure and keeps the recovery form available", async () => {
    updateUser.mockResolvedValue({
      error: new Error("Password update failed."),
    });
    openRecoveryForm();
    fireEvent.change(await screen.findByLabelText("New password"), {
      target: { value: "new-password" },
    });
    fireEvent.change(screen.getByLabelText("Confirm new password"), {
      target: { value: "new-password" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Change password" }));
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Password update failed.",
    );
    expect(screen.getByLabelText("New password")).toBeInTheDocument();
  });

  it("updates the password, ends the recovery session, and returns to sign in", async () => {
    openRecoveryForm();
    fireEvent.change(await screen.findByLabelText("New password"), {
      target: { value: "new-password" },
    });
    fireEvent.change(screen.getByLabelText("Confirm new password"), {
      target: { value: "new-password" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Change password" }));

    await waitFor(() =>
      expect(updateUser).toHaveBeenCalledWith({ password: "new-password" }),
    );
    expect(signOut).toHaveBeenCalled();
    expect(screen.getByRole("status")).toHaveTextContent(
      "Your password has been changed. You can now sign in.",
    );
    expect(
      screen.getByRole("link", { name: "Return to sign in" }),
    ).toHaveAttribute("href", "/app");
  });

  it("reports session cleanup failure without claiming the password update failed", async () => {
    signOut.mockResolvedValue({ error: new Error("Sign out failed.") });
    openRecoveryForm();
    fireEvent.change(await screen.findByLabelText("New password"), {
      target: { value: "new-password" },
    });
    fireEvent.change(screen.getByLabelText("Confirm new password"), {
      target: { value: "new-password" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Change password" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Your password was changed, but we could not end the recovery session.",
    );
    expect(updateUser).toHaveBeenCalledTimes(1);
    expect(
      screen.queryByRole("link", { name: "Return to sign in" }),
    ).not.toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Try ending session again" }),
    ).toBeInTheDocument();
  });

  it("fails safely when Supabase reports an invalid or expired link", async () => {
    window.history.replaceState(
      {},
      "",
      "/reset-password?error=access_denied&error_description=sensitive",
    );
    render(<PasswordResetPage />);
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "This password reset link is invalid or has expired.",
    );
    expect(screen.queryByText("sensitive")).not.toBeInTheDocument();
  });
});
