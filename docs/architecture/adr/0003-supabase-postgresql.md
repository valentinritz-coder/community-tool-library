# ADR 0003: Use Supabase/PostgreSQL for the MVP

- Status: Proposed
- Date: 2026-08-10

## Context

The MVP needs relational data, authentication, photo storage and strong authorization without building commodity infrastructure from scratch.

## Decision

Use Supabase as the initial backend platform, with PostgreSQL as the source of truth, Supabase Auth for authentication, and Supabase Storage for item/condition photos.

This remains **Proposed** until M0 verifies local development, migration workflow, authorization policies and cost/operational fit.

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
