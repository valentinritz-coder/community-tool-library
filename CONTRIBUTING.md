# Contributing

## Branches

Use short-lived branches:

- `feat/<short-description>` for product work;
- `fix/<short-description>` for fixes;
- `docs/<short-description>` for documentation;
- `agent/<short-description>` for agent-authored setup or maintenance work.

Do not push feature work directly to `main`.

## Commits

Use concise imperative commit messages, for example:

- `add community membership model`
- `validate booking date range`
- `document privacy retention rules`

Keep commits focused when practical. Do not manufacture meaningless commit granularity.

## Pull requests

A PR should solve one coherent issue or a tightly related set of issues. It must state:

- linked issue;
- user-visible outcome;
- implementation summary;
- tests/checks run;
- privacy/accessibility considerations;
- known limitations.

## Definition of done

A change is done when:

- acceptance criteria are met;
- authorization rules are enforced server-side;
- relevant automated tests exist;
- lint, typecheck, tests and build pass;
- accessibility has been considered for user-facing changes;
- docs/ADR are updated when behaviour or architecture changed;
- no secrets or real personal data were committed.

## Architecture decisions

Create an ADR when a decision is costly to reverse, affects multiple features, changes data ownership/security boundaries, or introduces a major dependency.

Use the next sequential number and the format in existing ADRs.
