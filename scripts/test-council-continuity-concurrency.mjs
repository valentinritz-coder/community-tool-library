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
const users = [1, 2, 3, 4, 5, 6].map(
  (n) => `c6000000-0000-4000-8000-${String(n).padStart(12, "0")}`,
);
const community = (n) =>
  `c6100000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const rejected = (promise) =>
  promise.then(
    () => null,
    (error) => error,
  );

async function asUser(client, user) {
  await client.query("begin");
  await client.query("set local role authenticated");
  await client.query("select set_config('request.jwt.claim.sub',$1,true)", [
    user,
  ]);
}
async function waitForLock(observer, pid, fragment) {
  for (let i = 0; i < 200; i++) {
    const result = await observer.query(
      "select wait_event_type from pg_stat_activity where pid=$1 and query like $2",
      [pid, `%${fragment}%`],
    );
    if (result.rows[0]?.wait_event_type === "Lock") return;
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(`expected ${fragment} to wait on a lock`);
}
async function fixture(admin, n, active = 3, target = 3) {
  const id = community(n);
  const founding = `c6200000-0000-4000-8000-${String(n).padStart(12, "0")}`;
  const council = `c6300000-0000-4000-8000-${String(n).padStart(12, "0")}`;
  await admin.query(
    "insert into public.communities(id,name,owner_id,governance_state,council_target_size) values($1,$2,$3,'democratic',$4)",
    [id, `Continuity race ${n}`, users[5], target],
  );
  await admin.query(
    "insert into public.memberships(community_id,user_id,role,status) select $1,x,'member','active' from unnest($2::uuid[]) x",
    [id, users],
  );
  await admin.query(
    "insert into public.election_cycles(id,community_id,target_seats,status,purpose,completed_at) values($1,$2,$3,'completed','founding',now())",
    [founding, id, target],
  );
  await admin.query(
    "insert into public.election_winners(cycle_id,candidate_id,elected_in_round,approval_count) select $1,x,1,1 from unnest($2::uuid[]) x",
    [founding, users.slice(0, active)],
  );
  await admin.query(
    "insert into public.elected_councils(id,community_id,source_cycle_id,target_seats,took_office_at,nominal_term_ends_at) values($1,$2,$3,$4,now(),now()+interval '12 months')",
    [council, id, founding, target],
  );
  await admin.query(
    "insert into public.elected_council_mandates(council_id,community_id,member_id,source_cycle_id,took_office_at,nominal_term_ends_at) select $1,$2,x,$3,now(),now()+interval '12 months' from unnest($4::uuid[]) x",
    [council, id, founding, users.slice(0, active)],
  );
  return id;
}
async function completedReconstitution(admin, id, winners) {
  const cycle = (
    await admin.query(
      "insert into public.election_cycles(community_id,target_seats,status,purpose,completed_at) values($1,$2,'completed','reconstitution',now()) returning id",
      [id, winners.length],
    )
  ).rows[0].id;
  await admin.query(
    "insert into public.election_winners(cycle_id,candidate_id,elected_in_round,approval_count) select $1,x,1,1 from unnest($2::uuid[]) x",
    [cycle, winners],
  );
  return cycle;
}

const observer = db("continuity-observer"),
  first = db("continuity-first"),
  second = db("continuity-second");
try {
  await Promise.all([observer.connect(), first.connect(), second.connect()]);
  const secondPid = (await second.query("select pg_backend_pid() pid")).rows[0]
    .pid;
  await observer.query(
    `insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
    select x,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',x||'@example.test','' from unnest($1::uuid[]) x`,
    [users],
  );

  // Same mandate: the community lock serializes both calls and only one resignation is audited.
  const same = await fixture(observer, 1);
  await Promise.all([asUser(first, users[0]), asUser(second, users[0])]);
  await first.query("select public.resign_elected_council_mandate($1)", [same]);
  const duplicate = rejected(
    second.query("select public.resign_elected_council_mandate($1)", [same]),
  );
  await waitForLock(observer, secondPid, "resign_elected");
  await first.query("commit");
  assert.equal((await duplicate)?.code, "42501");
  await second.query("rollback");
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.council_continuity_history where community_id=$1 and event='resignation'",
        [same],
      )
    ).rows[0].n,
    1,
  );

  // Different councillors can resign concurrently without reviving managed governance.
  const multiple = await fixture(observer, 2);
  await Promise.all([asUser(first, users[0]), asUser(second, users[1])]);
  const a = first.query("select public.resign_elected_council_mandate($1)", [
    multiple,
  ]);
  const b = second.query("select public.resign_elected_council_mandate($1)", [
    multiple,
  ]);
  await a;
  await first.query("commit");
  await b;
  await second.query("commit");
  const state = (
    await observer.query(
      "select governance_state::text state,public.active_elected_mandate_count(id) active from public.communities where id=$1",
      [multiple],
    )
  ).rows[0];
  assert.deepEqual(state, { state: "democratic", active: 1 });

  // Opening twice and resignation-vs-open both serialize on the community row.
  const opening = await fixture(observer, 3);
  await Promise.all([asUser(first, users[3]), asUser(second, users[4])]);
  await first.query("select public.open_council_reconstitution_cycle($1)", [
    opening,
  ]);
  const doubleOpen = rejected(
    second.query("select public.open_council_reconstitution_cycle($1)", [
      opening,
    ]),
  );
  await waitForLock(observer, secondPid, "open_council");
  await first.query("commit");
  assert.equal((await doubleOpen)?.code, "23505");
  await second.query("rollback");
  const resignOpen = await fixture(observer, 4);
  await Promise.all([asUser(first, users[0]), asUser(second, users[3])]);
  await first.query("select public.resign_elected_council_mandate($1)", [
    resignOpen,
  ]);
  const openAfter = second.query(
    "select public.open_council_reconstitution_cycle($1) id",
    [resignOpen],
  );
  await waitForLock(observer, secondPid, "open_council");
  await first.query("commit");
  const opened = (await openAfter).rows[0].id;
  await second.query("commit");
  assert.equal(
    (
      await observer.query(
        "select target_seats from public.election_cycles where id=$1",
        [opened],
      )
    ).rows[0].target_seats,
    1,
  );

  // Exactly-once finalization and finalization-vs-resignation cannot overfill the target.
  const installing = await fixture(observer, 5, 1, 3);
  const cycle = await completedReconstitution(
    observer,
    installing,
    users.slice(1, 3),
  );
  await Promise.all([first.query("begin"), second.query("begin")]);
  await first.query("select public.install_reconstitution_winners($1,$2)", [
    installing,
    cycle,
  ]);
  const duplicateInstall = rejected(
    second.query("select public.install_reconstitution_winners($1,$2)", [
      installing,
      cycle,
    ]),
  );
  await waitForLock(observer, secondPid, "install_reconstitution");
  await first.query("commit");
  assert.equal((await duplicateInstall)?.code, "55000");
  await second.query("rollback");
  assert.equal(
    (
      await observer.query(
        "select public.active_elected_mandate_count($1) active",
        [installing],
      )
    ).rows[0].active,
    3,
  );

  const changingVacancy = await fixture(observer, 6, 2, 3);
  const oneWinner = await completedReconstitution(observer, changingVacancy, [
    users[2],
  ]);
  await first.query("begin");
  await asUser(second, users[0]);
  await first.query("select public.install_reconstitution_winners($1,$2)", [
    changingVacancy,
    oneWinner,
  ]);
  const resignation = second.query(
    "select public.resign_elected_council_mandate($1)",
    [changingVacancy],
  );
  await waitForLock(observer, secondPid, "resign_elected");
  await first.query("commit");
  await resignation;
  await second.query("commit");
  assert.equal(
    (
      await observer.query(
        "select public.active_elected_mandate_count($1) active",
        [changingVacancy],
      )
    ).rows[0].active,
    2,
  );
  assert.equal(
    (
      await observer.query(
        "select governance_state::text state from public.communities where id=$1",
        [changingVacancy],
      )
    ).rows[0].state,
    "democratic",
  );
  console.log("Council continuity concurrency checks passed.");
} finally {
  await Promise.allSettled([first.query("rollback"), second.query("rollback")]);
  await observer
    .query("delete from auth.users where id=any($1::uuid[])", [users])
    .catch(() => {});
  await Promise.allSettled([observer.end(), first.end(), second.end()]);
}
