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
  handoverRace: "c3000000-0000-4000-8000-000000000001",
  handoverWins: "c3000000-0000-4000-8000-000000000002",
  cancellationWins: "c3000000-0000-4000-8000-000000000003",
  decisionRace: "c3000000-0000-4000-8000-000000000004",
};

function client(applicationName) {
  return new Client({
    connectionString,
    application_name: applicationName,
    connectionTimeoutMillis: 5_000,
  });
}

async function waitUntilBlocked(observer, processId, queryPattern, scenario) {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline) {
    const result = await observer.query(
      `select wait_event_type, wait_event
       from pg_stat_activity
       where pid = $1 and query like $2`,
      [processId, `%${queryPattern}%`],
    );
    if (result.rows[0]?.wait_event_type === "Lock") return result.rows[0];
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(`${scenario}: the second session did not wait on a lock`);
}

async function beginAs(clientConnection, userId) {
  await clientConnection.query("begin");
  await clientConnection.query("set local role authenticated");
  await clientConnection.query(
    "select set_config('request.jwt.claim.sub', $1, true)",
    [userId],
  );
}

async function runRace({
  observer,
  firstSession,
  secondSession,
  bookingId,
  scenario,
  firstUserId = ids.owner,
  secondUserId = ids.borrower,
  firstQuery,
  firstExpectedStatus,
  secondQuery,
  secondQueryPattern,
  secondErrorMessage,
  finalStatus,
}) {
  await beginAs(firstSession, firstUserId);
  await beginAs(secondSession, secondUserId);
  const secondPid = (
    await secondSession.query("select pg_backend_pid() as pid")
  ).rows[0].pid;

  const first = await firstSession.query(firstQuery, [bookingId]);
  assert.equal(
    first.rows[0].status,
    firstExpectedStatus,
    `${scenario}: winner`,
  );

  const secondOutcome = secondSession.query(secondQuery, [bookingId]).then(
    (result) => ({ result }),
    (error) => ({ error }),
  );

  const wait = await waitUntilBlocked(
    observer,
    secondPid,
    secondQueryPattern,
    scenario,
  );
  assert.equal(wait.wait_event_type, "Lock", `${scenario}: lock wait`);
  await firstSession.query("commit");

  const second = await secondOutcome;
  assert.equal(second.result, undefined, `${scenario}: loser must not succeed`);
  assert.equal(second.error?.code, "55000", `${scenario}: loser SQLSTATE`);
  assert.match(
    second.error?.message ?? "",
    secondErrorMessage,
    `${scenario}: loser state error`,
  );
  await secondSession.query("rollback");

  const final = await observer.query(
    "select status::text from public.bookings where id = $1",
    [bookingId],
  );
  assert.equal(final.rows[0].status, finalStatus, `${scenario}: final status`);
  console.log(`Concurrent lifecycle test passed: ${scenario}.`);
}

const observer = client("lifecycle-observer");
const firstSession = client("lifecycle-first");
const secondSession = client("lifecycle-second");
let observerConnected = false;
let firstConnected = false;
let secondConnected = false;

try {
  await observer.connect();
  observerConnected = true;
  await firstSession.connect();
  firstConnected = true;
  await secondSession.connect();
  secondConnected = true;

  await observer.query(
    `insert into auth.users (id, instance_id, aud, role, email, encrypted_password) values
       ($1, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'concurrent-owner@example.test', ''),
       ($2, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'concurrent-borrower@example.test', '')`,
    [ids.owner, ids.borrower],
  );
  await observer.query(
    "insert into public.communities (id, name, owner_id) values ($1, 'Concurrency community', $2)",
    [ids.community, ids.owner],
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
    `insert into public.availabilities (item_id, start_date, end_date)
     values ($1, '2026-12-01', '2026-12-31')`,
    [ids.item],
  );
  await observer.query(
    `insert into public.bookings (id, item_id, borrower_id, start_date, end_date, status) values
       ($1, $5, $6, '2026-12-01', '2026-12-01', 'accepted'),
       ($2, $5, $6, '2026-12-02', '2026-12-02', 'accepted'),
       ($3, $5, $6, '2026-12-03', '2026-12-03', 'accepted'),
       ($4, $5, $6, '2026-12-04', '2026-12-04', 'requested')`,
    [
      ids.handoverRace,
      ids.handoverWins,
      ids.cancellationWins,
      ids.decisionRace,
      ids.item,
      ids.borrower,
    ],
  );

  await runRace({
    observer,
    firstSession,
    secondSession,
    bookingId: ids.handoverRace,
    scenario: "handover versus handover serializes and exactly one succeeds",
    firstQuery: "select status::text from public.record_handover($1)",
    firstExpectedStatus: "checked_out",
    secondQuery: "select status::text from public.record_handover($1)",
    secondQueryPattern: "record_handover",
    secondErrorMessage: /not in the required state/,
    finalStatus: "checked_out",
  });

  await runRace({
    observer,
    firstSession,
    secondSession,
    bookingId: ids.handoverWins,
    scenario: "handover wins against cancellation",
    firstQuery: "select status::text from public.record_handover($1)",
    firstExpectedStatus: "checked_out",
    secondQuery: "select status::text from public.cancel_booking($1)",
    secondQueryPattern: "cancel_booking",
    secondErrorMessage: /cannot be cancelled after handover/,
    finalStatus: "checked_out",
  });

  await runRace({
    observer,
    firstSession,
    secondSession,
    bookingId: ids.cancellationWins,
    scenario: "cancellation wins against handover",
    firstQuery: "select status::text from public.cancel_booking($1)",
    firstExpectedStatus: "cancelled",
    secondQuery: "select status::text from public.record_handover($1)",
    secondQueryPattern: "record_handover",
    secondErrorMessage: /not in the required state/,
    finalStatus: "cancelled",
  });

  await runRace({
    observer,
    firstSession,
    secondSession,
    bookingId: ids.decisionRace,
    scenario: "requested cancellation wins against acceptance",
    firstUserId: ids.borrower,
    secondUserId: ids.owner,
    firstQuery: "select status::text from public.cancel_booking($1)",
    firstExpectedStatus: "cancelled",
    secondQuery:
      "select status::text from public.decide_booking($1, 'accepted')",
    secondQueryPattern: "decide_booking",
    secondErrorMessage: /already been decided/,
    finalStatus: "cancelled",
  });
} finally {
  if (firstConnected)
    await firstSession.query("rollback").catch(() => undefined);
  if (secondConnected)
    await secondSession.query("rollback").catch(() => undefined);
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
    firstConnected ? firstSession.end().catch(() => undefined) : undefined,
    secondConnected ? secondSession.end().catch(() => undefined) : undefined,
    observerConnected ? observer.end().catch(() => undefined) : undefined,
  ]);
}
