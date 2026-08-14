# ADR 0006: Keep election mechanics separate from democratic transfer

- Status: Accepted
- Date: 2026-08-14

## Context

ADR 0005 defines the election constitution and makes
`democratic_preparation -> democratic_transition` the irreversible political commitment. Issue #55
needs authoritative candidacy, snapshot, ballot, result and runoff storage without implementing the
commitment or installing a council, which belong to #56.

## Decision

Election cycles persist their candidacy phase, frozen electorate and candidate sets, independently
identified voting rounds, aggregate results and winners. Ballots and approvals are private
authoritative tables with no ordinary authenticated table privileges. A narrow submission RPC
validates the frozen voter, round candidate set, approval limit and one-ballot-per-round invariant.
An aggregate result RPC never returns voter identity or ballot selections.

Cycle creation and freeze are `SECURITY DEFINER` composition primitives with execution revoked from
browser roles. Issue #56 must call them inside its authoritative political transition; issue #55
does not expose a client-callable governance-state transition. Candidacy, withdrawal, ballot
submission and aggregate result reads are narrow authenticated operations. Closing and finalizing a
round are separate internal platform primitives, both revoked from browser roles. A round is
finalizable only after the close primitive has atomically changed it from `voting` to `closed`;
neither an elector nor an owner, appointed administrator or caretaker receives discretionary
closing power. Issue #56 or an authoritative server scheduler may compose that boundary without
changing community governance. Finalization locks the closed round and cycle, persists its outcome
once, and creates a new round containing only candidates tied
across the final-seat boundary when necessary. Every runoff reuses the original electorate
snapshot but has a distinct ballot uniqueness boundary.

Candidates already above a runoff boundary are recorded as provisional only. The authoritative
winner relation is materialized only when the entire founding cycle completes with at least three
winners. The aggregate result contract identifies its round and distinguishes provisional status
from final election, so a failed or unresolved cycle cannot imply a one- or two-person council.

Election failure marks the cycle failed without changing `communities.governance_state`. A later
cycle may therefore be created while #56 keeps the community in `democratic_transition`. Recorded
winners are data for #56; they confer no council mandate or administrative authority by themselves.

## Consequences

- membership and role changes cannot rewrite a frozen election;
- community roles cannot read a voter-to-choice ledger through ordinary APIs;
- database uniqueness and row locks, rather than browser coordination, serialize sensitive writes;
- issue #56 remains responsible for commitment, caretaker authority and council installation;
- issue #57 remains responsible for the broad election UI, and #60 for vacancies and
  reconstitution after installation;
- ballot confidentiality is application-level access control, not cryptographic secrecy.
