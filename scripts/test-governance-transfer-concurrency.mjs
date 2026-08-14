import assert from "node:assert/strict";
import pg from "pg";

const { Client } = pg;
const connectionString =
  process.env.SUPABASE_DB_URL ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const db = (name) =>
  new Client({
    connectionString,
    application_name: name,
    connectionTimeoutMillis: 5000,
  });
const users = [1, 2, 3, 4, 5].map(
  (n) => `f6000000-0000-4000-8000-${String(n).padStart(12, "0")}`,
);
const communityId = (n) =>
  `f6100000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const rejected = (promise) =>
  promise.then(
    () => null,
    (error) => error,
  );

async function asUser(client, user = users[0]) {
  await client.query("begin");
  await client.query("set local role authenticated");
  await client.query("select set_config('request.jwt.claim.sub',$1,true)", [
    user,
  ]);
}
async function waitForLock(observer, pid, fragment) {
  for (let attempt = 0; attempt < 200; attempt++) {
    const result = await observer.query(
      "select wait_event_type from pg_stat_activity where pid=$1 and query like $2",
      [pid, `%${fragment}%`],
    );
    if (result.rows[0]?.wait_event_type === "Lock") return;
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(`expected ${fragment} to wait on a database lock`);
}
async function prepare(admin, actor, number, target = 3, candidates = 3) {
  const community = communityId(number);
  await admin.query(
    "insert into public.communities(id,name,owner_id) values($1,$2,$3)",
    [community, `Governance race ${number}`, users[0]],
  );
  await admin.query(
    "insert into public.memberships(community_id,user_id,role,status) select $1,x,'member','active' from unnest($2::uuid[]) x",
    [community, users],
  );
  await asUser(actor);
  const cycle = (
    await actor.query("select public.begin_democratic_preparation($1,$2) id", [
      community,
      target,
    ])
  ).rows[0].id;
  await actor.query("commit");
  await admin.query(
    "insert into public.election_candidacies(cycle_id,community_id,candidate_id) select $1,$2,x from unnest($3::uuid[]) x",
    [cycle, community, users.slice(0, candidates)],
  );
  return { community, cycle };
}

const observer = db("governance-observer"),
  first = db("governance-first"),
  second = db("governance-second");
try {
  await Promise.all([observer.connect(), first.connect(), second.connect()]);
  const secondPid = (await second.query("select pg_backend_pid() pid")).rows[0]
    .pid;
  await observer.query(
    `insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
    select x,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',x||'@example.test','' from unnest($1::uuid[]) x`,
    [users],
  );

  // A. commit vs commit: one transition and one initial round.
  const duplicate = await prepare(observer, first, 1);
  await Promise.all([asUser(first), asUser(second)]);
  await first.query("select public.commit_democratic_transfer($1)", [
    duplicate.community,
  ]);
  const duplicateCommit = rejected(
    second.query("select public.commit_democratic_transfer($1)", [
      duplicate.community,
    ]),
  );
  await waitForLock(observer, secondPid, "commit_democratic_transfer");
  await first.query("commit");
  assert.equal((await duplicateCommit)?.code, "55000");
  await second.query("rollback");
  assert.equal(
    (
      await observer.query(
        "select governance_state::text state from public.communities where id=$1",
        [duplicate.community],
      )
    ).rows[0].state,
    "democratic_transition",
  );
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.election_rounds where cycle_id=$1",
        [duplicate.cycle],
      )
    ).rows[0].n,
    1,
  );

  // B1. commit owns the row before cancel: cancellation waits and can never restore managed.
  const commitFirst = await prepare(observer, first, 2);
  await Promise.all([asUser(first), asUser(second)]);
  await first.query("select public.commit_democratic_transfer($1)", [
    commitFirst.community,
  ]);
  const lateCancel = rejected(
    second.query("select public.cancel_democratic_preparation($1)", [
      commitFirst.community,
    ]),
  );
  await waitForLock(observer, secondPid, "cancel_democratic_preparation");
  await first.query("commit");
  assert.equal((await lateCancel)?.code, "55000");
  await second.query("rollback");
  assert.equal(
    (
      await observer.query(
        "select governance_state::text state from public.communities where id=$1",
        [commitFirst.community],
      )
    ).rows[0].state,
    "democratic_transition",
  );

  // B2. cancel owns the row first: commitment waits, then observes managed and fails atomically.
  const cancelFirst = await prepare(observer, first, 3);
  await Promise.all([asUser(first), asUser(second)]);
  await first.query("select public.cancel_democratic_preparation($1)", [
    cancelFirst.community,
  ]);
  const lateCommit = rejected(
    second.query("select public.commit_democratic_transfer($1)", [
      cancelFirst.community,
    ]),
  );
  await waitForLock(observer, secondPid, "commit_democratic_transfer");
  await first.query("commit");
  assert.equal((await lateCommit)?.code, "55000");
  await second.query("rollback");
  assert.equal(
    (
      await observer.query(
        "select governance_state::text state from public.communities where id=$1",
        [cancelFirst.community],
      )
    ).rows[0].state,
    "managed",
  );
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.election_rounds where cycle_id=$1",
        [cancelFirst.cycle],
      )
    ).rows[0].n,
    0,
  );

  // C. commit vs target mutation: the frozen target wins and the waiting mutation is rejected.
  const targetRace = await prepare(observer, first, 4);
  await Promise.all([asUser(first), asUser(second)]);
  await first.query("select public.commit_democratic_transfer($1)", [
    targetRace.community,
  ]);
  const lateTarget = rejected(
    second.query("select public.change_preparation_council_target($1,5)", [
      targetRace.community,
    ]),
  );
  await waitForLock(observer, secondPid, "change_preparation_council_target");
  await first.query("commit");
  assert.equal((await lateTarget)?.code, "55000");
  await second.query("rollback");
  const targets = (
    await observer.query(
      "select c.council_target_size,e.target_seats from public.communities c join public.election_cycles e on e.id=c.active_election_cycle_id where c.id=$1",
      [targetRace.community],
    )
  ).rows[0];
  assert.deepEqual(targets, { council_target_size: 3, target_seats: 3 });

  // E1. stand owns the cycle lock before commit: the committed candidacy is in the snapshot.
  const standRace = await prepare(observer, first, 5);
  await asUser(first, users[3]);
  await first.query("select public.stand_for_election($1)", [standRace.cycle]);
  await asUser(second);
  const commitAfterStand = second.query(
    "select public.commit_democratic_transfer($1)",
    [standRace.community],
  );
  await waitForLock(observer, secondPid, "commit_democratic_transfer");
  await first.query("commit");
  await commitAfterStand;
  await second.query("commit");
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.election_candidates where cycle_id=$1",
        [standRace.cycle],
      )
    ).rows[0].n,
    4,
  );

  // E2. commit/freeze owns the lock before withdrawal: late withdrawal fails, snapshot is immutable.
  const withdrawRace = await prepare(observer, first, 6, 3, 4);
  await asUser(first);
  await first.query("select public.commit_democratic_transfer($1)", [
    withdrawRace.community,
  ]);
  await asUser(second, users[3]);
  const lateWithdrawal = rejected(
    second.query("select public.withdraw_election_candidacy($1)", [
      withdrawRace.cycle,
    ]),
  );
  await waitForLock(observer, secondPid, "withdraw_election_candidacy");
  await first.query("commit");
  assert.equal((await lateWithdrawal)?.code, "55000");
  await second.query("rollback");
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.election_candidates where cycle_id=$1",
        [withdrawRace.cycle],
      )
    ).rows[0].n,
    4,
  );

  // F. concurrent member retries after terminal failure create exactly one new open cycle.
  const retryRace = await prepare(observer, first, 7);
  await asUser(first);
  await first.query("select public.commit_democratic_transfer($1)", [
    retryRace.community,
  ]);
  await first.query("commit");
  await observer.query(
    "update public.election_cycles set status='failed',completed_at=now() where id=$1",
    [retryRace.cycle],
  );
  await Promise.all([asUser(first, users[1]), asUser(second, users[2])]);
  await first.query("select public.open_transition_retry_cycle($1)", [
    retryRace.community,
  ]);
  const duplicateRetry = rejected(
    second.query("select public.open_transition_retry_cycle($1)", [
      retryRace.community,
    ]),
  );
  await waitForLock(observer, secondPid, "open_transition_retry_cycle");
  await first.query("commit");
  assert.equal((await duplicateRetry)?.code, "55000");
  await second.query("rollback");
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.election_cycles where community_id=$1 and status='candidacy'",
        [retryRace.community],
      )
    ).rows[0].n,
    1,
  );

  // D. concurrent installation materializes one council and one copy of each mandate.
  await observer.query(
    "update public.election_cycles set status='completed',completed_at=now() where id=$1",
    [duplicate.cycle],
  );
  await observer.query(
    "insert into public.election_winners(cycle_id,candidate_id,elected_in_round,approval_count) select $1,x,1,1 from unnest($2::uuid[]) x",
    [duplicate.cycle, users.slice(0, 3)],
  );
  await Promise.all([first.query("begin"), second.query("begin")]);
  await first.query("select public.install_elected_council($1,$2)", [
    duplicate.community,
    duplicate.cycle,
  ]);
  const duplicateInstall = rejected(
    second.query("select public.install_elected_council($1,$2)", [
      duplicate.community,
      duplicate.cycle,
    ]),
  );
  await waitForLock(observer, secondPid, "install_elected_council");
  await first.query("commit");
  assert.equal((await duplicateInstall)?.code, "55000");
  await second.query("rollback");
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.elected_councils where community_id=$1",
        [duplicate.community],
      )
    ).rows[0].n,
    1,
  );
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.elected_council_mandates where community_id=$1",
        [duplicate.community],
      )
    ).rows[0].n,
    3,
  );
  console.log(
    "Governance transfer concurrency tests passed: commit/cancel/target/candidacy/retry/install races serialize deterministically.",
  );
} finally {
  await first.query("rollback").catch(() => {});
  await second.query("rollback").catch(() => {});
  await observer
    .query(
      "delete from public.communities where id::text like 'f6100000-0000-4000-8000-%'",
    )
    .catch(() => {});
  await observer
    .query("delete from auth.users where id=any($1::uuid[])", [users])
    .catch(() => {});
  await Promise.all(
    [observer.end(), first.end(), second.end()].map((p) => p.catch(() => {})),
  );
}
