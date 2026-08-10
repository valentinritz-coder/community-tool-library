# AGENTS.md

This file defines mandatory working rules for AI coding agents and human contributors.

## Product guardrails

- Implement only the issue in scope.
- Do not add speculative features.
- Do not introduce payments, credits, lockers, AI features, collective purchasing, insurance workflows or dangerous-equipment support unless a dedicated issue and ADR explicitly approve them.
- Prefer a small coherent MVP over generic extensibility.

## Code conventions

- TypeScript strict mode is mandatory.
- Avoid `any`; if unavoidable, justify it in code and in the PR.
- Prefer explicit domain types over loose dictionaries.
- Keep business rules out of React presentation components.
- Keep server-only code server-only.
- Validate all untrusted input at system boundaries.
- No secrets, credentials or real personal data in the repository, fixtures or test snapshots.
- New dependencies require a short justification in the PR.
- Database schema changes must be versioned as migrations.

## Architecture

- Domain concepts are `User`, `Community`, `Membership`, `Item`, `Availability`, `Booking`, `Handover`, and `ConditionReport`.
- Authorization must be enforced server-side and, where applicable, with database row-level security.
- UI visibility is never an authorization mechanism.
- Important architecture changes require an ADR in `docs/architecture/adr/`.

## Accessibility

- Core flows must be keyboard operable.
- Interactive controls need visible focus states and accessible names.
- Do not rely on colour alone to convey state.
- Prefer plain language and large, forgiving touch targets.
- Forms must provide explicit labels and useful error messages.
- Mobile layouts are first-class, not a later adaptation.

## Testing

For every behaviour change:

- add or update relevant automated tests;
- test authorization boundaries for protected data/actions;
- cover important failure states, not only happy paths;
- keep test fixtures synthetic.

Before a PR is considered complete, run the repository's lint, typecheck, test and build commands.

## Pull requests

Each PR should include:

- the issue it addresses;
- what changed;
- notable trade-offs;
- validation performed;
- accessibility/privacy implications where relevant;
- any follow-up deliberately left out.

Keep PRs small enough to review. Do not mix unrelated refactors with feature work.
