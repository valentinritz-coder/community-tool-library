# Local Supabase development

This repository uses the workflow validated for ADR 0003 for versioned domain migrations, Row
Level Security (RLS), and private object storage.

## Prerequisites

- Node.js 20.9 or later and npm;
- Docker Engine or Docker Desktop running;
- ports 54320–54324 available.

The Supabase CLI is pinned as a development dependency, so no global CLI installation is required.

## Start from a clean clone

```bash
npm ci
cp .env.example .env.local
npm run supabase:start
npm run supabase:reset
npm run supabase:test
```

`supabase:start` downloads and starts the local containers and prints the local API URL and keys.
Copy the printed **publishable** key into `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` in `.env.local`.
The local URL defaults to the value already shown in `.env.example`. Do not put a service-role key
in a `NEXT_PUBLIC_` variable, source code, documentation, fixtures, or commits.

`supabase:reset` recreates the local database and applies every file in
`supabase/migrations` in timestamp order. Run it after pulling migrations or to verify that the
schema is reproducible. Create later migrations with `npm run supabase -- migration new <name>`;
never edit an already-shared migration. Inspect local services with `npm run supabase:status` and
stop them with `npm run supabase:stop`.

## Authorization tests

`npm run supabase:test` runs pgTAP inside the local database. The tests switch to the actual
`authenticated` database role and set synthetic JWT claims. Community, item, and Storage tests use
real captured community and item IDs to exercise owner, active-member, pending-member, non-member,
and cross-community boundaries. They do not use `service_role` for actions under test.

The item migration replaces the proof's owner-folder policies. An object path is the item's UUID
and its single declared photo filename. Storage policies resolve that UUID to `items`, then use the
authenticated item's owner for writes and active community membership for reads. A guessed path is
therefore not sufficient authorization. The bucket remains private and keeps its JPEG, PNG, WebP,
and 5 MB restrictions.

## Configuration boundaries

`.env.example` documents only browser-safe connection settings. Hosted values belong in the
deployment secret manager and local values belong in ignored `.env.local`. Administrative database
passwords and Supabase service-role keys are server-only credentials and are not required by this
workflow.
