"use client";

import { useState } from "react";

import {
  canCommitFoundingTransfer,
  candidateLabel,
  type CouncilTarget,
  type GovernanceSnapshot,
} from "../domain/governance";
import type { Community, Membership } from "../domain/community";
import { ConfirmationDialog } from "./confirmation-dialog";

type GovernanceAction = (
  action: string,
  functionName: string,
  parameters: Record<string, string | boolean | number | string[]>,
  success: string,
) => Promise<void>;

interface GovernanceSectionProps {
  communities: Community[];
  memberships: Membership[];
  snapshots: GovernanceSnapshot[];
  currentUserId: string;
  pendingActions: string[];
  runAction: GovernanceAction;
}

type Confirmation = "commit" | "resign" | null;

function ElectionPanel({
  snapshot,
  pendingActions,
  runAction,
}: {
  snapshot: GovernanceSnapshot;
  pendingActions: string[];
  runAction: GovernanceAction;
}) {
  const [selected, setSelected] = useState<string[]>([]);
  const limit = snapshot.seats_available ?? 0;
  const voting = snapshot.cycle_status === "voting" && snapshot.round_id;
  const candidacy = snapshot.cycle_status === "candidacy";

  return (
    <section
      className="governance-subsection"
      aria-labelledby={`election-${snapshot.community_id}`}
    >
      <h4 id={`election-${snapshot.community_id}`}>Election</h4>
      {candidacy && (
        <>
          <p>
            <strong>Candidates</strong>
            <br />
            {snapshot.candidate_ids.length} /{" "}
            {snapshot.governance_state === "democratic_preparation"
              ? "3 minimum required"
              : `${snapshot.seats_available ?? snapshot.council_target ?? 0} seats being filled`}
          </p>
          <ul className="plain-list" aria-label="Current candidates">
            {snapshot.candidate_ids.map((candidateId, index) => (
              <li key={candidateId}>{candidateLabel(index)}</li>
            ))}
          </ul>
          {snapshot.current_user_is_candidate ? (
            <button
              type="button"
              className="secondary"
              disabled={pendingActions.includes(
                `withdraw-${snapshot.community_id}`,
              )}
              onClick={() =>
                void runAction(
                  `withdraw-${snapshot.community_id}`,
                  "withdraw_election_candidacy",
                  { target_cycle_id: snapshot.cycle_id ?? "" },
                  "Your candidacy was withdrawn.",
                )
              }
            >
              Withdraw candidacy
            </button>
          ) : (
            <button
              type="button"
              disabled={pendingActions.includes(
                `stand-${snapshot.community_id}`,
              )}
              onClick={() =>
                void runAction(
                  `stand-${snapshot.community_id}`,
                  "stand_for_election",
                  { target_cycle_id: snapshot.cycle_id ?? "" },
                  "Your candidacy was submitted.",
                )
              }
            >
              Stand as candidate
            </button>
          )}
        </>
      )}
      {voting && snapshot.round_number && snapshot.round_number > 1 && (
        <p className="status-panel">
          <strong>Runoff required.</strong> The final seat remains unresolved.
          No winner is selected at random.
        </p>
      )}
      {voting && snapshot.current_user_ballot_recorded ? (
        <p className="status-panel" role="status">
          Your ballot was recorded.
        </p>
      ) : voting && snapshot.current_user_may_vote ? (
        <form
          aria-busy={pendingActions.includes(`ballot-${snapshot.community_id}`)}
          onSubmit={(event) => {
            event.preventDefault();
            void runAction(
              `ballot-${snapshot.community_id}`,
              "submit_election_ballot",
              {
                target_round_id: snapshot.round_id ?? "",
                approved_candidate_ids: selected,
              },
              "Your ballot was recorded.",
            ).then(() => setSelected([]));
          }}
        >
          <fieldset aria-describedby={`ballot-help-${snapshot.community_id}`}>
            <legend>Approve candidates</legend>
            <p id={`ballot-help-${snapshot.community_id}`}>
              Choose up to {limit} candidates. Selections are unranked and are
              not shown after submission.
            </p>
            {snapshot.candidate_ids.map((candidateId, index) => {
              const checked = selected.includes(candidateId);
              const atLimit = selected.length >= limit;
              return (
                <label key={candidateId}>
                  <input
                    type="checkbox"
                    checked={checked}
                    disabled={!checked && atLimit}
                    aria-label={`Approve ${candidateLabel(index)}`}
                    onChange={() =>
                      setSelected((current) =>
                        checked
                          ? current.filter((id) => id !== candidateId)
                          : [...current, candidateId],
                      )
                    }
                  />
                  {candidateLabel(index)}
                </label>
              );
            })}
          </fieldset>
          <button
            type="submit"
            disabled={pendingActions.includes(
              `ballot-${snapshot.community_id}`,
            )}
          >
            Submit ballot
          </button>
        </form>
      ) : voting ? (
        <p>You are not eligible to vote in this round.</p>
      ) : null}
      {snapshot.round_status === "failed_quorum" && (
        <p className="status-panel">
          <strong>Election unsuccessful: quorum was not reached.</strong>{" "}
          Democratic transfer remains committed; managed administration is not
          restored.
        </p>
      )}
      {snapshot.round_status === "insufficient_winners" && (
        <p className="status-panel">
          <strong>No valid founding council was installed.</strong> The
          transition remains committed and a new election cycle is required.
        </p>
      )}
    </section>
  );
}

