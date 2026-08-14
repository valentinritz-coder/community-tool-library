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

const observer = db("election-observer"),
  first = db("election-first"),
  second = db("election-second");
try {
  await Promise.all([observer.connect(), first.connect(), second.connect()]);
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

  // Finalizers lock the authoritative round; the loser observes the committed final state.
  await Promise.all([
    asUser(first, ids.users[0]),
    asUser(second, ids.users[1]),
  ]);
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
