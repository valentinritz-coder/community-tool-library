# ADR 0003: Use Supabase/PostgreSQL for the MVP

- Status: Accepted
- Date: 2026-08-10

## Context

The MVP needs relational data, authentication, photo storage and strong authorization without building commodity infrastructure from scratch.

## Decision

Use Supabase as the initial backend platform, with PostgreSQL as the source of truth, Supabase Auth for authentication, and Supabase Storage for item/condition photos.

M0 validated the decision with a reproducible CLI workflow, versioned migrations and behavioural
pgTAP tests for both table RLS and private Storage object policies. The proof uses an authenticated
user's JWT identity rather than a privileged service-role bypass.

## Consequences

### Positive

- PostgreSQL data model;
- authentication and storage available without custom infrastructure;
- Row Level Security can enforce tenant/community boundaries close to the data;
- simple pilot operations.

### Risks

- platform-specific APIs can create coupling;
- RLS policies can become difficult to reason about if not tested;
- storage authorization must be designed as carefully as table authorization.

## Guardrails

- keep domain logic in application/domain modules where practical;
- version database changes as migrations;
- test RLS/authorization boundaries explicitly;
- do not put privileged service credentials in client code;
- preserve PostgreSQL portability where it does not materially increase complexity.

## Validation required in M0

- local development setup;
- migration strategy;
- test strategy for RLS;
- private/public storage policy design;
- environment/secret management.

## M0 validation result

The local stack can be created from a clean clone with the pinned Supabase CLI and Docker. Database
reset applies repository migrations deterministically, and `supabase test db` exercises allowed and
denied access as the `authenticated` database role. A private, MIME-restricted `item-photos` bucket
uses the first object-path segment as the authenticated owner's identifier; behavioural tests prove
that an owner can upload/read their path while another identity cannot read it or upload to it.

This is sufficient to accept Supabase/PostgreSQL as the MVP backend direction. It does not approve a
future domain schema or final community-aware authorization rules: those must be introduced and
tested with their respective features. Operational cost remains deployment-specific and must be
reviewed before a pilot environment is provisioned.
