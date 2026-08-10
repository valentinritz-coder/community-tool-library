# Local Supabase development

This repository contains a deliberately minimal technical proof for ADR 0003. It validates the
local migration, Row Level Security (RLS), and private object-storage workflow; it is not an MVP
domain model.

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

## Security proof

The single migration creates only two validation surfaces:

1. `public.rls_validation_notes`, an explicitly temporary-style proof table whose rows are readable
   and insertable only when `owner_id = auth.uid()`;
2. a private `item-photos` bucket that accepts JPEG, PNG, and WebP images. Authenticated users may
   insert and read only object names beginning with `<auth.uid()>/`.

`npm run supabase:test` runs pgTAP inside the local database. The tests switch to the actual
`authenticated` database role and set synthetic JWT claims, then observe successful owner actions,
invisible rows for another user, and RLS errors for forbidden inserts. Storage tests likewise prove
an allowed upload/read and denied cross-user read/upload. They do not use `service_role` to perform
the actions under test.

These path policies are an authorization pattern, not the final item-photo design. A future item
issue must connect paths to item/community permissions and decide update/delete semantics. Full
authentication, users, communities, memberships, items, and application-side Supabase integration
are intentionally outside this proof.

## Configuration boundaries

`.env.example` documents only browser-safe connection settings. Hosted values belong in the
deployment secret manager and local values belong in ignored `.env.local`. Administrative database
passwords and Supabase service-role keys are server-only credentials and are not required by this
workflow.
