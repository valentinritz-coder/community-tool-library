import { expect, test, type Browser, type Page } from "@playwright/test";

const password = "demo-local-only";
const communityName = "Example Test Tool Circle";
const communityJoinCode = "d1000000-0000-4000-8000-000000000099";
const itemName = "E2E compact screwdriver";
const itemPhoto = {
  name: "e2e-item.png",
  mimeType: "image/png",
  buffer: Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
    "base64",
  ),
};

function dateFromToday(days: number): string {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

async function signIn(browser: Browser, email: string) {
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto("/");
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByText("Signed in successfully.")).toBeVisible();
  return { context, page };
}

function reservation(page: Page, heading: string) {
  return page
    .getByRole("heading", { name: heading })
    .locator("..")
    .getByRole("listitem")
    .filter({ hasText: itemName });
}

test.describe.serial("critical MVP journeys", () => {
  test("real authentication, join, and approval grant community access", async ({
    browser,
  }) => {
    const joining = await signIn(browser, "demo-pending@example.test");
    await expect(
      joining.page.getByRole("heading", { name: "Your active communities" }),
    ).toBeVisible();
    await expect(
      joining.page.getByText("No active communities yet."),
    ).toBeVisible();

    await joining.page
      .getByLabel("Community join code")
      .fill(communityJoinCode);
    await joining.page.getByRole("button", { name: "Request to join" }).click();
    await expect(
      joining.page.getByText(
        "Request sent. The community owner or an appointed administrator must approve it.",
      ),
    ).toBeVisible();
    const pendingMembership = joining.page
      .getByRole("heading", { name: "Memberships and requests" })
      .locator("..")
      .getByRole("listitem")
      .filter({ hasText: "member — pending" });
    await expect(pendingMembership).toBeVisible();

    const admin = await signIn(browser, "demo-admin@example.test");
    await expect(
      admin.page
        .getByRole("region", { name: "Your active communities" })
        .getByText(communityName, { exact: true }),
    ).toBeVisible();
    const specificPendingMembership = admin.page
      .getByRole("heading", { name: "Memberships and requests" })
      .locator("..")
      .getByRole("listitem")
      .filter({ hasText: "member — pending" });
    await expect(specificPendingMembership).toHaveCount(1);
    await specificPendingMembership
      .getByRole("button", { name: "Approve membership" })
      .click();
    await expect(admin.page.getByText("Membership approved.")).toBeVisible();

    await joining.page.reload();
    await expect(
      joining.page
        .getByRole("region", { name: "Your active communities" })
        .getByText(communityName, { exact: true }),
    ).toBeVisible();
    await expect(
      joining.page.getByRole("heading", { name: "Community inventory" }),
    ).toBeVisible();

    await admin.context.close();
    await joining.context.close();
  });

  test("owner lists an available item and accepts a borrower request", async ({
    browser,
  }) => {
    const owner = await signIn(browser, "demo-owner@example.test");
    const createItemForm = owner.page
      .getByRole("button", { name: "List item" })
      .locator("..");
    await createItemForm
      .getByLabel("Item name", { exact: true })
      .fill(itemName);
    await createItemForm
      .getByLabel("Item category", { exact: true })
      .selectOption("small_diy");
    await createItemForm
      .getByLabel("Short description", { exact: true })
      .fill("Synthetic low-risk screwdriver for the Playwright critical path.");
    await createItemForm.getByLabel(/Item photo/).setInputFiles(itemPhoto);
    await createItemForm.getByRole("button", { name: "List item" }).click();
    await expect(
      owner.page.getByText("Item listed for your community."),
    ).toBeVisible();

    const ownedItem = owner.page
      .locator("article")
      .filter({
        has: owner.page.getByRole("heading", { name: itemName, exact: true }),
      })
      .filter({
        has: owner.page.getByRole("button", {
          name: "Add availability range",
        }),
      });
    await expect(ownedItem).toHaveCount(1);
    await ownedItem.getByLabel("Start date (included)").fill(dateFromToday(20));
    await ownedItem.getByLabel("End date (included)").fill(dateFromToday(22));
    await ownedItem
      .getByRole("button", { name: "Add availability range" })
      .click();
    await expect(
      owner.page.getByText("Availability range added."),
    ).toBeVisible();

    const borrower = await signIn(browser, "demo-borrower@example.test");
    await borrower.page.getByLabel("Search inventory").fill(itemName);
    const inventoryItem = borrower.page
      .locator("article")
      .filter({ has: borrower.page.getByRole("heading", { name: itemName }) });
    await expect(inventoryItem).toBeVisible();
    await inventoryItem
      .getByLabel("Start date", { exact: true })
      .fill(dateFromToday(20));
    await inventoryItem
      .getByLabel("End date", { exact: true })
      .fill(dateFromToday(22));
    await inventoryItem
      .getByRole("button", { name: "Request reservation" })
      .click();
    await expect(
      borrower.page.getByText(
        "Reservation request created with Requested status.",
      ),
    ).toBeVisible();

    await owner.page.reload();
    const ownerRequest = reservation(owner.page, "Reservation decisions");
    await expect(ownerRequest.getByText("Status: Requested")).toBeVisible();
    await ownerRequest
      .getByRole("button", { name: `Accept reservation for ${itemName}` })
      .click();
    await expect(owner.page.getByText(/Reservation accepted/)).toBeVisible();

    await borrower.page.reload();
    await expect(
      reservation(borrower.page, "Your reservation requests").getByText(
        "Status: Accepted",
      ),
    ).toBeVisible();

    await borrower.context.close();
    await owner.context.close();
  });

  test("participants record handover and return into transaction history", async ({
    browser,
  }) => {
    const owner = await signIn(browser, "demo-owner@example.test");
    const ownerRequest = reservation(owner.page, "Reservation decisions");
    await ownerRequest
      .getByRole("button", { name: `Mark ${itemName} as handed over` })
      .click();
    await expect(
      owner.page.getByText("Handover recorded. Status is now Checked out."),
    ).toBeVisible();
    await expect(ownerRequest.getByText("Status: Checked out")).toBeVisible();

    const borrower = await signIn(browser, "demo-borrower@example.test");
    const borrowerRequest = reservation(
      borrower.page,
      "Your reservation requests",
    );
    await expect(
      borrowerRequest.getByText("Status: Checked out"),
    ).toBeVisible();
    await borrowerRequest
      .getByRole("button", { name: `Mark ${itemName} as returned` })
      .click();
    await expect(
      borrower.page.getByText(
        "Return recorded. This transaction is now in your history.",
      ),
    ).toBeVisible();
    await expect(
      reservation(borrower.page, "Transaction history").getByText(
        "Status: Returned",
      ),
    ).toBeVisible();

    await borrower.context.close();
    await owner.context.close();
  });
});
