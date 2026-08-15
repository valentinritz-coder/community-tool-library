# Pilot privacy and retention baseline

> Engineering and product baseline for issue #29. It describes the repository as implemented on
> 2026-08-12. It is not legal advice, a privacy notice, or a claim of GDPR or other legal
> compliance. Items marked **REQUIRES LEGAL REVIEW** must be decided outside this document before a
> public pilot.

## Implemented disclosure rules

- Authentication requires an email address. The application has no public profile, display name,
  phone, postal address, exact pickup location, identity/residence evidence, payment credential, or
  tracker collection.
- Community inventory (including item photos and availability summaries) is available only to
  active members of that community. Archived listings are limited to their active owner.
- Booking clients use role/capability projections. They do not receive `borrower_id`, `owner_id`,
  condition-report `author_id`, or authentication records.
- A counterparty email is disclosed only when a booking is `accepted`, only to its borrower and item
  owner, and only while the caller remains an active member of the item's community. Community
  administrators do not receive participant email unless they are themselves a participant.
  Contact disappears at handover (`checked_out`), after return, after refusal, and when membership
  ceases to be active. Participants should arrange the handover while the booking is accepted.
- Booking participants can complete an already accepted handover/return after membership loss, but
  membership loss does not preserve email access. Their transaction projection contains operational
  booking facts only.
- Condition reports and private condition photos are readable by the borrower, item owner, and an
  **active administrator of that same community**. Only borrower/owner participants can create a
  report or upload its reserved photo in the matching lifecycle phase. Client rows omit `author_id`
  and MIME metadata. Storage uses a private bucket and short-lived signed URLs; no public or
  permanent link is created by the application.

## Actual data inventory and pilot retention schedule

“Current retention” states what the software does today, not a legally required duration. The pilot
has no deletion scheduler, lifecycle worker, complete account-erasure flow, or legal hold system.

