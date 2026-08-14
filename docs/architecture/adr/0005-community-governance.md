# ADR 0005: Define the community governance constitution

- Status: Accepted
- Date: 2026-08-14

## Context

The MVP needs an explicit distinction between ownership, appointed administration and elected
governance. Without a constitution, later authorization, election and continuity work could encode
different political rules or accidentally return a democratic community to its former owner after
an election failure or council vacancy.

This ADR defines product and domain invariants only. It does not select a database representation,
API, RLS policy or user interface.

## Decision

### Roles are independent

The following roles must be represented and authorized explicitly. Holding one role never grants
another role implicitly.

| Role                    | Conceptual powers                                                                                                                                                                                                                                                                                                                                                                                                |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Platform operator       | Acts outside community politics when necessary for security, technical integrity, legal obligations, compliance, prohibited content or behaviour, and justified suspension or other operator measures. It cannot use those powers as a right to choose or arbitrarily replace community government.                                                                                                              |
| Community owner         | Holds the community's ownership designation. In `managed` and `democratic_preparation`, exercises ordinary administration and appoints or removes appointed administrators. May open/cancel preparation, choose a 3- or 5-seat target, and explicitly commit an eligible founding election. After commitment, ownership alone grants no ordinary administration, election control or right to restore `managed`. |
| Appointed administrator | Exercises delegated ordinary administration while appointed administration is in force. Cannot exercise the owner's ownership-only decisions or acquire elected authority by appointment.                                                                                                                                                                                                                        |
| Temporary caretaker     | Preserves necessary day-to-day service and enforces existing community rules while a valid council is unavailable. May handle existing membership, listing and moderation operations needed for continuity, but cannot appoint administrators, change the constitution or target council size, cancel democratic transfer, select candidates, alter an election, fill vacancies, or claim a democratic mandate.  |
| Ordinary active member  | Uses ordinary member capabilities, may cast one ballot when included in the authoritative electorate snapshot, may stand as an individual candidate when eligible, and may use the member-accessible democratic reconstitution path. Active membership alone grants no administrative power.                                                                                                                     |
| Candidate               | An eligible active member who individually stands for a particular election. Candidacy grants no administrative or council authority.                                                                                                                                                                                                                                                                            |
| Elected council member  | Holds a valid electoral mandate and, as part of an operational council, exercises ordinary community administration. When only one or two elected members remain, each has temporary caretaker authority only until reconstitution.                                                                                                                                                                              |

The owner may separately be an active member, appointed administrator or candidate if eligible.
An appointed administrator may likewise be a candidate. Authorization must test the relevant role,
governance state and mandate rather than infer authority from coincident roles. Neither an owner nor
an administrator becomes elected automatically.

“Ordinary administration” means applying existing community rules to membership, listings and
community moderation, and other routine operational decisions. It excludes operator interventions,
constitutional decisions, election control and powers expressly reserved to another role.

### Governance state machine and irreversible boundary

The only forward sequence is:

`managed -> democratic_preparation -> democratic_transition -> democratic`

#### `managed`

The owner and appointed administrators exercise ordinary administration. The owner may appoint and
remove administrators and may open `democratic_preparation`.

#### `democratic_preparation`

Preparation is reversible. Ordinary administration remains exactly as in `managed`. The owner
chooses a target council size of 3 or 5 seats, but the platform fixes the constitutional minimum at
three elected members. The owner neither selects nor caps candidates: every eligible active member
may stand individually. With zero, one or two valid candidates, no founding election can launch and
the community remains in preparation. Before commitment, the owner may cancel and return to
`managed`.

#### `democratic_transition`

The transition **from `democratic_preparation` to `democratic_transition` is the exact point at
which the transfer becomes unilaterally irreversible**. It requires an explicit owner confirmation,
at least three valid candidates, at least five active members in the authoritative electorate, a
target of 3 or 5 seats, and no incompatible election state. The founding candidate set and
electorate are then frozen as required for a deterministic election.

From that transition onward, the owner cannot cancel the transfer or restore `managed` alone.
Appointed administrators cease appointed administration and become temporary caretakers. A failed
quorum, fewer than three electable winners, or an unresolved final-seat tie leaves the community in
`democratic_transition`; caretakers continue and a new candidacy/election cycle (or required runoff)
must occur. Failure never returns authority to the owner.

