# Architecture

## Principles

The MVP uses a conventional web architecture. The differentiator is the community/item/booking domain, not infrastructure novelty.

Priorities:

1. understandable by one maintainer and coding agents;
2. secure authorization boundaries;
3. mobile-first accessibility;
4. cheap to operate for a pilot;
5. easy to evolve without premature microservices.

## Proposed stack

- **Frontend/server application:** Next.js + TypeScript
- **Database:** PostgreSQL
- **Backend platform:** Supabase for PostgreSQL, authentication and object storage
- **Validation:** schema validation at request boundaries
- **Testing:** unit/integration tests plus browser tests for critical flows
- **CI:** GitHub Actions

Exact library choices beyond these foundations should be made during M0 and documented when material.

## Initial domain model

### User

An authenticated person. Personal data should be separated from public/community-facing profile data where practical.

### Community

A trusted group defining an access boundary. The first pilot is expected to map to a municipality/local community.

### Membership

Links a user to a community and carries role/status information.

### Item

A physical object listed by a member. Contains descriptive metadata, eligibility state and sharing terms.

### Availability

Rules/windows defining when an item may be requested.

### Booking

A request for exclusive access to an item over a time interval. Lifecycle initially: `requested`, `accepted`, `refused`, `cancelled`, `checked_out`, `returned`.

### Handover

Records operational handoff/return facts for an accepted booking.

### ConditionReport

References photos/notes describing item condition around handover/return.

## Authorization model

The database must enforce that:

- users can only access communities they are members of where required;
- only authorized owners/admins can modify items;
- borrowers cannot accept their own requests on behalf of owners;
- booking/condition information is visible only to participants/admins according to product rules;
- object storage paths and policies mirror data permissions.

Do not rely on hidden UI controls for access control.

## Deployment shape

Keep the MVP as a modular monolith:

```text
Browser
  |
Next.js application
  |
Domain/application services
  |
Supabase API / PostgreSQL / Storage
```

No microservices, queues or event bus until concrete load/reliability requirements justify them.

## Data/privacy boundary

Store the minimum data needed to operate the pilot. Exact home address should not be a generally browsable profile field. Verification documents, if introduced, require a dedicated privacy design and retention decision before implementation.
