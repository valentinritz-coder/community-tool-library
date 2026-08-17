import { expect, test, type Browser, type Page } from "@playwright/test";
import pg from "pg";

const { Client } = pg;
const password = "demo-local-only";
const communityId = "d1000000-0000-4000-8000-000000000001";
const users = {
  owner: "d0000000-0000-4000-8000-000000000001",
  candidateOne: "d0000000-0000-4000-8000-000000000002",
  candidateTwo: "d0000000-0000-4000-8000-000000000003",
  candidateThree: "d0000000-0000-4000-8000-000000000004",
  member: "d0000000-0000-4000-8000-000000000005",
  appointedAdmin: "d0000000-0000-4000-8000-000000000006",
} as const;
const emails = {
  owner: "demo-admin@example.test",
  candidateOne: "demo-owner@example.test",
  candidateTwo: "demo-borrower@example.test",
  candidateThree: "demo-member@example.test",
  member: "demo-pending@example.test",
  appointedAdmin: "demo-appointed@example.test",
} as const;

const connectionString =
  process.env.SUPABASE_DB_URL ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

async function withDatabase<T>(operation: (client: pg.Client) => Promise<T>) {
  const client = new Client({ connectionString });
  await client.connect();
  try {
    return await operation(client);
  } finally {
    await client.end();
  }
}

async function asActor<T>(
  userId: string,
  statement: string,
  values: unknown[] = [],
): Promise<T[]> {
  return withDatabase(async (client) => {
    await client.query("begin");
    try {
      await client.query("set local role authenticated");
      await client.query("select set_config('request.jwt.claim.sub',$1,true)", [
        userId,
      ]);
      const result = await client.query(statement, values);
      await client.query("commit");
      return result.rows as T[];
    } catch (error) {
      await client.query("rollback");
      throw error;
    }
  });
}

async function signIn(browser: Browser, email: string) {
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto("/app");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByText("Signed in successfully.")).toBeVisible();
  return { context, page };
}

function governance(page: Page) {
  return page
    .getByRole("region", { name: "Community governance" })
    .getByRole("heading", { name: "Example Test Tool Circle", exact: true })
    .locator("..");
}

async function stand(browser: Browser, email: string) {
  const actor = await signIn(browser, email);
  await governance(actor.page)
    .getByRole("button", { name: "Stand as candidate" })
    .click();
  await expect(
    actor.page.getByText("Your candidacy was submitted."),
  ).toBeVisible();
  await actor.context.close();
}

async function vote(browser: Browser, email: string, candidateNames: string[]) {
  const voter = await signIn(browser, email);
  for (const name of candidateNames) {
    await governance(voter.page).getByLabel(`Approve ${name}`).check();
  }
  await governance(voter.page)
    .getByRole("button", { name: "Submit ballot" })
    .click();
  await expect(
    governance(voter.page)
      .getByRole("region", { name: "Election" })
      .getByText("Your ballot was recorded."),
  ).toBeVisible();
  await voter.context.close();
}