| Data actually processed | Source / table / bucket / projection | Product purpose | Who can see it, and when | Current pilot retention / limitation | External decision |
|---|---|---|---|---|---|
| Account UUID, email, encrypted credential and Supabase Auth technical metadata/timestamps | `auth.users`; sign-in/sign-up UI | Authentication; email is also the participant contact channel | Supabase Auth/service operators; the signed-in user through Auth; only the counterparty email projection described below | Retained by Supabase Auth until the account is deleted. There is no complete user-facing deletion workflow. Deleting an Auth user cascades memberships, owned items and borrowed bookings, but can be blocked by condition-report or moderation-report `RESTRICT` references to authors, reporters, counterparties, or handling admins; this is a documented pilot limitation, not an erasure promise. | **REQUIRES LEGAL REVIEW:** lawful basis, notice, account closure/erasure handling and any required post-closure period. |
| Auth/session technical identifiers and browser session material | Supabase Auth client/session | Maintain authenticated sessions and enforce `auth.uid()` authorization | The user’s browser and Supabase Auth/service operators | Governed by the configured Supabase Auth session lifecycle; no application tracker or separate consent manager is present. | **REQUIRES LEGAL REVIEW:** hosted configuration, cookie/storage wording, processor terms and international transfers. |
| Community UUID, name, secret join code, creation time | `communities`; community RPCs | Define a sharing boundary and permit join requests | Active members can read the community row (including its join code); a supplied join code can initiate a request. It is not publicly browsable. | Retained until the community is deleted; no self-service community deletion exists. Deletion would cascade memberships and items, subject to downstream historical/evidence constraints. | **REQUIRES LEGAL REVIEW:** whether join-code visibility/rotation and operator deletion procedures are adequate. |
| Membership community/user UUID pair, role, status, creation time | `memberships`; membership/admin RPCs | Access control and membership approval | The user sees their own row; active community admins see that community’s membership rows; identifiers remain server-side elsewhere | Retained until the membership, community, or Auth user is deleted. Status is changed rather than automatically purged; no audit copy or timed purge is implemented. | **REQUIRES LEGAL REVIEW:** post-membership retention and administrator access expectations. |
| Item UUID, community/owner UUID, name, category, description, price/free terms, photo path, publication/archive/moderation flags, creation time | `items`; `browse_community_inventory()` | Publish and manage community inventory and direct-settlement terms | Owner sees their row while actively enrolled; active members receive a projection without `owner_id`; only published, unarchived, non-moderated items appear in browse | Rows remain until their parent account/community is deleted; archive and moderation hide rather than delete. An item referenced by a moderation report cannot be deleted until a future controlled retention/deletion procedure addresses that `RESTRICT` reference. A row deletion does not guarantee deletion of its Storage object. | **REQUIRES LEGAL REVIEW:** retention after archive/moderation/account closure and whether descriptions/photos may contain incidental personal data. |
| Item image and Storage object metadata | private `item-photos` bucket; temporary signed URL in UI | Illustrate an item | Active members can read a published/unarchived item image; an active owner can also read archived inventory imagery and upload/replace their own image | Replaced objects are overwritten. Deleting an `items` row does not guarantee deletion of its Storage object, which can become orphaned; no automatic orphan cleanup exists. The pilot deletion/retention procedure must handle this operational limitation. Signed URLs are generated for 300 seconds (5 minutes) and are not stored by the application. | **REQUIRES LEGAL REVIEW:** acceptable image retention and user guidance about personal information in images. |
| Availability UUID, item UUID, inclusive date range, creation time; formatted summary | `availabilities`; inventory projection | Let owners publish requestable dates and validate requests | Active owner reads/manages rows; active community members see only the formatted availability summary in inventory | Retained until explicitly changed/deleted by the owner or cascaded with the item. No separate historical archive or timed purge. | No duration is asserted; review with the overall listing schedule before public launch. |
| Booking UUID, item/borrower UUIDs, requested date range, status, creation time | `bookings`; request/decision/lifecycle RPCs; `list_booking_requests()` | Operate decisions, handover/return, conflict prevention and transaction history | Raw table has no client table privilege. Borrower/owner see a privacy-minimized projection for their transactions even after membership loss; active same-community admins see only requested rows needed to decide. Other users see none. | Retained as transaction history; no automatic deletion. Item/Auth deletion can cascade bookings unless condition evidence prevents it, and a booking used for a counterparty moderation report is protected by `RESTRICT` until a future controlled retention/deletion procedure handles that report. No fixed period is claimed. | **REQUIRES LEGAL REVIEW:** operational/dispute/moderation record periods, deletion exceptions, admin needs, and handling of non-returns/damage. |
| Counterparty email plus booking UUID | `list_accepted_booking_contacts()` projection from `auth.users` | Let participants arrange an accepted exchange | Only active borrower and owner, only while status is `accepted`; never a non-participant admin/member | Not copied into a product table. It remains in Auth according to account retention; projection access ends on status/membership change. A user may independently retain an email once disclosed. | **REQUIRES LEGAL REVIEW:** notice/lawful basis and whether the accepted-only window is operationally sufficient. |
| Handover/return state | `bookings.status` values `checked_out` / `returned`; lifecycle RPCs | Record custody and make returned exchanges historical | Borrower and owner projection; no participant IDs. Active admin does not gain historical booking visibility solely from role. | Part of booking history; retained indefinitely in the current product pending the booking-history decision above. | **REQUIRES LEGAL REVIEW:** same unresolved transaction-history period and dispute requirements. |
| Condition report UUID, booking UUID, phase, path, MIME type, author UUID, creation time | `condition_reports`; condition RPC/projection | Reserve and describe before/after condition evidence | Borrower, owner, and active same-community admin can read client-safe columns; `author_id` and MIME are withheld. Only participants create evidence in permitted phases. | Immutable and retained indefinitely with the booking today. `RESTRICT` references intentionally prevent accidental Auth/booking deletion, but no reviewed deletion/operator process exists. | **REQUIRES LEGAL REVIEW:** purpose, evidence period, administrator access, disputes, deletion and legal holds. |
| Condition image and Storage metadata | private `condition-photos` bucket; temporary signed URL in UI | Evidence item condition around handover/return | Same read boundary as DB report; only the authoring participant uploads the exact reserved object. Signed URLs last 300 seconds (5 minutes) and are not persisted by the app. | Retained indefinitely; no user deletion, scheduled purge, or orphan cleanup. This is a public-pilot blocker until an evidence schedule/process is reviewed. | **REQUIRES LEGAL REVIEW:** retention duration, access, deletion, disputes and image-content guidance. |
| Moderation report UUID, community, reporter UUID, item or booking-derived counterparty target, structured reason, optional note, status, timestamps, handling admin UUID and action | `moderation_reports`; submission and narrow admin RPCs | Let participants flag visible listings or a counterparty they encountered, and let the relevant community respond | Identifiers remain in the server-only table. Only active same-community admins receive the narrow queue (target label/item capability, reason, note, status/date/action); it omits reporter, counterparty, and handling-admin UUIDs. Item reports require currently visible inventory. Counterparty reports require current active membership, accept only a booking UUID, and derive the other participant server-side. Notes are untrusted text, trimmed and limited to 500 characters. | Retained with parent records indefinitely today; there is no deletion scheduler or reviewed retention period. `RESTRICT` references can block deletion of referenced accounts, items, and bookings until a future controlled procedure addresses the reports. Handled reports remain as a minimal operational trace. | **REQUIRES LEGAL REVIEW:** lawful basis/notice, administrator access, an appropriate retention period and deletion handling. |
| Technical RLS proof UUID, owner UUID, short body | `rls_validation_notes` | Repository infrastructure validation only; not an MVP user flow | Only the authenticated row owner | The production-facing migration still creates this proof table; no UI writes it and no cleanup automation exists. Do not use it for pilot content. | Decide operationally whether to remove this technical proof before production; legal review only if it will contain real data. |

