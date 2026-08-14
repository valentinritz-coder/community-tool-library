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
const ids = {
  community: "e1000000-0000-4000-8000-000000000001",
  cycle: "e2000000-0000-4000-8000-000000000001",
  round: "e3000000-0000-4000-8000-000000000001",
  users: [1, 2, 3, 4].map(
    (n) => `e0000000-0000-4000-8000-${String(n).padStart(12, "0")}`,
  ),
};

async function asUser(client, user) {
  await client.query("begin");
  await client.query("set local role authenticated");
  await client.query("select set_config('request.jwt.claim.sub',$1,true)", [
    user,
  ]);
}

async function waitForLock(observer, pid, queryFragment) {
  for (let attempt = 0; attempt < 200; attempt++) {
    const result = await observer.query(
      "select wait_event_type from pg_stat_activity where pid=$1 and query like $2",
      [pid, `%${queryFragment}%`],
    );
    if (result.rows[0]?.wait_event_type === "Lock") return;
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(`expected ${queryFragment} to wait on a database lock`);
}

const observer = db("election-observer"),
  first = db("election-first"),
  second = db("election-second");
try {
  await Promise.all([observer.connect(), first.connect(), second.connect()]);
  const firstPid = (await first.query("select pg_backend_pid() pid")).rows[0]
    .pid;
  const secondPid = (await second.query("select pg_backend_pid() pid")).rows[0]
    .pid;
  await observer.query(
    `insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
    select x,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',x||'@example.test','' from unnest($1::uuid[]) x`,
    [ids.users],
  );
  await observer.query(
    "insert into public.communities(id,name,owner_id,governance_state) values($1,'Concurrent election',$2,'democratic_transition')",
    [ids.community, ids.users[0]],
  );
  await observer.query(
    "insert into public.memberships(community_id,user_id,role,status) select $1,x,'member','active' from unnest($2::uuid[]) x",
    [ids.community, ids.users],
  );
  await observer.query(
    "insert into public.election_cycles(id,community_id,target_seats,status,frozen_at) values($1,$2,3,'voting',now())",
    [ids.cycle, ids.community],
  );
  await observer.query(
    "insert into public.election_candidacies(cycle_id,community_id,candidate_id) select $1,$2,x from unnest($3::uuid[]) x",
    [ids.cycle, ids.community, ids.users.slice(0, 3)],
  );
  await observer.query(
    "insert into public.election_candidates(cycle_id,community_id,candidate_id) select $1,$2,x from unnest($3::uuid[]) x",
    [ids.cycle, ids.community, ids.users.slice(0, 3)],
  );
  await observer.query(
    "insert into public.election_electorate(cycle_id,community_id,voter_id) select $1,$2,x from unnest($3::uuid[]) x",
    [ids.cycle, ids.community, ids.users],
  );
  await observer.query(
    "insert into public.election_rounds(id,cycle_id,round_number,seats_available,electorate_count,quorum_threshold) values($1,$2,1,3,4,3)",
    [ids.round, ids.cycle],
  );
  await observer.query(
    "insert into public.election_round_candidates(round_id,candidate_id) select $1,x from unnest($2::uuid[]) x",
    [ids.round, ids.users.slice(0, 3)],
  );

  // Two concurrent submissions by one voter serialize on the unique (round, voter) constraint.
  await Promise.all([
    asUser(first, ids.users[0]),
    asUser(second, ids.users[0]),
  ]);
  await first.query(
    "select public.submit_election_ballot($1,array[]::uuid[])",
    [ids.round],
  );
  const duplicate = second
    .query("select public.submit_election_ballot($1,array[]::uuid[])", [
      ids.round,
    ])
    .then(
      () => null,
      (e) => e,
    );
  await first.query("commit");
  const duplicateError = await duplicate;
  assert.equal(
    duplicateError?.code,
    "23505",
    "concurrent duplicate ballot is rejected by the database",
  );
  await second.query("rollback");

  for (let i = 1; i < 3; i++) {
    await asUser(first, ids.users[i]);
    await first.query("select public.submit_election_ballot($1,$2::uuid[])", [
      ids.round,
      ids.users.slice(0, 3),
    ]);
    await first.query("commit");
  }

  await observer.query("select public.close_election_round($1)", [ids.round]);
  // Internal finalizers lock the closed authoritative round; no community role can invoke them.
  await Promise.all([first.query("begin"), second.query("begin")]);
  const winner = await first.query(
    "select public.finalize_election_round($1)::text status",
    [ids.round],
  );
  assert.equal(winner.rows[0].status, "completed");
  const loser = second
    .query("select public.finalize_election_round($1)", [ids.round])
    .then(
      () => null,
      (e) => e,
    );
  await first.query("commit");
  const loserError = await loser;
  assert.equal(
    loserError?.code,
    "55000",
    "concurrent second finalization is rejected",
  );
  await second.query("rollback");
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.election_winners where cycle_id=$1",
        [ids.cycle],
      )
    ).rows[0].n,
    3,
  );
  console.log(
    "Concurrent election tests passed: duplicate ballot and exactly-once finalization.",
  );

  // A candidacy that owns the cycle lock before freeze is included atomically.
  const candidacyCycle = (
    await observer.query(
      "insert into public.election_cycles(community_id,target_seats) values($1,3) returning id",
      [ids.community],
    )
  ).rows[0].id;
  await observer.query(
    "insert into public.election_candidacies(cycle_id,community_id,candidate_id) select $1,$2,x from unnest($3::uuid[]) x",
    [candidacyCycle, ids.community, ids.users.slice(0, 3)],
  );
  await asUser(first, ids.users[3]);
  await first.query("select public.stand_for_election($1)", [candidacyCycle]);
  await second.query("begin");
  const freezeAfterCandidacy = second.query(
    "select public.freeze_election_cycle($1) round_id",
    [candidacyCycle],
  );
  await waitForLock(observer, secondPid, "freeze_election_cycle");
  await first.query("commit");
  const candidacyRound = (await freezeAfterCandidacy).rows[0].round_id;
  await second.query("commit");
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.election_candidates where cycle_id=$1",
        [candidacyCycle],
      )
    ).rows[0].n,
    4,
    "candidacy committed before freeze is present in the snapshot",
  );

  // A ballot holding the round share lock commits before closure and is counted consistently.
  await asUser(first, ids.users[0]);
  await first.query(
    "select public.submit_election_ballot($1,array[]::uuid[])",
    [candidacyRound],
  );
  await second.query("begin");
  const closeAfterBallot = second.query(
    "select public.close_election_round($1)",
    [candidacyRound],
  );
  await waitForLock(observer, secondPid, "close_election_round");
  await first.query("commit");
  await closeAfterBallot;
  await second.query("commit");
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.election_ballots where round_id=$1",
        [candidacyRound],
      )
    ).rows[0].n,
    1,
    "ballot committed before closure remains in the authoritative set",
  );

  // Freeze owning the cycle lock wins over a later withdrawal; the snapshot stays coherent.
  await observer.query("select public.finalize_election_round($1)", [
    candidacyRound,
  ]);
  const withdrawalCycle = (
    await observer.query(
      "insert into public.election_cycles(community_id,target_seats) values($1,3) returning id",
      [ids.community],
    )
  ).rows[0].id;
  await observer.query(
    "insert into public.election_candidacies(cycle_id,community_id,candidate_id) select $1,$2,x from unnest($3::uuid[]) x",
    [withdrawalCycle, ids.community, ids.users],
  );
  await first.query("begin");
  await first.query("select public.freeze_election_cycle($1)", [
    withdrawalCycle,
  ]);
  await asUser(second, ids.users[3]);
  const lateWithdrawal = second
    .query("select public.withdraw_election_candidacy($1)", [withdrawalCycle])
    .then(
      () => null,
      (error) => error,
    );
  await waitForLock(observer, secondPid, "withdraw_election_candidacy");
  await first.query("commit");
  assert.equal((await lateWithdrawal)?.code, "55000");
  await second.query("rollback");
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.election_candidates where cycle_id=$1",
        [withdrawalCycle],
      )
    ).rows[0].n,
    4,
    "withdrawal after freeze cannot rewrite the candidate snapshot",
  );

  // Closure owning the exclusive round lock wins over a late ballot. The ballot waits, then
  // re-checks the committed status and is rejected without inserting anything.
  const withdrawalRound = (
    await observer.query(
      "select id from public.election_rounds where cycle_id=$1 and round_number=1",
      [withdrawalCycle],
    )
  ).rows[0].id;
  await first.query("begin");
  await first.query("select public.close_election_round($1)", [
    withdrawalRound,
  ]);
  await asUser(second, ids.users[0]);
  const lateBallot = second
    .query("select public.submit_election_ballot($1,array[]::uuid[])", [
      withdrawalRound,
    ])
    .then(
      () => null,
      (error) => error,
    );
  await waitForLock(observer, secondPid, "submit_election_ballot");
  await first.query("commit");
  const lateBallotError = await lateBallot;
  assert.equal(lateBallotError?.code, "55000");
  assert.match(lateBallotError?.message ?? "", /Voting is closed/);
  await second.query("rollback");
  assert.equal(
    (
      await observer.query(
        "select count(*)::int n from public.election_ballots where round_id=$1",
        [withdrawalRound],
      )
    ).rows[0].n,
    0,
    "closure committed first rejects the late ballot without inserting it",
  );

  console.log(
    `Concurrent election tests passed with backend PIDs ${firstPid}/${secondPid}: freeze/candidacy, freeze/withdrawal, and both ballot/closure orders serialize deterministically.`,
  );
} finally {
  await first.query("rollback").catch(() => {});
  await second.query("rollback").catch(() => {});
  await observer
    .query("delete from public.communities where id=$1", [ids.community])
    .catch(() => {});
  await observer
    .query("delete from auth.users where id=any($1::uuid[])", [ids.users])
    .catch(() => {});
  await Promise.all([
    observer.end().catch(() => {}),
    first.end().catch(() => {}),
    second.end().catch(() => {}),
  ]);
}
