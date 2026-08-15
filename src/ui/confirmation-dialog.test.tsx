import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { ConfirmationDialog } from "./confirmation-dialog";

describe("ConfirmationDialog", () => {
  it("keeps focus inside the dialog while a mutation is pending", () => {
    const { rerender } = render(
      <ConfirmationDialog
        title="Commit?"
        description="Irreversible"
        confirmLabel="Commit"
        cancelLabel="Keep current governance"
        onConfirm={vi.fn()}
        onCancel={vi.fn()}
      />,
    );
    expect(
      screen.getByRole("button", { name: "Keep current governance" }),
    ).toHaveFocus();
    rerender(
      <ConfirmationDialog
        title="Commit?"
        description="Irreversible"
        confirmLabel="Commit"
        cancelLabel="Keep current governance"
        pending
        onConfirm={vi.fn()}
        onCancel={vi.fn()}
      />,
    );
    const dialog = screen.getByRole("alertdialog");
    expect(dialog).toHaveFocus();
    expect(dialog).toHaveAttribute("aria-busy", "true");
    expect(screen.getByRole("status")).toHaveTextContent(
      "Action in progress. Dialog controls are temporarily unavailable.",
    );
    fireEvent.keyDown(dialog, { key: "Tab" });
    expect(dialog).toHaveFocus();
  });
});
