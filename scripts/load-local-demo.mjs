import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

import pg from "pg";

const { Client } = pg;
const connectionString =
  process.env.SUPABASE_LOCAL_DB_URL ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const target = new URL(connectionString);

assert.ok(
  ["127.0.0.1", "localhost", "::1"].includes(target.hostname),
  "Refusing to load demo data: SUPABASE_LOCAL_DB_URL must use a loopback host.",
);
assert.equal(
  target.port,
  "54322",
  "Refusing to load demo data: the target must use the repository's local Supabase DB port 54322.",
);

const sql = await readFile(
  new URL("../supabase/demo.sql", import.meta.url),
  "utf8",
);
const client = new Client({ connectionString, connectionTimeoutMillis: 5_000 });

try {
  await client.connect();
  const database = await client.query("select current_database() as name");
  assert.equal(database.rows[0]?.name, "postgres");

  await client.query(sql);
  const result = await client.query(`
    select
      (select count(*)::int from public.communities where id = 'd1000000-0000-4000-8000-000000000001') as communities,
      (select count(*)::int from public.memberships where community_id = 'd1000000-0000-4000-8000-000000000001') as memberships,
      (select count(*)::int from public.items where community_id = 'd1000000-0000-4000-8000-000000000001') as items,
      (select count(*)::int from public.bookings b join public.items i on i.id = b.item_id where i.community_id = 'd1000000-0000-4000-8000-000000000001') as bookings,
      (select count(*)::int from public.condition_reports where booking_id = 'd4000000-0000-4000-8000-000000000004') as evidence,
      (select count(*)::int from public.moderation_reports where community_id = 'd1000000-0000-4000-8000-000000000001') as reports
  `);
  assert.deepEqual(result.rows[0], {
    communities: 1,
    memberships: 5,
    items: 4,
    bookings: 5,
    evidence: 2,
    reports: 1,
  });
  console.log(
    "Local synthetic demo loaded and verified (1 community, 5 memberships, 4 items, 5 bookings, 2 evidence records, 1 report).",
  );
} finally {
  await client.end().catch(() => undefined);
}
