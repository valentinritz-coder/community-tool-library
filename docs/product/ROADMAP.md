# MVP Roadmap

The roadmap is deliberately short. Later ideas stay outside the MVP until pilot behaviour justifies them.

## M0 — Foundation

Goal: a deployable, tested skeleton with architecture and security foundations.

- scaffold Next.js + strict TypeScript;
- establish Supabase local/dev workflow;
- add migrations and environment strategy;
- add lint/typecheck/test/build CI;
- establish accessible UI primitives;
- create synthetic seed/demo data strategy.

## M1 — Communities

Goal: users can authenticate and belong to a controlled community.

- sign in;
- create community (admin);
- join/invite flow;
- membership roles/status;
- server/database authorization boundaries.

## M2 — Inventory

Goal: members can create and discover small eligible items.

- item create/edit/archive;
- photo upload;
- category/name search;
- free or price-per-day terms;
- availability definition;
- moderation/removal.

## M3 — Booking lifecycle

Goal: real reservation and exchange flow.

- request date range;
- prevent conflicting accepted bookings;
- owner accept/refuse;
- cancel according to simple rules;
- checkout/handover;
- return;
- before/after condition photos;
- history.

## M4 — Pilot ready

Goal: safe and presentable enough for a small municipality-backed experiment.

- accessibility pass and manual test plan;
- privacy/data-retention implementation;
- reporting/moderation basics;
- legal copy placeholders reviewed/replaced before launch;
- demo community and seed data;
- production deployment/runbook;
- pilot metrics/event definitions.

M4 established the implementation and readiness foundations, but its remaining manual, hosted-environment and external/legal gates are deliberately completed through M5–M7 rather than pretending a green CI run is a public-launch decision.

## M5 — Robust MVP

Goal: harden the implemented MVP before hosting it for realistic use.

Tracking issue: #44.

- complete the real keyboard/NVDA/zoom accessibility protocol from #28;
- protect `main` and require the CI quality gate (#36);
- add a minimal password-reset flow (#37);
- add a tightly scoped booking-cancellation workflow (#38);
- add 2–3 critical-path Playwright E2E scenarios (#39).

**Milestone outcome:** the core product is a robust MVP with manual accessibility evidence and browser-level regression coverage. It is not yet considered hosted or public-pilot-ready.

## M6 — Hosted staging

Goal: run the reviewed application in a real non-production hosted environment using the simplest architecture consistent with the current code.

Tracking issue: #45.

- deploy Next.js to Vercel and a dedicated hosted Supabase project in an EU region (#40);
- apply and verify versioned migrations, Auth and Storage in the hosted environment;
- run the deployment-runbook smoke flow with synthetic accounts;
- configure a real SMTP provider and verify signup/confirmation/password recovery (#41).

**Milestone outcome:** the application is hosted over TLS and realistically testable outside localhost, without claiming public-pilot readiness.

## M7 — Public pilot readiness

Goal: resolve the final documentation, measurement, operational and external/legal launch gates before inviting real pilot users.

Tracking issue: #46.

- reconcile repository documentation with the hosted application (#42);
- decide whether to collect the privacy-minimized search/useful-result metric and implement or explicitly reject it (#43);
- resolve the outstanding human/operator/legal blockers documented by #29 and `docs/legal/PUBLIC-PILOT-READINESS.md`;
- close #11 only when the repository's own launch-readiness criteria can honestly record GO.

**Milestone outcome:** the exact hosted release can enter a small public pilot with its documented technical, operational, accessibility, privacy and legal gates resolved.

## After the MVP (not committed)

Potential future tracks include member reputation, stronger identity/residence verification, credits, payments, community-owned equipment, merchant/depot roles, collective purchasing and eventually automated lockers.

They require evidence from the pilot, not enthusiasm from the backlog.