test.describe.serial("governance constitutional journeys", () => {
  test("founding transfer crosses real user RPCs and installs only elected authority", async ({
    browser,
  }) => {
    await withDatabase(async (client) => {
      await client.query(
        `insert into public.memberships(community_id,user_id,role,status,display_name)
         values($1,$2,'member','active','Jordan Field')
         on conflict (community_id,user_id) do update set status='active',display_name=excluded.display_name`,
        [communityId, users.member],
      );
    });

    const owner = await signIn(browser, emails.owner);
    const ownerGovernance = governance(owner.page);
    await expect(
      ownerGovernance.getByRole("heading", { name: "Managed administration" }),
    ).toBeVisible();
    await expect(ownerGovernance.getByText("Taylor Ash")).toBeVisible();
    await ownerGovernance.getByLabel("Target council size").selectOption("3");
    await ownerGovernance
      .getByRole("button", { name: "Start democratic preparation" })
      .click();
    await expect(
      owner.page.getByText("Democratic preparation started."),
    ).toBeVisible();

    await stand(browser, emails.candidateOne);
    await stand(browser, emails.candidateTwo);
    await owner.page.reload();
    await expect(
      governance(owner.page).getByRole("button", {
        name: "Launch election and commit democratic transfer",
      }),
    ).toBeDisabled();
    await expect(
      asActor(users.owner, "select public.commit_democratic_transfer($1)", [
        communityId,
      ]),
    ).rejects.toMatchObject({ code: "55000" });

    await stand(browser, emails.candidateThree);
    await owner.page.reload();
    await governance(owner.page)
      .getByRole("button", {
        name: "Launch election and commit democratic transfer",
      })
      .click();
    const confirmation = owner.page.getByRole("alertdialog");
    await expect(confirmation).toBeVisible();
    await expect(
      confirmation.getByRole("button", { name: "Keep current governance" }),
    ).toBeFocused();
    await confirmation
      .getByRole("button", { name: "Launch election and commit transfer" })
      .click();
    await expect(
      owner.page.getByText("Democratic transfer committed."),
    ).toBeVisible();
    await expect(
      governance(owner.page).getByRole("heading", {
        name: "Committed transition to elected governance",
      }),
    ).toBeVisible();

    const frozen = await withDatabase(async (client) =>
      client.query(
        `select c.governance_state::text,
          (select count(*)::int from public.election_candidates where cycle_id=c.active_election_cycle_id) candidates,
          (select count(*)::int from public.election_electorate where cycle_id=c.active_election_cycle_id) electors,
          (select r.id from public.election_rounds r where r.cycle_id=c.active_election_cycle_id) round_id
         from public.communities c where c.id=$1`,
        [communityId],
      ),
    );
    expect(frozen.rows[0]).toMatchObject({
      governance_state: "democratic_transition",
      candidates: 3,
      electors: 6,
    });

    const candidateNames = ["Alex River", "Blair Stone", "Casey Wood"];
    await vote(browser, emails.owner, candidateNames);
    await vote(browser, emails.appointedAdmin, candidateNames);
    await vote(browser, emails.member, candidateNames);

    await withDatabase(async (client) => {
      await client.query("begin");
      await client.query("set local role service_role");
      const result = await client.query(
        "select public.finalize_foundation_round($1)::text status",
        [frozen.rows[0].round_id],
      );
      expect(result.rows[0].status).toBe("completed");
      await client.query("commit");
    });

    const installed = await withDatabase(async (client) =>
      client.query(
        `select c.governance_state::text,
          public.active_elected_mandate_count(c.id) active,
          public.has_elected_council_authority(c.id) elected_authority
         from public.communities c where c.id=$1`,
        [communityId],
      ),
    );
    expect(installed.rows[0]).toMatchObject({
      governance_state: "democratic",
      active: 3,
    });

    await withDatabase((client) =>
      client.query(
        "update public.memberships set status='pending' where community_id=$1 and user_id=$2",
        [communityId, users.member],
      ),
    );
    for (const rejectedActor of [users.owner, users.appointedAdmin]) {
      await expect(
        asActor(rejectedActor, "select public.approve_membership($1,$2)", [
          communityId,
          users.member,
        ]),
      ).rejects.toMatchObject({ code: "42501" });
    }
    await expect(
      asActor(users.candidateOne, "select public.approve_membership($1,$2)", [
        communityId,
        users.member,
      ]),
    ).resolves.toHaveLength(1);
    await owner.context.close();
  });

  test("resignation remains democratic and member-led reconstitution restores three mandates", async ({
    browser,
  }) => {
    const resigning = await signIn(browser, emails.candidateThree);
    await governance(resigning.page)
      .getByRole("button", { name: "Resign from council" })
      .click();
    await resigning.page
      .getByRole("alertdialog")
      .getByRole("button", { name: "Confirm council resignation" })
      .click();
    await expect(
      resigning.page.getByText("Council resignation completed."),
    ).toBeVisible();
    await expect(
      governance(resigning.page).getByText(/Council under-strength/),
    ).toBeVisible();
    await resigning.context.close();

    const underStrength = await withDatabase(async (client) =>
      client.query(
        `select c.governance_state::text,
          public.active_elected_mandate_count(c.id) active,
          public.council_vacant_seat_count(c.id) vacancies,
          public.get_council_operational_status(c.id)::text operational_status,
          (select count(*)::int from public.election_winners w
            join public.election_cycles cycle on cycle.id=w.cycle_id
            where cycle.community_id=c.id) historical_winners
         from public.communities c where c.id=$1`,
        [communityId],
      ),
    );
    expect(underStrength.rows[0]).toMatchObject({
      governance_state: "democratic",
      active: 2,
      vacancies: 1,
      operational_status: "under_strength",
      historical_winners: 3,
    });
    const resignedAuthority = await asActor<{
      ordinary: boolean;
      caretaker: boolean;
    }>(
      users.candidateThree,
      `select public.has_elected_council_authority($1) ordinary,
        public.has_temporary_caretaker_authority($1) caretaker`,
      [communityId],
    );
    expect(resignedAuthority[0]).toEqual({
      ordinary: false,
      caretaker: false,
    });
    const endedMandate = await withDatabase(async (client) =>
      client.query(
        `select exists(select 1 from public.elected_council_mandates
          where community_id=$1 and member_id=$2 and ended_at is not null) mandate_ended`,
        [communityId, users.candidateThree],
      ),
    );
    expect(endedMandate.rows[0].mandate_ended).toBe(true);
    const remainingAuthority = await asActor<{
      ordinary: boolean;
      caretaker: boolean;
    }>(
      users.candidateOne,
      `select public.has_elected_council_authority($1) ordinary,
        public.has_temporary_caretaker_authority($1) caretaker`,
      [communityId],
    );
    expect(remainingAuthority[0]).toEqual({
      ordinary: false,
      caretaker: true,
    });
    for (const actor of [users.owner, users.appointedAdmin]) {
      const authority = await asActor<{ ordinary: boolean }>(
        actor,
        "select public.has_elected_council_authority($1) ordinary",
        [communityId],
      );
      expect(authority[0].ordinary).toBe(false);
    }

    const member = await signIn(browser, emails.member);
    await governance(member.page)
      .getByRole("button", { name: "Open council reconstitution" })
      .click();
    await expect(
      member.page.getByText("Council reconstitution opened."),
    ).toBeVisible();
    await member.context.close();

    await stand(browser, emails.appointedAdmin);
    const launcher = await signIn(browser, emails.member);
    await governance(launcher.page)
      .getByRole("button", { name: "Start voting" })
      .click();
    await expect(launcher.page.getByText("Voting is now open.")).toBeVisible();
    await launcher.context.close();

    await vote(browser, emails.owner, ["Taylor Ash"]);
    await vote(browser, emails.candidateOne, ["Taylor Ash"]);
    await vote(browser, emails.candidateTwo, ["Taylor Ash"]);

    const reconstitution = await withDatabase(async (client) =>
      client.query(
        `select cycle.id cycle_id,r.id round_id,r.seats_available
         from public.election_cycles cycle join public.election_rounds r on r.cycle_id=cycle.id
         where cycle.community_id=$1 and cycle.purpose='reconstitution' order by cycle.created_at desc limit 1`,
        [communityId],
      ),
    );
    expect(reconstitution.rows[0].seats_available).toBe(1);
    await withDatabase(async (client) => {
      await client.query("begin");
      await client.query("set local role service_role");
      const result = await client.query(
        "select public.finalize_reconstitution_round($1)::text status",
        [reconstitution.rows[0].round_id],
      );
      expect(result.rows[0].status).toBe("completed");
      await client.query("commit");
    });

    const restored = await withDatabase(async (client) =>
      client.query(
        `select c.governance_state::text,
          public.active_elected_mandate_count(c.id) active,
          public.council_vacant_seat_count(c.id) vacancies,
          public.get_council_operational_status(c.id)::text operational_status,
          count(*) filter (where m.source_cycle_id=$2)::int new_mandates,
          count(*) filter (where m.source_cycle_id<>$2 and m.ended_at is null)::int preserved_mandates
         from public.communities c join public.elected_council_mandates m on m.community_id=c.id
         where c.id=$1 group by c.id`,
        [communityId, reconstitution.rows[0].cycle_id],
      ),
    );
    expect(restored.rows[0]).toMatchObject({
      governance_state: "democratic",
      active: 3,
      vacancies: 0,
      operational_status: "operational",
      new_mandates: 1,
      preserved_mandates: 2,
    });
  });
});
