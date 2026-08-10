# Community Tool Library

Community Tool Library is a local platform for sharing and reserving small tools and equipment inside trusted communities.

The first target is a municipality-backed pilot where residents can offer small equipment, discover what is available nearby, request a reservation, agree on a small rental price or free loan, and hand the item over directly.

## Product thesis

Households own many tools that are rarely used. At the same time, neighbours often buy the same equipment because there is no trustworthy, convenient way to discover and reserve what already exists locally.

The product aims to make **access more useful than ownership** for low-risk, infrequently used equipment.

## MVP

The MVP will support:

- user accounts;
- communities and memberships;
- a community inventory;
- member-owned items;
- item photos and descriptions;
- free loans or owner-defined price per day;
- availability and reservation requests;
- owner acceptance/refusal;
- checkout and return states;
- before/after condition photos;
- a basic transaction history;
- privacy and accessibility by design.

See [`docs/product/MVP.md`](docs/product/MVP.md) for acceptance boundaries.

## Explicitly out of scope for the MVP

- integrated payments;
- internal credit economy;
- collective purchasing;
- automated lockers;
- dangerous/high-risk equipment;
- AI features;
- insurance integration;
- national anonymous marketplace behaviour.

See [`docs/product/OUT_OF_SCOPE.md`](docs/product/OUT_OF_SCOPE.md).

## Technical direction

The intended implementation is a responsive web application using TypeScript, Next.js and Supabase/PostgreSQL. Architectural choices are documented as ADRs under [`docs/architecture/adr`](docs/architecture/adr).

## Development workflow

Development is issue-driven:

1. an issue defines the user story and acceptance criteria;
2. implementation happens on a short-lived branch;
3. tests, lint, type checks and build must pass;
4. changes are merged through a pull request;
5. important architectural changes require an ADR.

AI coding agents must follow [`AGENTS.md`](AGENTS.md).

## Local development

This project requires Node.js 20.9 or later. Install dependencies and start the development server:

```bash
npm install
npm run dev
```

The application skeleton does not consume backend configuration yet. The repository now includes
a local Supabase proof of concept; see
[`docs/development/SUPABASE.md`](docs/development/SUPABASE.md) for its prerequisites, environment
variables, migration workflow and security tests. Never commit secrets.

The source tree separates concerns as follows:

- `src/app`: Next.js routes and global styling;
- `src/ui`: presentation components;
- `src/domain`: framework-independent domain rules and types;
- `src/application`: application use cases;
- `src/infrastructure`: external-system adapters.

Run the complete local validation suite before opening a pull request:

```bash
npm run lint
npm run typecheck
npm test
npm run build
```

Formatting can be checked with `npm run format:check` and applied with `npm run format`.

## Accessibility

The application is intended to be usable by people with limited digital confidence, including older residents. Accessibility is therefore a product requirement, not post-launch polish.

See [`docs/accessibility/ACCESSIBILITY.md`](docs/accessibility/ACCESSIBILITY.md).

## Legal / privacy status

This repository contains early product and technical work. Legal documents in `docs/legal` are engineering notes and checklists, not legal advice. A public pilot must receive appropriate legal review before launch.

The MVP deliberately avoids handling payments and aims to minimize stored personal data.

## License

No open-source license is granted at this stage. Unless explicitly stated otherwise, all rights are reserved.

Copyright © 2026 Valentin Ritz.