The schema contains a community-scoped display name, but no approximate area,
address/pickup-location field, phone number, identity/residence document, analytics event store, payment/deposit record, or
insurance record. Those categories are therefore deliberately excluded from the inventory rather
than documented as if collected.

## Minimal moderation boundaries

One open report per reporter and target is enforced with partial unique indexes, including under
concurrent submissions; another report may be submitted after handling. Listing moderation uses an
admin-only `moderation_hidden` state separate from owner-controlled archive/publication. Hidden items
leave inventory browse and the normal photo-read boundary, and owners cannot clear that state.
Counterparty reports create no member directory and expose no raw participant UUID. The pilot adds no
ban, suspension, reputation, automated enforcement, appeal, or membership-removal workflow.

## Pilot retention operating rule

Until the external decisions above are complete, the honest implemented rule is **retain the current
records with their parent records and do not promise a deletion deadline**. Pilot operators must not
represent this as a legally approved schedule. Before admitting public-pilot users they must:

1. obtain reviewed periods/triggers for account, membership, listing, booking, and condition evidence;
2. document a manual, access-controlled deletion/closure procedure, including blocked cascades and
   Storage objects;
3. decide whether condition evidence must be preserved for a dispute and who may authorize deletion;
4. test that procedure on synthetic staging data and record the outcome; and
5. open a narrowly scoped follow-up for automation only where pilot volume and the reviewed schedule
   justify it.

No cron job, generic data-lifecycle framework, DSAR automation, or new data collection is introduced
by issue #29.

## Verification map

- `booking_participants.test.sql` verifies booking/contact projections, role boundaries, authorized
  statuses, and absence of raw participant identifiers. Its membership-loss regression keeps an
  accepted booking unchanged, proves that the inactive caller loses contact access, and proves that
  the other participant retains access while that participant remains active.
- `booking_handover_return.test.sql` verifies participant-only transitions, privacy after transitions,
  condition row/Storage symmetry, private metadata, and borrower/owner/admin/non-participant access.
