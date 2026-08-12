# Pilot launch readiness checklist

> A release checklist, not a current PASS statement or legal advice. A public pilot is **NOT READY**
> while any required item is open. Record evidence, date, environment, and accountable human outside
> this repository rather than checking boxes speculatively here.

## Engineering, deployment, and data

- [ ] CI is green for the exact release commit (migrations, RLS tests, concurrency, lint, typecheck,
      unit tests, and build).
- [ ] The production frontend provider decision is recorded and the target environment/TLS/Auth URLs
      are configured and reviewed.
- [ ] Only the hosted project's browser-safe URL and publishable key are exposed to the client; secrets
      are in the authorized secret store and repository/history scanning found no credential.
- [ ] Pending versioned migrations were reviewed, backed up as appropriate, applied by the assigned
      database owner, and verified; there are no manual schema edits.
- [ ] Synthetic demo data is absent from production. If desired, it was loaded only into an explicitly
      local/demo environment using `npm run demo:local` after a clean reset.
- [ ] The deployment runbook smoke checks passed against the exact release and target.
- [ ] Backup/restore capability and limitations were verified and rehearsed for the actual Supabase
      plan; frontend rollback and forward-only DB correction ownership are understood.
- [ ] Named credential, release, database/recovery, smoke-test, incident, privacy, security, and
      moderation contacts are assigned with escalation paths and coverage.

## Accessibility gate — issue #28

- [ ] **Accessibility manual protocol (#28): NOT YET COMPLETED.** Complete and record the repository
      protocol for keyboard, NVDA, and zoom with human evidence. Automated checks do not close this gate.
- [ ] Any manual findings that block core flows are fixed and re-tested before launch.

## Privacy and legal gate — issue #29

- [ ] Every **BLOCKER — REQUIRES LEGAL REVIEW** in
      [`PUBLIC-PILOT-READINESS.md`](../legal/PUBLIC-PILOT-READINESS.md) is resolved by an authorized
      external/human reviewer; reviewed privacy notice, terms, roles, liability/insurance position,
      processor/transfer assessment, retention, rights, and acceptance approach are deployed.
- [ ] The operational privacy blockers remain reconciled with
      [`PRIVACY-DESIGN.md`](../legal/PRIVACY-DESIGN.md): named contacts/process, approved retention,
      account/community closure and Storage deletion, hosted log/backup inventory, and incident response.
- [ ] The deployed release has no unreviewed analytics/advertising tracker. Pilot metrics use authorized
      aggregates; searches remain unavailable unless separately approved minimal collection exists.

## Moderation gate — issue #30

- [ ] A synthetic report proves submission, same-community admin queue access, handling and listing-hide
      behavior; cross-community/non-admin denial remains covered by automated tests.
- [ ] A named community moderation operator monitors the queue at an agreed cadence and owns triage,
      escalation, privacy-safe notes, and incident handoff. The MVP does not provide bans, sanctions,
      automated moderation, appeals, or a generic case-management system.

## Go/no-go record

- [ ] The accountable launch owner reviewed all evidence and recorded **GO**. Until then—including while
      the manual #28 protocol or any #29 blocker is open—the only honest state is **NO-GO / NOT READY**.
