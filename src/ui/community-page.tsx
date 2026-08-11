"use client";

import type { FormEvent } from "react";
import { useEffect, useState } from "react";

import {
  canApproveMembership,
  type Community,
  type Membership,
} from "../domain/community";
import { getSupabaseBrowserClient } from "../infrastructure/supabase-browser";

interface CommunityState {
  communities: Community[];
  memberships: Membership[];
}

const emptyState: CommunityState = { communities: [], memberships: [] };

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

  async function refresh() {
    const supabase = getSupabaseBrowserClient();
    const [communities, memberships] = await Promise.all([
      supabase.from("communities").select("id,name,join_code").order("name"),
      supabase.from("memberships").select("community_id,user_id,role,status"),
    ]);
    if (communities.error) throw communities.error;
    if (memberships.error) throw memberships.error;
    setState({
      communities: communities.data as Community[],
      memberships: memberships.data as Membership[],
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
        setMessage(errorMessage(error));
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
    setMessage("");
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
      setMessage("Signed in successfully.");
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function createAccount() {
    const form = document.querySelector<HTMLFormElement>("#sign-in-form");
    if (!form?.reportValidity()) return;
    const data = new FormData(form);
    try {
      const { error } = await getSupabaseBrowserClient().auth.signUp({
        email: String(data.get("email") ?? "").trim(),
        password: String(data.get("password") ?? ""),
      });
      if (error) throw error;
      setMessage(
        "Account created. Check your email if confirmation is required, then sign in.",
      );
    } catch (error) {
      setMessage(errorMessage(error));
    }
  }

  async function runRpc(
    functionName: string,
    parameters: Record<string, string>,
    success: string,
  ) {
    setMessage("");
    try {
      const { error } = await getSupabaseBrowserClient().rpc(
        functionName,
        parameters,
      );
      if (error) throw error;
      await refresh();
      setMessage(success);
    } catch (error) {
      setMessage(errorMessage(error));
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
        <p className="notice" role="status" aria-live="polite">
          {message}
        </p>
        {!authenticated ? (
          <section className="card" aria-labelledby="sign-in-title">
            <h2 id="sign-in-title">Sign in</h2>
            <form id="sign-in-form" onSubmit={authenticate}>
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
                <button type="submit">Sign in</button>
                <button
                  type="button"
                  className="secondary"
                  onClick={() => void createAccount()}
                >
                  Create account
                </button>
              </div>
            </form>
          </section>
        ) : (
          <div className="flow-grid">
            <section className="card" aria-labelledby="create-title">
              <h2 id="create-title">Create a community</h2>
              <form
                onSubmit={(event) => {
                  event.preventDefault();
                  const name = String(
                    new FormData(event.currentTarget).get("name") ?? "",
                  );
                  void runRpc(
                    "create_community",
                    { community_name: name },
                    "Community created. You are its admin.",
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
                <button type="submit">Create community</button>
              </form>
            </section>
            <section className="card" aria-labelledby="join-title">
              <h2 id="join-title">Request to join</h2>
              <p>An admin must approve your request.</p>
              <form
                onSubmit={(event) => {
                  event.preventDefault();
                  const code = String(
                    new FormData(event.currentTarget).get("code") ?? "",
                  );
                  void runRpc(
                    "request_to_join_community",
                    { requested_join_code: code },
                    "Request sent. An admin must approve it.",
                  );
                }}
              >
                <label htmlFor="join-code">Community join code</label>
                <input id="join-code" name="code" inputMode="text" required />
                <button type="submit">Request to join</button>
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
                      {canApproveMembership(
                        membership,
                        currentUserId,
                        state.memberships,
                      ) && (
                        <button
                          type="button"
                          onClick={() =>
                            void runRpc(
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
