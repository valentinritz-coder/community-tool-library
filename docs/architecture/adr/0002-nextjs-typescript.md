# ADR 0002: Use Next.js with strict TypeScript

- Status: Accepted
- Date: 2026-08-10

## Context

The MVP needs a maintainable full-stack web application that works well with GitHub/Codex workflows and has a large ecosystem for accessible UI, testing and deployment.

## Decision

Use Next.js with TypeScript in strict mode for the application.

## Consequences

- shared language/types across client and server code;
- mature React ecosystem and good agent/tool support;
- straightforward server-rendered and interactive flows;
- framework conventions must be respected to avoid client/server boundary mistakes.

## Guardrails

- no `any` without justification;
- business rules live outside presentation components;
- server-only secrets/data access never enter client bundles;
- route/server boundaries validate untrusted input.
