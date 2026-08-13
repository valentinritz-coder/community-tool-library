"use client";

import type { FormEvent } from "react";
import { useEffect, useState } from "react";
import Link from "next/link";

import { getSupabaseBrowserClient } from "../infrastructure/supabase-browser";

const MINIMUM_PASSWORD_LENGTH = 6;

function safeErrorMessage(error: unknown): string {
  return error instanceof Error
    ? error.message
    : "The password could not be changed. Please request a new link and try again.";
}

export function PasswordResetPage() {
  const [recoveryReady, setRecoveryReady] = useState(false);
  const [checkingLink, setCheckingLink] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [complete, setComplete] = useState(false);
  const [message, setMessage] = useState("");
  const [messageIsError, setMessageIsError] = useState(false);

  useEffect(() => {
    const url = new URL(window.location.href);
    const hash = new URLSearchParams(url.hash.replace(/^#/, ""));
    if (url.searchParams.has("error") || hash.has("error")) {
      queueMicrotask(() => {
        setMessage(
          "This password reset link is invalid or has expired. Request a new link to try again.",
        );
        setMessageIsError(true);
        setCheckingLink(false);
      });
    }

    const supabase = getSupabaseBrowserClient();
    const { data } = supabase.auth.onAuthStateChange((event) => {
      if (event === "PASSWORD_RECOVERY") {
        setRecoveryReady(true);
        setMessage("");
        setMessageIsError(false);
      }
      if (event === "PASSWORD_RECOVERY" || event === "INITIAL_SESSION") {
        setCheckingLink(false);
      }
    });
    return () => data.subscription.unsubscribe();
  }, []);

  async function updatePassword(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (submitting) return;
    const form = new FormData(event.currentTarget);
    const password = String(form.get("new-password") ?? "");
    const confirmation = String(form.get("confirm-password") ?? "");
    if (password.length < MINIMUM_PASSWORD_LENGTH) {
      setMessage(
        `Password must be at least ${MINIMUM_PASSWORD_LENGTH} characters.`,
      );
      setMessageIsError(true);
      return;
    }
    if (password !== confirmation) {
      setMessage("The passwords do not match.");
      setMessageIsError(true);
      return;
    }

    setSubmitting(true);
    setMessage("");
    try {
      const { error } = await getSupabaseBrowserClient().auth.updateUser({
        password,
      });
      if (error) throw error;
      await getSupabaseBrowserClient().auth.signOut();
      setComplete(true);
      setRecoveryReady(false);
      setMessage("Your password has been changed. You can now sign in.");
      setMessageIsError(false);
    } catch (error) {
      setMessage(safeErrorMessage(error));
      setMessageIsError(true);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="page">
      <a className="skip-link" href="#main">
        Skip to main content
      </a>
      <header className="header">
        <span className="brand">Community Tool Library</span>
      </header>
      <main id="main" className="community-main reset-main">
        <div>
          <p className="eyebrow">Account recovery</p>
          <h1>Choose a new password</h1>
        </div>
        <p
          id="reset-message"
          className="notice"
          role={messageIsError ? "alert" : "status"}
          aria-live={messageIsError ? "assertive" : "polite"}
        >
          {message}
        </p>
        {checkingLink ? (
          <p role="status">Checking your password reset link…</p>
        ) : recoveryReady ? (
          <section className="card" aria-labelledby="new-password-title">
            <h2 id="new-password-title">Set your new password</h2>
            <p>Use at least {MINIMUM_PASSWORD_LENGTH} characters.</p>
            <form
              onSubmit={updatePassword}
              aria-busy={submitting}
              aria-describedby="reset-message"
            >
              <label htmlFor="new-password">New password</label>
              <input
                id="new-password"
                name="new-password"
                type="password"
                autoComplete="new-password"
                minLength={MINIMUM_PASSWORD_LENGTH}
                required
                autoFocus
              />
              <label htmlFor="confirm-password">Confirm new password</label>
              <input
                id="confirm-password"
                name="confirm-password"
                type="password"
                autoComplete="new-password"
                minLength={MINIMUM_PASSWORD_LENGTH}
                required
              />
              <button type="submit" disabled={submitting}>
                Change password
              </button>
            </form>
          </section>
        ) : (
          <section className="card" aria-labelledby="link-error-title">
            <h2 id="link-error-title">
              {complete ? "Password changed" : "Reset link unavailable"}
            </h2>
            {!message && !complete ? (
              <p>
                This password reset link is invalid, expired, or already used.
              </p>
            ) : null}
            <Link className="button-link" href="/">
              {complete ? "Return to sign in" : "Request a new reset link"}
            </Link>
          </section>
        )}
      </main>
    </div>
  );
}
