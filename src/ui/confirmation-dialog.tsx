"use client";

import { useEffect, useRef } from "react";

interface ConfirmationDialogProps {
  title: string;
  description: string;
  confirmLabel: string;
  cancelLabel: string;
  pending?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

export function ConfirmationDialog({
  title,
  description,
  confirmLabel,
  cancelLabel,
  pending = false,
  onConfirm,
  onCancel,
}: ConfirmationDialogProps) {
  const cancelRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const previouslyFocused = document.activeElement as HTMLElement | null;
    cancelRef.current?.focus();
    return () => previouslyFocused?.focus();
  }, []);

  useEffect(() => {
    if (pending) dialogRef.current?.focus();
  }, [pending]);

  return (
    <div
      className="dialog-backdrop"
      role="presentation"
      onKeyDown={(event) => {
        if (event.key === "Escape" && !pending) onCancel();
        if (event.key === "Tab") {
          const controls = dialogRef.current?.querySelectorAll<HTMLElement>(
            "button:not(:disabled)",
          );
          if (!controls?.length) {
            event.preventDefault();
            dialogRef.current?.focus();
            return;
          }
          const first = controls[0];
          const last = controls[controls.length - 1];
          if (event.shiftKey && document.activeElement === first) {
            event.preventDefault();
            last.focus();
          } else if (!event.shiftKey && document.activeElement === last) {
            event.preventDefault();
            first.focus();
          }
        }
      }}
    >
      <div
        ref={dialogRef}
        tabIndex={-1}
        className="confirmation-dialog"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="confirmation-title"
        aria-describedby="confirmation-description"
      >
        <h2 id="confirmation-title">{title}</h2>
        <p id="confirmation-description">{description}</p>
        <div className="actions">
          <button disabled={pending} onClick={onConfirm}>
            {confirmLabel}
          </button>
          <button
            ref={cancelRef}
            className="secondary"
            disabled={pending}
            onClick={onCancel}
          >
            {cancelLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
