import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

import pg from "pg";

const { Client } = pg;
const databaseUrl =
  process.env.SUPABASE_LOCAL_DB_URL ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

function runSupabase(...args) {
  const result = spawnSync("npx", ["supabase", ...args], {
    encoding: "utf8",
  });
  return result;
}

async function seedLegacyCommunities(ambiguous) {
  const client = new Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    await client.query(`
      insert into auth.users (id, instance_id, aud, role, email, encrypted_password)
      values
        ('54000000-0000-4000-8000-000000000011', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'legacy-admin@example.test', ''),
        ('54000000-0000-4000-8000-000000000012', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'legacy-second-admin@example.test', '');
      insert into public.communities (id, name)
      values ('54100000-0000-4000-8000-000000000001', 'Legacy governed community');
      insert into public.memberships (community_id, user_id, role, status)
      values ('54100000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000011', 'admin', 'active');
    `);
    if (ambiguous) {
      await client.query(`
        insert into public.memberships (community_id, user_id, role, status)
        values ('54100000-0000-4000-8000-000000000001', '54000000-0000-4000-8000-000000000012', 'admin', 'active');
      `);
    }
  } finally {
    await client.end();
  }
}

async function verifyBackfill() {
  const client = new Client({ connectionString: databaseUrl });
  await client.connect();
  try {
    const result = await client.query(`
      select owner_id::text, governance_state::text,
        (select count(*)::int from public.communities where owner_id is null) as ownerless
      from public.communities
      where id = '54100000-0000-4000-8000-000000000001'
    `);
    assert.deepEqual(result.rows[0], {
      owner_id: "54000000-0000-4000-8000-000000000011",
      governance_state: "managed",
      ownerless: 0,
    });
  } finally {
    await client.end();
  }
}

function requireSuccess(result, operation) {
  assert.equal(
    result.status,
    0,
    `${operation} failed:\n${result.stdout}\n${result.stderr}`,
  );
}

try {
  requireSuccess(
    runSupabase("db", "reset", "--version", "20260813000100"),
    "reset to the historical schema",
  );
  await seedLegacyCommunities(false);
  requireSuccess(
    runSupabase("migration", "up", "--local"),
    "ownership migration",
  );
  await verifyBackfill();

  requireSuccess(
    runSupabase("db", "reset", "--version", "20260813000100"),
    "second reset to the historical schema",
  );
  await seedLegacyCommunities(true);
  const ambiguousMigration = runSupabase("migration", "up", "--local");
  assert.notEqual(
    ambiguousMigration.status,
    0,
    "ownership migration must reject multiple historical active admins",
  );
  assert.match(
    `${ambiguousMigration.stdout}\n${ambiguousMigration.stderr}`,
    /every community must have exactly one historical active admin/,
  );
  console.log(
    "Community governance migration verified: deterministic backfill succeeds and ambiguous ownership aborts.",
  );
} finally {
  requireSuccess(runSupabase("db", "reset"), "restore current local schema");
}
