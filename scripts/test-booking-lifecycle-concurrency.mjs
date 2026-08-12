import assert from "node:assert/strict";

import pg from "pg";

const { Client } = pg;
const connectionString =
  process.env.SUPABASE_DB_URL ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

const ids = {
  owner: "c0000000-0000-4000-8000-000000000001",
  borrower: "c0000000-0000-4000-8000-000000000002",
  community: "c1000000-0000-4000-8000-000000000001",
  item: "c2000000-0000-4000-8000-000000000001",
  booking: "c3000000-0000-4000-8000-000000000001",
};

function client(applicationName) {
  return new Client({
    connectionString,
    application_name: applicationName,
    connectionTimeoutMillis: 5_000,
  });
}

async function waitUntilSecondSessionIsBlocked(observer, processId) {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline) {
    const result = await observer.query(
      `select wait_event_type, wait_event
       from pg_stat_activity
       where pid = $1 and query like '%record_handover%'`,
      [processId],
    );
    if (result.rows[0]?.wait_event_type === "Lock") return result.rows[0];
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(
    "The second handover session did not wait on the booking row lock",
  );
}

async function setParticipant(clientConnection, userId) {
  await clientConnection.query("begin");
  await clientConnection.query("set local role authenticated");
  await clientConnection.query(
    "select set_config('request.jwt.claim.sub', $1, true)",
    [userId],
  );
}

const observer = client("lifecycle-observer");
const ownerSession = client("lifecycle-owner");
const borrowerSession = client("lifecycle-borrower");
let observerConnected = false;
let ownerConnected = false;
let borrowerConnected = false;

try {
  await observer.connect();
  observerConnected = true;
  await ownerSession.connect();
  ownerConnected = true;
  await borrowerSession.connect();
  borrowerConnected = true;

  await observer.query("begin");
  await observer.query(
    `insert into auth.users (id, instance_id, aud, role, email, encrypted_password) values
       ($1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'concurrent-owner@example.test', ''),
       ($2, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'concurrent-borrower@example.test', '')`,
    [ids.owner, ids.borrower],
  );
  await observer.query(
    "insert into public.communities (id, name) values ($1, 'Concurrency community')",
    [ids.community],
  );
  await observer.query(
    `insert into public.memberships (community_id, user_id, role, status) values
       ($1, $2, 'member', 'active'), ($1, $3, 'member', 'active')`,
    [ids.community, ids.owner, ids.borrower],
  );
  await observer.query(
    `insert into public.items (id, community_id, owner_id, name, category, description, photo_path, is_free, photo_uploaded)
       values ($1, $2, $3, 'Concurrency drill', 'small_diy', 'Synthetic concurrent fixture', $4, true, true)`,
    [ids.item, ids.community, ids.owner, `${ids.item}/photo.jpg`],
  );
  await observer.query(
    `insert into public.bookings (id, item_id, borrower_id, start_date, end_date, status)
       values ($1, $2, $3, '2026-12-01', '2026-12-01', 'accepted')`,
    [ids.booking, ids.item, ids.borrower],
  );
  await observer.query("commit");

  await setParticipant(ownerSession, ids.owner);
  await setParticipant(borrowerSession, ids.borrower);
  const borrowerPid = (
    await borrowerSession.query("select pg_backend_pid() as pid")
  ).rows[0].pid;

  const first = await ownerSession.query(
    "select status::text from public.record_handover($1)",
    [ids.booking],
  );
  assert.equal(first.rows[0].status, "checked_out");

  const secondOutcome = borrowerSession
    .query("select status::text from public.record_handover($1)", [ids.booking])
    .then(
      (result) => ({ result }),
      (error) => ({ error }),
    );

  const wait = await waitUntilSecondSessionIsBlocked(observer, borrowerPid);
  assert.equal(wait.wait_event_type, "Lock");
  await ownerSession.query("commit");

  const second = await secondOutcome;
  assert.equal(
    second.result,
    undefined,
    "the second handover must not succeed",
  );
  assert.equal(second.error?.code, "55000");
  assert.match(second.error?.message ?? "", /not in the required state/);
  await borrowerSession.query("rollback");

  const final = await observer.query(
    "select status::text from public.bookings where id = $1",
    [ids.booking],
  );
  assert.equal(final.rows[0].status, "checked_out");
  console.log(
    "Concurrent lifecycle test passed: two sessions contended for one booking; exactly one handover succeeded.",
  );
} finally {
  if (ownerConnected)
    await ownerSession.query("rollback").catch(() => undefined);
  if (borrowerConnected)
    await borrowerSession.query("rollback").catch(() => undefined);
  if (observerConnected) {
    await observer
      .query("delete from public.communities where id = $1", [ids.community])
      .catch(() => undefined);
    await observer
      .query("delete from auth.users where id in ($1, $2)", [
        ids.owner,
        ids.borrower,
      ])
      .catch(() => undefined);
  }
  await Promise.all([
    ownerConnected ? ownerSession.end().catch(() => undefined) : undefined,
    borrowerConnected
      ? borrowerSession.end().catch(() => undefined)
      : undefined,
    observerConnected ? observer.end().catch(() => undefined) : undefined,
  ]);
}
