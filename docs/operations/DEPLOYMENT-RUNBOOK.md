# Deployment and pilot operations runbook

> Architecture as implemented for issue #31. This is an operator procedure, not evidence that the
> unresolved accessibility, legal, privacy, provider, or ownership gates have passed.

## Environments and prerequisites

Use Node.js 20.9 or later, npm, the repository-pinned Supabase CLI, Docker for local validation, and
the PostgreSQL `psql` client for operator metrics/recovery checks.
A target deployment requires a Supabase project, a user permitted to link/push migrations and inspect
backups, and access to the chosen frontend environment and its environment-variable manager.

**DEPLOYMENT PROVIDER DECISION REQUIRED:** this repository defines a Next.js application but does not
select a production frontend provider. The provider must support Node/Next.js 16, TLS, immutable or
identifiable releases, rollback to a prior frontend artifact, and server-side build configuration.
Do not infer that any particular vendor has been approved.

| Variable/credential                    | Use                                                      | Local                                             | Production                                                           | Classification and configuration location                                                                           |
| -------------------------------------- | -------------------------------------------------------- | ------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `NEXT_PUBLIC_SUPABASE_URL`             | Browser API/Auth/Storage endpoint                        | Local CLI URL in ignored `.env.local`             | Hosted project URL                                                   | Public/client-safe; frontend environment manager                                                                    |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Browser authorization key; RLS still enforces access     | Local CLI publishable key in ignored `.env.local` | Target project's publishable key                                     | Public/client-safe; frontend environment manager                                                                    |
| Supabase access token/login            | CLI project access                                       | Not needed for a local stack                      | Needed by release operator/CI if automated                           | Secret/server-only; operator or CI secret store, never frontend                                                     |
| Target database password               | Link/push or recovery when requested by Supabase tooling | Local CLI default only                            | Target-specific credential                                           | Secret/server-only; operator or CI secret store                                                                     |
| Service-role key                       | Privileged administration (not used by the current app)  | Not required                                      | Do not configure unless a separately reviewed server-only use exists | Secret/server-only; never `NEXT_PUBLIC_`                                                                            |
| `OPERATOR_DATABASE_URL`                | Read-only pilot aggregate SQL via `psql`                 | Local DB URL only for local validation            | Short-lived target read-only connection string                       | Secret/server/operator-only; authorized operator shell or approved secret mechanism, never frontend/`NEXT_PUBLIC_*` |

Local values printed by `supabase start` are disposable development credentials, not production
secrets. `.env.local` is ignored; `.env.example` contains placeholders only.

## Versioned database release

1. From the reviewed commit, run the complete validation sequence below against a clean local stack.
2. Review ordered files with `npm run supabase -- migration list --local`; migration timestamps are
   the source of ordering. Shared migrations are immutable: create a later corrective migration with
   `npm run supabase -- migration new <name>`, and never make an unversioned Studio schema edit.
3. Authenticate and link explicitly: `npm run supabase -- login`, then
   `npm run supabase -- link --project-ref <TARGET_PROJECT_REF>`. Independently verify the displayed
   target is the intended environment.
4. Preview local/remote state with `npm run supabase -- migration list --linked` and
   `npm run supabase -- db push --linked --dry-run`. Review every pending filename and its operational
   effect before continuing.
5. Confirm backup/recovery ownership and an appropriate target backup exist, then apply with
   `npm run supabase -- db push --linked`.
6. Re-run `migration list --linked`, verify no unexpected pending versions, inspect Supabase logs for
   migration errors, and run the smoke checks with synthetic pilot accounts.

Before deploying the frontend, verify the target project's hosted Auth settings—not the local defaults
in `supabase/config.toml`—against the selected frontend domain: Site URL, every permitted redirect URL,
whether pilot signup is enabled, and whether email confirmation is required/configured. Final values
remain an environment/operator decision; local URLs must not be copied into hosted production settings.
The exact HTTPS `<application-origin>/reset-password` URL must be in the hosted Auth redirect
allow-list; the application constructs that fixed route from its current browser origin.

Never use `supabase db reset` on a hosted production database. It is a destructive local
reproducibility command, not a rollback mechanism.

## Application release and smoke checks

Build the reviewed SHA with `npm ci && npm run build`, configure the two browser-safe variables for
the exact target Supabase project, and deploy the resulting Next.js release using the chosen
provider's documented immutable-release process. Record the application SHA, migration versions,
operator, and smoke-check result outside the repository.

After deployment, keep this check short:

1. Load over TLS at mobile and desktop widths; sign up/sign in with a synthetic smoke account.
2. Create or request membership in the designated smoke community; have its admin approve it and
   confirm a pending/non-member cannot browse inventory.
3. As an active member, browse inventory and create/publish a permitted listing with availability.
4. As another member, request an available booking; as owner accept it. Confirm contact appears only
   to those participants while accepted, not to an admin/non-participant, and disappears after handover.
5. Record handover, optional before evidence, return and optional after evidence; confirm history and
   private evidence access for participants and same-community admin only.
6. Submit a synthetic listing report; confirm the same-community admin queue can handle it and that a
   different-community admin cannot read it.

Delete or clearly label smoke data according to the approved pilot retention procedure. Do not use
real personal data in validation.

## Rollback and recovery

- **Frontend:** stop or roll back to the last known-good immutable frontend release. This does not
  reverse writes made by the newer version; assess their compatibility before rollback.
- **Database:** there is no automatic down-migration facility. Prefer a reviewed, forward-only
  corrective migration. A destructive restore requires the recovery owner to evaluate downtime,
  Storage/Auth consistency, and data created since the backup; preserve that data where required.
- **Backups:** capabilities and retention depend on the selected Supabase plan and hosted settings.
  Verify and rehearse them for the actual project before launch; the repository cannot promise a
  point-in-time recovery window.
- **Incident:** restrict or pause the affected release, preserve necessary evidence, contact the
  security/privacy owners, and document operator decisions. Never improvise `db reset` in production.

## Required operational ownership

Assign named humans before pilot launch, even though this repository names only functional roles:

| Responsibility                                               | Required role                 |
| ------------------------------------------------------------ | ----------------------------- |
| Own production credentials and provider access               | Credential owner              |
| Review CI and authorize a release                            | Release owner                 |
| Apply/review migrations and backup readiness                 | Database/recovery owner       |
| Execute and record smoke checks                              | Pilot operator                |
| Triage availability/security incidents                       | Incident lead                 |
| Monitor and handle the moderation queue on an agreed cadence | Community moderation operator |
| Receive/escalate privacy requests and security notifications | Privacy and security contacts |

No release proceeds when one individual is implicitly assumed to own an unassigned role.

## Local synthetic demo (never production)

The demo is deliberately excluded from `supabase/seed.sql`, so `supabase db reset` remains a clean
schema/test reset. To recreate it:

```bash
npm ci
npm run supabase:start
npm run supabase:reset
npm run demo:local
```

`demo:local` accepts only a loopback URL on local port 54322, refuses a second load, and verifies its
expected counts. Its fixed UUIDs and `example.test` identities are synthetic; availability and booking
dates are calculated from `current_date`. The common local-only password is `demo-local-only`.
The dataset represents an admin, three active members, one pending member, four category/pricing
listings, availability, requested/accepted/refused/checked-out/returned bookings, before/after
condition metadata, and one open report. Photo paths/evidence records are representative database
metadata; the SQL does not install image binaries, so use synthetic uploads when exercising image
rendering.

**WARNING:** never copy, pipe, or execute `supabase/demo.sql` against a hosted or production database.
The loader guard is defense in depth, not permission to weaken operational target checks.