function CommunityGovernance({
  community,
  snapshot,
  memberships,
  currentUserId,
  pendingActions,
  runAction,
}: {
  community: Community;
  snapshot: GovernanceSnapshot;
  memberships: Membership[];
  currentUserId: string;
  pendingActions: string[];
  runAction: GovernanceAction;
}) {
  const [target, setTarget] = useState<CouncilTarget>(
    snapshot.council_target ?? 3,
  );
  const [confirmation, setConfirmation] = useState<Confirmation>(null);
  const activeMembership = memberships.find(
    (membership) =>
      membership.community_id === community.id &&
      membership.user_id === currentUserId &&
      membership.status === "active",
  );
  const admins = memberships.filter(
    (membership) =>
      membership.community_id === community.id &&
      membership.role === "admin" &&
      membership.status === "active",
  );
  const pendingCommit = pendingActions.includes(`commit-${community.id}`);
  const pendingResign = pendingActions.includes(`resign-${community.id}`);

  return (
    <article
      className="governance-community"
      aria-labelledby={`governance-${community.id}`}
    >
      <h3 id={`governance-${community.id}`}>{community.name}</h3>
      {snapshot.governance_state === "managed" && (
        <>
          <h4>Managed administration</h4>
          <p>
            Authority is exercised by the community owner and appointed
            administrators.
          </p>
          <dl className="governance-facts">
            <div>
              <dt>Owner</dt>
              <dd>
                {snapshot.is_owner
                  ? "You — community owner"
                  : "Community owner"}
              </dd>
            </div>
            <div>
              <dt>Appointed administrators</dt>
              <dd>{admins.length}</dd>
            </div>
            <div>
              <dt>Your role</dt>
              <dd>
                {snapshot.is_owner
                  ? "Community owner"
                  : activeMembership?.role === "admin"
                    ? "Appointed administrator"
                    : "Member"}
              </dd>
            </div>
          </dl>
          {snapshot.is_owner && (
            <form
              onSubmit={(event) => {
                event.preventDefault();
                void runAction(
                  `prepare-${community.id}`,
                  "begin_democratic_preparation",
                  {
                    target_community_id: community.id,
                    requested_seats: target,
                  },
                  "Democratic preparation started. This stage remains reversible.",
                );
              }}
            >
              <label htmlFor={`target-${community.id}`}>
                Target council size
              </label>
              <select
                id={`target-${community.id}`}
                value={target}
                onChange={(event) =>
                  setTarget(Number(event.target.value) as CouncilTarget)
                }
              >
                <option value={3}>3 seats</option>
                <option value={5}>5 seats</option>
              </select>
              <p>
                Preparation is reversible. Managed administration continues
                until an election is explicitly launched.
              </p>
              <button
                disabled={pendingActions.includes(`prepare-${community.id}`)}
              >
                Start democratic preparation
              </button>
            </form>
          )}
        </>
      )}
      {snapshot.governance_state === "democratic_preparation" && (
        <>
          <h4>Preparing democratic governance</h4>
          <p>
            <strong>The community is still managed.</strong> Preparation may be
            cancelled before the election is launched.
          </p>
          <p>
            Target: {snapshot.council_target} seats. Candidacies are open to
            eligible members and are not capped by the target.
          </p>
          <ElectionPanel
            snapshot={snapshot}
            pendingActions={pendingActions}
            runAction={runAction}
          />
          {snapshot.is_owner && (
            <div className="governance-actions">
              <label htmlFor={`change-target-${community.id}`}>
                Change target council size
              </label>
              <select
                id={`change-target-${community.id}`}
                value={target}
                onChange={(event) =>
                  setTarget(Number(event.target.value) as CouncilTarget)
                }
              >
                <option value={3}>3 seats</option>
                <option value={5}>5 seats</option>
              </select>
              <button
                className="secondary"
                onClick={() =>
                  void runAction(
                    `target-${community.id}`,
                    "change_preparation_council_target",
                    {
                      target_community_id: community.id,
                      requested_seats: target,
                    },
                    "Council target changed.",
                  )
                }
              >
                Change target
              </button>
              <button
                className="secondary"
                onClick={() =>
                  void runAction(
                    `cancel-${community.id}`,
                    "cancel_democratic_preparation",
                    { target_community_id: community.id },
                    "Democratic preparation cancelled. Managed administration continues.",
                  )
                }
              >
                Cancel democratic preparation
              </button>
              <button
                disabled={!canCommitFoundingTransfer(snapshot)}
                onClick={() => setConfirmation("commit")}
              >
                Launch election and commit democratic transfer
              </button>
              {snapshot.candidate_ids.length < 3 && (
                <p role="status">
                  At least 3 candidates are required before the election can
                  launch.
                </p>
              )}
            </div>
          )}
        </>
      )}
      {snapshot.governance_state === "democratic_transition" && (
        <>
          <h4>Committed transition to elected governance</h4>
          <p>
            <strong>The transfer is irreversible.</strong> Appointed
            administrators now serve only as temporary caretakers. The owner
            cannot restore managed administration alone.
          </p>
          <ElectionPanel
            snapshot={snapshot}
            pendingActions={pendingActions}
            runAction={runAction}
          />
          {snapshot.cycle_status === "failed" && (
            <button
              onClick={() =>
                void runAction(
                  `retry-${community.id}`,
                  "open_transition_retry_cycle",
                  { target_community_id: community.id },
                  "A new candidacy cycle was opened. Democratic transfer remains committed.",
                )
              }
            >
              Open new election cycle
            </button>
          )}
        </>
      )}
      {snapshot.governance_state === "democratic" && (
        <>
          <h4>Elected community council</h4>
          <dl className="governance-facts">
            <div>
              <dt>Target</dt>
              <dd>{snapshot.council_target} seats</dd>
            </div>
            <div>
              <dt>Active elected members</dt>
              <dd>{snapshot.active_mandates}</dd>
            </div>
            <div>
              <dt>Vacant seats</dt>
              <dd>{snapshot.vacant_seats}</dd>
            </div>
          </dl>
          {(snapshot.active_mandates ?? 0) > 0 && (
            <div>
              <strong>
                {snapshot.operational_status === "operational"
                  ? "Active elected members"
                  : "Temporary democratic caretakers"}
              </strong>
              <ul className="plain-list">
                {snapshot.elected_member_ids.map((memberId, index) => (
                  <li key={memberId}>
                    Council member {index + 1}
                    {memberId === currentUserId ? " — you" : ""}
                  </li>
                ))}
              </ul>
            </div>
          )}
          {snapshot.operational_status === "operational" && (
            <p className="status-panel">
              <strong>Council operational.</strong> Ordinary administration is
              exercised by elected council members.
            </p>
          )}
          {snapshot.operational_status === "under_strength" && (
            <p className="status-panel">
              <strong>Council under-strength — reconstitution required.</strong>{" "}
              Remaining elected members are temporary democratic caretakers.
              Governance remains democratic; the owner and former admins have
              not regained control.
            </p>
          )}
          {snapshot.operational_status === "vacant" && (
            <p className="status-panel">
              <strong>
                Council vacant — democratic reconstitution required.
              </strong>{" "}
              Nobody currently holds elected council authority. Governance
              remains democratic and historical owners or admins do not regain
              authority.
            </p>
          )}
          {snapshot.may_resign && (
            <button
              className="secondary"
              onClick={() => setConfirmation("resign")}
            >
              Resign from council
            </button>
          )}
          {(snapshot.vacant_seats ?? 0) > 0 &&
            (!snapshot.cycle_id ||
              snapshot.cycle_status === "failed" ||
              snapshot.cycle_status === "completed") && (
              <button
                onClick={() =>
                  void runAction(
                    `reconstitute-${community.id}`,
                    "open_council_reconstitution_cycle",
                    { target_community_id: community.id },
                    "Council reconstitution opened.",
                  )
                }
              >
                {snapshot.operational_status === "operational"
                  ? "Open by-election"
                  : "Open council reconstitution"}
              </button>
            )}
          {snapshot.cycle_id && (
            <ElectionPanel
              snapshot={snapshot}
              pendingActions={pendingActions}
              runAction={runAction}
            />
          )}
        </>
      )}
      {confirmation === "commit" && (
        <ConfirmationDialog
          title="Commit the democratic transfer?"
          description="Once launched, the community cannot be returned to managed administration by the owner alone, even if the election fails. The owner cannot cancel the transition or simply take control back, and appointed administrators become temporary caretakers."
          confirmLabel="Launch election and commit transfer"
          pending={pendingCommit}
          onCancel={() => setConfirmation(null)}
          onConfirm={() =>
            void runAction(
              `commit-${community.id}`,
              "commit_democratic_transfer",
              { target_community_id: community.id },
              "Democratic transfer committed. The election is now open.",
            ).then(() => setConfirmation(null))
          }
        />
      )}
      {confirmation === "resign" && (
        <ConfirmationDialog
          title="Resign from the council?"
          description="Your resignation is immediate once confirmed and your seat becomes vacant. If fewer than three active councillors remain, democratic reconstitution is required. The owner does not regain control."
          confirmLabel="Confirm council resignation"
          pending={pendingResign}
          onCancel={() => setConfirmation(null)}
          onConfirm={() =>
            void runAction(
              `resign-${community.id}`,
              "resign_elected_council_mandate",
              { target_community_id: community.id },
              "Council resignation completed. Your seat is now vacant.",
            ).then(() => setConfirmation(null))
          }
        />
      )}
    </article>
  );
}

export function GovernanceSection(props: GovernanceSectionProps) {
  return (
    <section
      className="card wide governance-section"
      aria-labelledby="governance-title"
    >
      <h2 id="governance-title">Community governance</h2>
      <p>
        See who currently exercises authority and take actions available to your
        independent roles.
      </p>
      <div className="governance-grid">
        {props.communities.map((community) => {
          const snapshot = props.snapshots.find(
            (candidate) => candidate.community_id === community.id,
          );
          return snapshot ? (
            <CommunityGovernance
              key={community.id}
              community={community}
              snapshot={snapshot}
              memberships={props.memberships}
              currentUserId={props.currentUserId}
              pendingActions={props.pendingActions}
              runAction={props.runAction}
            />
          ) : null;
        })}
      </div>
    </section>
  );
}
