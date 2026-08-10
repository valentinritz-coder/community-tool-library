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

## After the MVP (not committed)

Potential future tracks include member reputation, stronger identity/residence verification, credits, payments, community-owned equipment, merchant/depot roles, collective purchasing and eventually automated lockers.

They require evidence from the pilot, not enthusiasm from the backlog.