#### `democratic`

This state begins only when a valid election installs at least three elected members. The elected
council takes ordinary administration. Ownership by itself retains only the ownership designation
and no exclusive political or ordinary administrative power; any member, candidate or council
power held by the owner must arise independently under the same rules as for anyone else.

Later vacancies do not change the governance state. There is no `democratic -> managed` mechanism
in M5.5, and an owner can never trigger such a return alone. If introduced later, it must use a
dedicated, member-controlled democratic procedure; this ADR does not design that procedure.

### Power matrix

Operator interventions described above remain available in every row and do not confer community
political authority.

| Community condition                                                                   | Ordinary administration                                                                             | Appoint/remove appointed admins | Start/cancel preparation and choose target                        | Commit founding transfer                              | Conduct/finalize election                                                                                                               | Initiate reconstitution / fill vacancies                                                                                                                        |
| ------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `managed`                                                                             | Owner and appointed administrators                                                                  | Owner                           | Owner may start preparation                                       | Not available                                         | Not available                                                                                                                           | Not applicable                                                                                                                                                  |
| `democratic_preparation`                                                              | Owner and appointed administrators                                                                  | Owner                           | Owner may cancel or choose 3/5; cannot curate candidates          | Owner, only when all preconditions hold               | Not before commitment                                                                                                                   | Not applicable                                                                                                                                                  |
| `democratic_transition`                                                               | Former appointed administrators as temporary caretakers, limited to continuity under existing rules | Nobody                          | Nobody; target cannot be changed and transfer cannot be cancelled | Already committed; nobody can reverse it unilaterally | Active members in the frozen electorate vote; deterministic platform rules establish the result; no owner/admin/caretaker controls it   | Not applicable until a council is installed; failed founding elections require another member candidacy/election cycle                                          |
| `democratic`, 3+ active elected members                                               | Operational elected council                                                                         | Nobody                          | Nobody                                                            | Not applicable                                        | Active members in the electorate snapshot vote under the constitution; the sitting council remains until a valid successor is installed | A vacancy makes the mechanism available deterministically; an active member can initiate/access it, and the election may fill only vacant seats                 |
| `democratic`, 1–2 active elected members (`under-strength / reconstitution required`) | Remaining elected members only as temporary caretakers, limited to continuity under existing rules  | Nobody                          | Nobody                                                            | Not applicable                                        | Active members in the electorate snapshot vote under the constitution                                                                   | A vacancy makes reconstitution available deterministically; an active member can initiate/access it without the former owner or former appointed administrators |
| `democratic`, 0 active elected members (`vacant / reconstitution required`)           | Nobody; human-governed functions may be restricted                                                  | Nobody                          | Nobody                                                            | Not applicable                                        | Active members in the electorate snapshot vote under the constitution                                                                   | Reconstitution is available deterministically; an active member can initiate/access it independently of the historical owner; only vacant seats may be filled   |

The matrix describes authorization outcomes, not an implementation mechanism. In particular, UI
visibility must not be treated as authorization.

### Council size and candidacy

- The owner selects a target of 3 or 5 seats during `democratic_preparation`; it does not change
  during a mandate.
- Three elected members is the constitutional minimum for initial installation or restoration of
  normal council operation. A founding council of one or two is invalid.
- Candidacies are individual; party and list slates are unsupported.
- Every otherwise-eligible active member may stand. There is no owner-selected candidate count or
  owner-imposed cap.
- Owner and appointed administrators may stand if eligible, but receive no automatic mandate.

### MVP election method

Council, by-election and reconstitution elections use multi-winner approval voting:

For every election, the authoritative electorate snapshot consists of the community's active
members at the moment the snapshot is frozen. Every member in that snapshot may submit exactly one
ballot. Voting requires no additional tenure rule, owner/admin/council approval, or qualification
as a subclass of active member. Candidate eligibility is separate and does not restrict this right
to vote; this ADR does not add new candidacy criteria.

- each active member in the authoritative electorate snapshot may submit exactly one ballot;
- a voter may approve up to the number of seats being filled (the target size for a founding or
  full election, and only the vacant-seat count for a by-election/reconstitution);
