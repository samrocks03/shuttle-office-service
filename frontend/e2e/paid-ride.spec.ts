/**
 * Paid ride happy path: sign in as the demo employee, book a priced Pune ride,
 * pay by card in the Hyperswitch checkout, and see "Paid" on the result page
 * and in the reservations list.
 *
 * Start the stack first (Playwright does not start servers):
 *   - Hyperswitch lab: ../hyperswitch-lab/lab.sh start (router 8080, SDK 9050, lab app 3100)
 *   - Rails API on 3000 and Sidekiq (with the repo .env loaded)
 *   - Frontend on 3001:
 *       NEXT_PUBLIC_API_URL=http://localhost:3001 INTERNAL_API_URL=http://localhost:3000 npm run dev
 *
 * Environment for this test (never commit the values):
 *   E2E_CARD_NUMBER        a public Visa success test card number (required)
 *   E2E_EMPLOYEE_PASSWORD  password of the demo employee (required)
 *   E2E_EMPLOYEE_EMAIL     defaults to the dev demo employee
 *   E2E_SCHEDULE_DATE      defaults to 2026-12-02
 *   E2E_SCHEDULE_ROUTE     defaults to "Wakad to Kharadi" (AC, priced)
 *
 * Repeatable: before booking, the test cancels the demo employee's own active
 * reservation on the same ride (through the app's API), because a rider can hold
 * only one active reservation per schedule. Cancelling a paid ride refunds it.
 *
 * The test does not depend on which processor takes the card (Hyperswitch routes
 * stripe -> stripe_test -> razorpay); it checks only the rider-facing outcome.
 */
import { expect, test, type Page } from "@playwright/test";

const EMAIL = process.env.E2E_EMPLOYEE_EMAIL ?? "task8-demo@example.test";
const PASSWORD = process.env.E2E_EMPLOYEE_PASSWORD;
const CARD_NUMBER = process.env.E2E_CARD_NUMBER;
const DATE = process.env.E2E_SCHEDULE_DATE ?? "2026-12-02";
const ROUTE = process.env.E2E_SCHEDULE_ROUTE ?? "Wakad to Kharadi";

interface ReservationRow {
  attributes: {
    uid: string;
    status: string;
    schedule: { start_point: string; date: string };
  };
}

async function signIn(page: Page) {
  await page.goto("/login");
  await page.locator("#email").fill(EMAIL);
  await page.locator("#password").fill(PASSWORD!);
  await page.locator("button[type=submit]").click();
  await page.waitForURL(/\/employee/);
}

/** Cancel the rider's active reservations on the ride this test books. */
async function cancelActiveReservations(page: Page) {
  const active: string[] = [];
  for (let p = 1; p <= 50; p++) {
    const res = await page.request.get(`/api/reservations?page=${p}&per_page=100`);
    expect(res.ok(), "list reservations").toBeTruthy();
    const body = (await res.json()) as { data: ReservationRow[]; meta?: { total_pages?: number } };
    for (const { attributes: a } of body.data) {
      const sameRide = a.schedule.start_point === ROUTE && a.schedule.date === DATE;
      if (sameRide && ["pending_payment", "confirmed"].includes(a.status)) active.push(a.uid);
    }
    if (p >= (body.meta?.total_pages ?? 1)) break;
  }
  for (const uid of active) {
    const res = await page.request.delete(`/api/reservations/${uid}`);
    expect(res.ok(), `cancel reservation ${uid}`).toBeTruthy();
  }
}

test("rider books a priced ride and pays by card", async ({ page }) => {
  expect(CARD_NUMBER, "set E2E_CARD_NUMBER to a public Visa success test card").toBeTruthy();
  expect(PASSWORD, "set E2E_EMPLOYEE_PASSWORD for the demo employee").toBeTruthy();

  await test.step("sign in and reset the ride", async () => {
    await signIn(page);
    await cancelActiveReservations(page);
  });

  await test.step("find the priced ride and book it", async () => {
    await page.goto("/employee/schedules");
    const heading = page.getByRole("heading", { name: ROUTE, exact: true });
    // The date input can be reset by hydration, so retry until the search shows the ride.
    await expect(async () => {
      await page.locator("input[type=date]").fill(DATE);
      await page.getByRole("button", { name: "Search" }).click();
      await expect(heading).toBeVisible({ timeout: 3_000 });
    }).toPass({ timeout: 30_000 });

    const row = page.locator("div.rounded-xl", { has: heading });
    await expect(row.getByText(/Rs\s?\d+/).first()).toBeVisible();
    await row.getByRole("button", { name: "Reserve" }).click();
    await page.waitForURL(/\/employee\/reservations\/[^/]+\/pay$/, { timeout: 30_000 });
  });

  const uid = page.url().match(/reservations\/([^/]+)\/pay/)![1];

  await test.step("pay by card in the Hyperswitch checkout", async () => {
    const card = page
      .frameLocator('iframe[name^="orca-payment-element-iframeRef-orca-elements-payment-element"]')
      .frameLocator('iframe[name*="card-inner-iframe"]');
    const number = card.locator('input[name="cardNoInput"]');
    await expect(number).toBeVisible({ timeout: 30_000 });
    await number.pressSequentially(CARD_NUMBER!, { delay: 20 });
    await card.locator('input[name="expiryInput"]').pressSequentially("1230", { delay: 20 });
    await card.locator('input[name="cvvInput"]').pressSequentially("123", { delay: 20 });

    const pay = page.getByRole("button", { name: /^Pay / });
    await expect(pay).toBeEnabled();
    await pay.click();
  });

  await test.step("result page says Paid", async () => {
    await page.waitForURL(new RegExp(`/employee/reservations/${uid}/result`), { timeout: 60_000 });
    const title = page.getByTestId("result-title");
    await expect(title).toHaveAttribute("data-state", "paid", { timeout: 30_000 });
    await expect(title).toHaveText(/^Paid/);
  });

  await test.step("reservations list shows Paid", async () => {
    await page.goto("/employee/reservations");
    const paidCard = page
      .locator("div.rounded-xl.px-5")
      .filter({ hasText: ROUTE })
      .filter({ hasText: DATE })
      .filter({ has: page.getByTestId("reservation-status").filter({ hasText: /^Paid$/i }) });
    const next = page.getByRole("button", { name: "Next", exact: true });
    // The list is oldest first and paged; walk forward until the paid ride shows.
    await expect(async () => {
      if ((await paidCard.count()) === 0 && (await next.isVisible()) && (await next.isEnabled())) {
        await next.click();
      }
      await expect(paidCard).toHaveCount(1, { timeout: 2_000 });
    }).toPass({ timeout: 60_000 });
  });
});
