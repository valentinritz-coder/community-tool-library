import assert from "node:assert/strict";
import pg from "pg";

const { Client } = pg;
const connectionString =
  process.env.SUPABASE_DB_URL ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const connect = async (name) => {
  const client = new Client({
    connectionString,
    application_name: name,
    connectionTimeoutMillis: 5000,
  });
  await client.connect();
  return client;
};
const asOwner = async (client, owner) => {
  await client.query("begin");
  await client.query("set local role authenticated");
  await client.query("select set_config('request.jwt.claim.sub',$1,true)", [
    owner,
  ]);
};
const rejected = (promise) =>
  promise.then(
    () => null,
    (error) => error,
  );

const ids = {
  owner: "f6000000-0000-4000-8000-000000000001",
  users: [1, 2, 3, 4, 5].map(
    (n) => `f6000000-0000-4000-8000-${String(n).padStart(12, "0")}`,
  ),
  community: "f6100000-0000-4000-8000-000000000001",
};
let admin, first, second;
try {
  [admin, first, second] = await Promise.all([
    connect("governance-admin"),
    connect("governance-first"),
    connect("governance-second"),
  ]);
  await admin.query(
    `insert into auth.users(id,instance_id,aud,role,email,encrypted_password)
    select x,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',x||'@example.test','' from unnest($1::uuid[]) x`,
    [ids.users],
  );
  await admin.query(
    "insert into public.communities(id,name,owner_id) values($1,'Governance race',$2)",
    [ids.community, ids.owner],
  );
  await admin.query(
    "insert into public.memberships(community_id,user_id,role,status) select $1,x,'member','active' from unnest($2::uuid[]) x",
    [ids.community, ids.users],
  );
  await asOwner(first, ids.owner);
  const cycle = (
    await first.query("select public.begin_democratic_preparation($1,3) id", [
      ids.community,
    ])
  ).rows[0].id;
  await first.query("commit");
  await admin.query(
    "insert into public.election_candidacies(cycle_id,community_id,candidate_id) select $1,$2,x from unnest($3::uuid[]) x",
    [cycle, ids.community, ids.users.slice(0, 3)],
  );

  // Concurrent commitments serialize on the community row and exactly one crosses the boundary.
  await Promise.all([asOwner(first, ids.owner), asOwner(second, ids.owner)]);
  await first.query("select public.commit_democratic_transfer($1)", [
    ids.community,
  ]);
  const secondCommit = rejected(
    second.query("select public.commit_democratic_transfer($1)", [
      ids.community,
    ]),
  );
  await first.query("commit");
  assert.equal((await secondCommit)?.code, "55000");
  await second.query("rollback");
  assert.equal(
    (
      await admin.query(
        "select governance_state::text state from public.communities where id=$1",
        [ids.community],
      )
    ).rows[0].state,
    "democratic_transition",
  );
  assert.equal(
    (
      await admin.query(
        "select count(*)::int n from public.election_rounds where cycle_id=$1",
        [cycle],
      )
    ).rows[0].n,
    1,
  );

  // Commit winning the lock also permanently rejects both cancellation and target mutation.
  await asOwner(first, ids.owner);
  const cancelError = await rejected(
    first.query("select public.cancel_democratic_preparation($1)", [
      ids.community,
    ]),
  );
  assert.equal(cancelError?.code, "55000");
  await first.query("rollback");
  await asOwner(first, ids.owner);
  const targetError = await rejected(
    first.query("select public.change_preparation_council_target($1,5)", [
      ids.community,
    ]),
  );
  assert.equal(targetError?.code, "55000");
  await first.query("rollback");

  // Build a valid terminal result. Concurrent installers serialize and exactly one materializes it.
  await admin.query(
    "update public.election_cycles set status='completed',completed_at=now() where id=$1",
    [cycle],
  );
  await admin.query(
    "insert into public.election_winners(cycle_id,candidate_id,elected_in_round,approval_count) select $1,x,1,1 from unnest($2::uuid[]) x",
    [cycle, ids.users.slice(0, 3)],
  );
  await Promise.all([first.query("begin"), second.query("begin")]);
  await first.query("select public.install_elected_council($1,$2)", [
    ids.community,
    cycle,
  ]);
  const secondInstall = rejected(
    second.query("select public.install_elected_council($1,$2)", [
      ids.community,
      cycle,
    ]),
  );
  await first.query("commit");
  assert.equal((await secondInstall)?.code, "55000");
  await second.query("rollback");
  assert.equal(
    (
      await admin.query(
        "select count(*)::int n from public.elected_councils where community_id=$1",
        [ids.community],
      )
    ).rows[0].n,
    1,
  );
  assert.equal(
    (
      await admin.query(
        "select count(*)::int n from public.elected_council_mandates where community_id=$1",
        [ids.community],
      )
    ).rows[0].n,
    3,
  );
  console.log(
    "Governance transfer concurrency tests passed: commit, irreversible alternatives, and council installation serialize exactly once.",
  );
} finally {
  await first?.query("rollback").catch(() => {});
  await second?.query("rollback").catch(() => {});
  await admin
    ?.query("delete from public.communities where id=$1", [ids.community])
    .catch(() => {});
  await admin
    ?.query("delete from auth.users where id=any($1::uuid[])", [ids.users])
    .catch(() => {});
  await Promise.all(
    [admin?.end(), first?.end(), second?.end()]
      .filter(Boolean)
      .map((p) => p.catch(() => {})),
  );
}