- approvals are unranked;
- candidates with the highest approval totals fill the available seats;
- a candidate needs at least one approval to be electable, with no additional candidate-specific
  percentage threshold;
- quorum requires ballots from at least 20% of the eligible electorate **and** at least three
  submitted ballots;
- a tie affecting the final occupied seat requires a runoff limited to the tied candidates; random
  selection is forbidden.

For a founding election or full successor election, the result constitutes a new council and must
contain at least three elected members. A three-seat target therefore requires three electable
winners. A five-seat target permits three, four or five electable winners, with any remainder
explicitly vacant. Exactly three candidates are therefore enough to permit founding commitment for
either target, provided all other preconditions hold, although the result must still satisfy quorum
and produce three electable winners.

A by-election or reconstitution election instead preserves every existing active elected mandate
and fills only currently vacant seats. It may therefore elect fewer than three new members. Normal
council operation resumes as soon as `existing active elected mandates + newly elected mandates >=
3`. For example, one remaining mandate plus two winners filling the two vacancies of a three-seat
council restores normal operation; three new winners are neither required nor possible in that
election.

The term is 12 months. A sitting council remains in office after that term until a valid successor
is installed, avoiding an authority gap. This ADR does not otherwise design periodic renewal.

### Resignation, vacancies and democratic continuity

An elected member may resign. Resignation ends only that mandate and creates a vacant seat; other
mandates remain valid and the configured target stays 3 or 5. Resignation never restores `managed`
or revives owner/former-admin authority.

- With at least three active elected members, the council remains normally operational and may
  have vacant seats.
- With one or two, the community remains `democratic`, but its council status is
  `under-strength / reconstitution required`. Remaining elected members act only as temporary
  caretakers as defined above, not as a normal one- or two-person council.
- With zero, the community remains `democratic` with a `vacant / reconstitution required` council.
  No historical authority revives; functions requiring human authority may be restricted, and
  active members must have a safe reconstitution path that does not depend on the historical owner.

By-elections and reconstitution reuse the approval method and fill only vacant seats up to the
configured target. Failure leaves the existing democratic continuity condition unchanged. Normal
council operation resumes when at least three active elected members hold mandates. There is no
automatic succession by an unelected runner-up. Detailed workflows and authorization are reserved
for issue #60.

Whenever a democratic council has a vacancy, availability of the by-election/reconstitution
mechanism is a deterministic consequence of that vacancy rather than a discretionary political
power of the historical owner, former appointed administrators or caretakers. An active member can
initiate or reach that process in the 3+, 1–2 and zero-active-member conditions. Issue #60 will
define the UX, RPC, transaction and concurrency details without weakening this access invariant.

### Ballot privacy

The product must not expose a `voter -> candidates selected` ledger to members, the owner,
appointed administrators, caretakers or the council. Aggregate results and participation may be
published where the product needs them. This is application-level confidentiality of ballot
choices, not a claim of cryptographic secrecy, end-to-end verifiability or coercion resistance.
Storage and access-control design are deliberately deferred to the implementation issues.

## Consequences

### Positive

- the irreversible boundary and authority in failure/vacancy states are deterministic;
- ownership, appointed delegation, caretaker continuity and electoral mandate cannot be conflated;
- later server and database authorization can be tested against one political source of truth;
- approval voting is understandable for a small community while allowing support for several
  individuals;
- democratic authority cannot silently revert through election failure or council collapse.

### Trade-offs and risks

- transition may remain in caretaker operation through repeated failed elections;
- approval voting does not provide rankings or proportional representation;
- a five-seat target can begin or continue with vacancies;
- under-strength caretaker authority intentionally limits decisions until members reconstitute the
  council;
- application-level ballot confidentiality is weaker than cryptographic secret voting.

## Out of scope

- election/schema/RPC/RLS/UI implementation;
- referendums, constitutional amendment votes, general member propositions, recalls or no-confidence
  motions;
- ranked, weighted, proportional, list, liquid/delegated or proxy voting;
- cryptographic/end-to-end verifiable or coercion-resistant voting;
- automatic runner-up succession;
- changing council size during a mandate;
- ownership transfer, co-ownership, billing governance or a designed return from `democratic` to
  `managed`.
