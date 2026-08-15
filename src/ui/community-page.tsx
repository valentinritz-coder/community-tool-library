"use client";

import type { FormEvent } from "react";
import { useEffect, useRef, useState } from "react";

import { type Community, type Membership } from "../domain/community";
import {
  parseGovernanceSnapshot,
  type GovernanceSnapshot,
} from "../domain/governance";
import { getSupabaseBrowserClient } from "../infrastructure/supabase-browser";
import { ItemSection } from "./item-section";
import { GovernanceSection } from "./governance-section";

interface CommunityState {
  communities: Community[];
  memberships: Membership[];
  governance: GovernanceSnapshot[];
}

const emptyState: CommunityState = {
  communities: [],
  memberships: [],
  governance: [],
};

function errorMessage(error: unknown): string {
  return error instanceof Error
    ? error.message
    : "Something went wrong. Please try again.";
}

export function CommunityPage() {
  const [authenticated, setAuthenticated] = useState(false);
  const [currentUserId, setCurrentUserId] = useState("");
  const [state, setState] = useState<CommunityState>(emptyState);
  const [message, setMessage] = useState("");
  const [messageIsError, setMessageIsError] = useState(false);
  const [pendingActions, setPendingActions] = useState<string[]>([]);
  const [showPasswordResetRequest, setShowPasswordResetRequest] =
    useState(false);
  const pendingActionsRef = useRef(new Set<string>());

  function beginAction(action: string): boolean {
    if (pendingActionsRef.current.has(action)) return false;
    pendingActionsRef.current.add(action);
    setPendingActions([...pendingActionsRef.current]);
    return true;
  }

  function endAction(action: string) {
    pendingActionsRef.current.delete(action);
    setPendingActions([...pendingActionsRef.current]);
  }

  function isPending(action: string): boolean {
    return pendingActions.includes(action);
  }

  function announce(nextMessage: string, isError = false) {
    setMessage(nextMessage);
    setMessageIsError(isError);
  }

  async function refresh() {
    const supabase = getSupabaseBrowserClient();
    const [communities, memberships] = await Promise.all([
      supabase
        .from("communities")
        .select(
          "id,name,join_code,owner_id,governance_state,council_target_size,active_election_cycle_id",
        )
        .order("name"),
      supabase.from("memberships").select("community_id,user_id,role,status"),
    ]);
    if (communities.error) throw communities.error;
    if (memberships.error) throw memberships.error;
    const communityRows = communities.data as Community[];
    const governance = await Promise.all(
      communityRows.map(async (community) => {
        const result = await supabase.rpc("get_community_governance_ui", {
          target_community_id: community.id,
        });
        if (result.error) throw result.error;
        const row: unknown = Array.isArray(result.data)
          ? result.data[0]
          : result.data;
        return parseGovernanceSnapshot(row);
      }),
    );
    setState({
      communities: communityRows,
      memberships: memberships.data as Membership[],
      governance,
    });
  }

  useEffect(() => {
    async function initialize() {
      try {
        const supabase = getSupabaseBrowserClient();
        const { data } = await supabase.auth.getSession();
        const signedIn = Boolean(data.session);
        setAuthenticated(signedIn);
        setCurrentUserId(data.session?.user.id ?? "");
        if (signedIn) await refresh();
      } catch (error) {
        announce(errorMessage(error), true);
      }
    }

    void initialize();
    const supabase = getSupabaseBrowserClient();
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      setAuthenticated(Boolean(session));
      setCurrentUserId(session?.user.id ?? "");
    });
    return () => data.subscription.unsubscribe();
  }, []);

  async function authenticate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    announce("");
    if (!beginAction("authenticate")) return;
    const form = new FormData(event.currentTarget);
    const email = String(form.get("email") ?? "").trim();
    const password = String(form.get("password") ?? "");
    try {
      const { error } =
        await getSupabaseBrowserClient().auth.signInWithPassword({
          email,
          password,
        });
      if (error) throw error;
      setAuthenticated(true);
      const { data } = await getSupabaseBrowserClient().auth.getUser();
      setCurrentUserId(data.user?.id ?? "");
      await refresh();
      announce("Signed in successfully.");
    } catch (error) {
      announce(errorMessage(error), true);
    } finally {
      endAction("authenticate");
    }
  }

  async function createAccount() {
    const form = document.querySelector<HTMLFormElement>("#sign-in-form");
    if (!form?.reportValidity()) return;
    const data = new FormData(form);
    if (!beginAction("authenticate")) return;
    try {
      const { error } = await getSupabaseBrowserClient().auth.signUp({
        email: String(data.get("email") ?? "").trim(),
        password: String(data.get("password") ?? ""),
      });
      if (error) throw error;
      announce(
        "Account created. Check your email if confirmation is required, then sign in.",
      );
    } catch (error) {
      announce(errorMessage(error), true);
    } finally {
      endAction("authenticate");
    }
  }

  async function requestPasswordReset(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    announce("");
    if (!beginAction("request-password-reset")) return;
    const email = String(
      new FormData(event.currentTarget).get("reset-email") ?? "",
    ).trim();
    try {
      const redirectTo = new URL("/reset-password", window.location.origin);
      await getSupabaseBrowserClient().auth.resetPasswordForEmail(email, {
        redirectTo: redirectTo.toString(),
      });
      announce(
        "If an account exists for that email, a password reset link has been sent.",
      );
    } catch {
      // Recovery failures can depend on account state (for example, rate limits).
      // Keep the public response indistinguishable and do not log sensitive details.
      announce(
        "If an account exists for that email, a password reset link has been sent.",
      );
    } finally {
      endAction("request-password-reset");
    }
  }

  async function runRpc(
    action: string,
    functionName: string,
    parameters: Record<string, string | boolean | number | string[]>,
    success: string,
  ) {
    announce("");
    if (!beginAction(action)) return;
    announce("Working…");
    try {
      const { error } = await getSupabaseBrowserClient().rpc(
        functionName,
        parameters,
      );
      if (error) throw error;
      await refresh();
      announce(success);
    } catch (error) {
      announce(errorMessage(error), true);
    } finally {
      endAction(action);
    }
  }

  return (
    <div className="page">
      <a className="skip-link" href="#main">
        Skip to main content
      </a>
      <header className="header">
        <span className="brand">
          <span className="brand-mark" aria-hidden="true">
            CT
          </span>
          Community Tool Library
        </span>
      </header>
      <main id="main" className="community-main">
        <div>
          <p className="eyebrow">Share locally. Use more. Own less.</p>
          <h1>Your community</h1>
          <p className="intro">
            Create a private community or request access with a join code.
          </p>
        </div>
        <p
          id="community-message"
          className="notice"
          role={messageIsError ? "alert" : "status"}
          aria-live={messageIsError ? "assertive" : "polite"}
        >
          {message}
        </p>
        {!authenticated && showPasswordResetRequest ? (
          <section className="card" aria-labelledby="reset-request-title">
            <h2 id="reset-request-title">Reset your password</h2>
            <p>Enter your email address to receive a password reset link.</p>
            <form
              onSubmit={requestPasswordReset}
              aria-describedby={
                messageIsError ? "community-message" : undefined
              }
              aria-busy={isPending("request-password-reset")}
            >
              <label htmlFor="reset-email">Email address</label>
              <input
                id="reset-email"
                name="reset-email"
                type="email"
                autoComplete="email"
                required
                autoFocus
              />
              <div className="actions">
                <button
                  type="submit"
                  disabled={isPending("request-password-reset")}
                >
                  Send reset link
                </button>
                <button
                  type="button"
                  className="secondary"
                  disabled={isPending("request-password-reset")}
                  onClick={() => {
                    announce("");
                    setShowPasswordResetRequest(false);
                  }}
                >
                  Back to sign in
                </button>
              </div>
            </form>
          </section>
        ) : !authenticated ? (
          <section className="card" aria-labelledby="sign-in-title">
            <h2 id="sign-in-title">Sign in</h2>
            <form
              id="sign-in-form"
              onSubmit={authenticate}
              aria-describedby={
                messageIsError ? "community-message" : undefined
              }
              aria-busy={isPending("authenticate")}
            >
              <label htmlFor="email">Email address</label>
              <input
                id="email"
                name="email"
                type="email"
                autoComplete="email"
                required
              />
              <label htmlFor="password">Password</label>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                minLength={6}
                required
              />
              <div className="actions">
                <button type="submit" disabled={isPending("authenticate")}>
                  Sign in
                </button>
                <button
                  type="button"
                  className="secondary"
                  disabled={isPending("authenticate")}
                  onClick={() => void createAccount()}
                >
                  Create account
                </button>
              </div>
              <button
                type="button"
                className="text-button"
                disabled={isPending("authenticate")}
                onClick={() => {
                  announce("");
                  setShowPasswordResetRequest(true);
                }}
              >
                Forgot password?
              </button>
            </form>
          </section>
        ) : (
          <div className="flow-grid">
            <section className="card" aria-labelledby="create-title">
              <h2 id="create-title">Create a community</h2>
              <form
                aria-busy={isPending("create-community")}
                onSubmit={(event) => {
                  event.preventDefault();
                  const name = String(
                    new FormData(event.currentTarget).get("name") ?? "",
                  );
                  void runRpc(
                    "create-community",
                    "create_community",
                    { community_name: name },
                    "Community created. You are its community owner.",
                  );
                }}
              >
                <label htmlFor="community-name">Community name</label>
                <input
                  id="community-name"
                  name="name"
                  minLength={2}
                  maxLength={80}
                  required
                />
                <button type="submit" disabled={isPending("create-community")}>
                  Create community
                </button>
              </form>
            </section>
            <section className="card" aria-labelledby="join-title">
              <h2 id="join-title">Request to join</h2>
              <p>
                The community owner or an appointed administrator must approve
                your request.
              </p>
              <form
                aria-busy={isPending("join-community")}
                onSubmit={(event) => {
                  event.preventDefault();
                  const code = String(
                    new FormData(event.currentTarget).get("code") ?? "",
                  );
                  void runRpc(
                    "join-community",
                    "request_to_join_community",
                    { requested_join_code: code },
                    "Request sent. The community owner or an appointed administrator must approve it.",
                  );
                }}
              >
                <label htmlFor="join-code">Community join code</label>
                <input id="join-code" name="code" inputMode="text" required />
                <button type="submit" disabled={isPending("join-community")}>
                  Request to join
                </button>
              </form>
            </section>
            <section className="card wide" aria-labelledby="communities-title">
              <h2 id="communities-title">Your active communities</h2>
              {state.communities.length === 0 ? (
                <p>No active communities yet.</p>
              ) : (
                <ul>
                  {state.communities.map((community) => (
                    <li key={community.id}>
                      <strong>{community.name}</strong>
                      <span>
                        Join code: <code>{community.join_code}</code>
                      </span>
                      <span>Governance details are available below.</span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
            <section className="card wide" aria-labelledby="requests-title">
              <h2 id="requests-title">Memberships and requests</h2>
              {state.memberships.length === 0 ? (
                <p>No memberships yet.</p>
              ) : (
                <ul>
                  {state.memberships.map((membership) => (
                    <li
                      key={`${membership.community_id}-${membership.user_id}`}
                    >
                      <span>
                        {membership.role} — {membership.status}
                      </span>
                      {state.communities.map((community) =>
                        membership.community_id === community.id &&
                        membership.status === "active" &&
                        state.governance.find(
                          (snapshot) => snapshot.community_id === community.id,
                        )?.may_manage_appointed_admins ? (
                          <button
                            key={community.id}
                            type="button"
                            disabled={isPending(
                              `admin-${membership.community_id}-${membership.user_id}`,
                            )}
                            onClick={() =>
                              void runRpc(
                                `admin-${membership.community_id}-${membership.user_id}`,
                                "set_appointed_administrator",
                                {
                                  target_community_id: membership.community_id,
                                  target_user_id: membership.user_id,
                                  appointed: membership.role !== "admin",
                                },
                                membership.role === "admin"
                                  ? "Appointed administrator removed."
                                  : "Appointed administrator added.",
                              )
                            }
                          >
                            {membership.role === "admin"
                              ? `Remove administrator ${membership.user_id}`
                              : `Appoint administrator ${membership.user_id}`}
                          </button>
                        ) : null,
                      )}
                      {membership.status === "pending" &&
                        membership.user_id !== currentUserId &&
                        state.governance.find(
                          (snapshot) =>
                            snapshot.community_id === membership.community_id,
                        )?.may_approve_memberships && (
                          <button
                            type="button"
                            disabled={isPending(
                              `approve-${membership.community_id}-${membership.user_id}`,
                            )}
                            onClick={() =>
                              void runRpc(
                                `approve-${membership.community_id}-${membership.user_id}`,
                                "approve_membership",
                                {
                                  target_community_id: membership.community_id,
                                  target_user_id: membership.user_id,
                                },
                                "Membership approved.",
                              )
                            }
                          >
                            Approve membership
                          </button>
                        )}
                    </li>
                  ))}
                </ul>
              )}
            </section>
            <GovernanceSection
              communities={state.communities}
              memberships={state.memberships}
              snapshots={state.governance}
              currentUserId={currentUserId}
              pendingActions={pendingActions}
              runAction={runRpc}
            />
            <ItemSection
              communities={state.communities}
              currentUserId={currentUserId}
              moderationCommunityIds={state.governance
                .filter((snapshot) => snapshot.may_moderate_community)
                .map((snapshot) => snapshot.community_id)}
            />
            <button
              type="button"
              className="secondary sign-out"
              onClick={() =>
                void getSupabaseBrowserClient()
                  .auth.signOut()
                  .then(() => {
                    setAuthenticated(false);
                    setCurrentUserId("");
                    setState(emptyState);
                  })
              }
            >
              Sign out
            </button>
          </div>
        )}
      </main>
    </div>
  );
}