- Community, item, availability, booking decision, and base Storage pgTAP files verify their narrower
  RLS and tenant boundaries.

The tests are regression evidence for implemented authorization, not a security certification or
legal-compliance assessment.

## Governance privacy inventory (M5.5)

Governance uses community-facing `memberships.display_name` values (or opaque member suffixes), not
authentication email addresses. The following inventory records the application boundary audited
for issue #58. “Internal” means browser roles have neither table privileges nor an RPC that returns
the row shape.

| Category | Purpose and classification | Application exposure and actor visibility | MVP retention expectation |
|---|---|---|---|
| Community governance fields (`owner_id`, state, council target, active cycle) | Authoritative active operational state and irreversible-transition audit context | Active members receive the minimum state/capability projection. Owner identity is a community display name; outsiders receive no row. Direct writes are denied. | Retain with the community. State/history must outlive a transition so a former owner cannot manufacture rollback. |
| Membership and `display_name` | Eligibility, authority and community-facing identity; active operational data | A member sees their own membership; continuity-authorized actors see the operational membership queue. Governance projections expose display names/opaque fallbacks only within the community. Auth email is not a community identity. | Retain with membership under the unresolved membership schedule above. |
| Cycles, candidacies, candidate and electorate snapshots | Run elections and preserve authoritative eligibility; active data followed by historical governance record | Narrow member projection exposes cycle state and candidate community identities. Raw tables and the electorate UUID ledger are internal. Snapshots remain immutable after freeze. | Retain with the community as the evidence needed to explain eligibility and results; no automated purge exists. |
| Rounds, aggregate candidate results and winners | Quorum, deterministic result, runoff and installation; historical governance record | Active members may receive round status, aggregate turnout/quorum and aggregate candidate results. No ballot choice is returned. | Retain with the election/council history; no automated purge exists. |
| Ballots | Enforce one ballot per electorate member/round; **sensitive ballot data** | Internal. The governance projection may return only whether the current caller's ballot was recorded and aggregate turnout. It does not return another voter's participation row. | Retained with the election today to enforce uniqueness and support authoritative counting. Any later deletion/anonymisation design needs a dedicated reviewed migration. |
| Ballot approvals | Count approvals; **most sensitive ballot data** because joining it to ballots creates voter-to-choice mapping | Internal only. `anon` and `authenticated` have no `SELECT`; no member/owner/admin/caretaker/councillor RPC or projection returns approval arrays or a voter-to-candidate ledger. | Retained internally with the election today. Operators must restrict database/service-role access and must not export it into logs, traces or routine support artifacts. |
| Elected councils and mandates | Establish current authority, term and vacancy count; active and historical governance record | Active members receive current elected community identities, term/status and vacancy totals. Ended mandates remain internal history; no free-text resignation reason exists. | Retain with the community to prove the source and end of authority. |
| Resignation/continuity history (`ended_at`, `ended_reason`, audit actor/details) | Prove mandate termination and deterministic reconstitution; historical governance/audit record | Member UI receives the resulting active count/status, not raw actor/audit rows. Internal history stores structured events only. | Retain with council history; no automated purge exists. Review before public pilot together with membership/account erasure. |
| Logs, CI artifacts, demo and test data | Diagnose synthetic validation, not a product record | Fixtures use reserved synthetic identities. Tests assert states/counts and avoid printing selections, credentials, tokens or a voter-to-choice export. Failure screenshots/traces remain access-controlled CI artifacts and should be deleted under the CI provider policy. | Keep only as long as needed to diagnose a run; do not promote test artifacts into governance records. |

The MVP provides **application-level ballot confidentiality/privacy**. It does **not** claim a
cryptographic secret ballot, coercion resistance, or end-to-end verifiability. Database operators
and tightly controlled service credentials necessarily sit outside the ordinary application actor
boundary. Cryptographic voting is deliberately out of scope.
