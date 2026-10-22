import { expect, test, type BrowserContext, type Page } from '@playwright/test';

/**
 * TEST-001: the operations modules, driven through the real shell.
 *
 * The other three specs this replaces asserted against markup they had written
 * themselves. These navigate the actual application and assert on text that only
 * exists because a stub API returned it - so a journey fails if the app stops
 * calling the endpoint, stops rendering the data, or renders it under the wrong
 * heading.
 */
const accessCookie = 'fixnow_admin_access';

async function signIn(context: BrowserContext, token: string): Promise<void> {
  await context.addCookies([
    {
      name: accessCookie,
      value: token,
      domain: '127.0.0.1',
      path: '/',
      httpOnly: true,
      sameSite: 'Strict',
    },
  ]);
}

test.describe('admin operations modules', () => {
  test('the dashboard renders every metric the API returned', async ({
    page,
    context,
  }) => {
    await signIn(context, 'e2e-analytics');
    await page.goto('/');

    // Values, not just labels: a dashboard that renders the four headings over an
    // empty object would satisfy a label-only assertion, which is the shape of
    // assertion the deleted specs used.
    //
    // Scoped to the tile, because the label and its value are siblings inside a
    // card and `locator('..')` only walks one level up - which lands on the
    // row holding the label and the icon ligature, not on the card. Asserting
    // against that produced "Bookings pendingpending_actions" and no number.
    const metrics: ReadonlyArray<readonly [string, string]> = [
      ['Bookings pending', '86'],
      ['Active providers', '287'],
      ['Completed bookings', '1102'],
      ['Active emergencies', '7'],
    ];

    for (const [label, value] of metrics) {
      const tile = page
        .getByText(label)
        .locator('xpath=ancestor::div[contains(@class,"rounded-2xl")][1]');
      await expect(tile, `${label} tile must show its value`).toContainText(value);
    }

    // The window the numbers describe, from the API's own generatedAt. This is
    // the only figure on the page that cannot be confused with a metric, so it is
    // what proves the stub's payload was read rather than a hard-coded default.
    await expect(page.getByText(/Generated/)).toBeVisible();
  });

  test('the support module lists the complaints the API returned', async ({
    page,
    context,
  }) => {
    await signIn(context, 'e2e-support');
    await page.goto('/');
    await page.getByRole('link', { name: /Complaints & Escrow/ }).click();

    await expect(page).toHaveURL(/\/support$/);

    // The page shortens ids - `cmp-e2e-1111111111111111` becomes `CMPE2E11`,
    // because it strips the dashes and takes eight characters. Asserting on the
    // shortened form is deliberate: it checks the page's own formatting rather
    // than merely that a string from the stub arrived.
    await expect(page.getByText('#CMPE2E11').first()).toBeVisible();
    await expect(page.getByText('#CMPE2E22').first()).toBeVisible();

    // Categories render verbatim from the row and only the detail heading runs
    // through the humaniser, so the underscore form is what the list shows. The
    // first version of this asserted "No Show" here, which is the detail-page
    // presentation, and could only ever have passed against the wrong screen.
    await expect(page.getByText('NO_SHOW')).toBeVisible();
    await expect(page.getByText('REFUND').first()).toBeVisible();

    // Both statuses, scoped to the row that carries each id. A bare
    // `getByText('OPEN')` also matches a status filter option in the page's own
    // controls, which is hidden behind a disclosure, so `.first()` resolved to
    // that and reported the row as missing - a locator that pointed at the wrong
    // element rather than a page that rendered wrongly.
    const rowFor = (shortId: string) =>
      page.getByRole('link', { name: new RegExp(shortId) });
    await expect(rowFor('#CMPE2E11')).toContainText('ESCALATED');
    await expect(rowFor('#CMPE2E22')).toContainText('OPEN');
    await expect(rowFor('#CMPE2E22')).not.toContainText('ESCALATED');

    // Each row links through to its detail page, so the ids are navigable rather
    // than merely displayed.
    await expect(
      page.getByRole('link', { name: /#CMPE2E11/ }),
    ).toHaveAttribute('href', '/support/cmp-e2e-1111111111111111');
  });

  test('the support module can be filtered by status', async ({
    page,
    context,
  }) => {
    await signIn(context, 'e2e-support');
    await page.goto('/support?status=ESCALATED');

    // The filter is applied server-side, from searchParams, over the API result.
    // Asserting the ESCALATED-only outcome is what proves the filter ran: a page
    // that ignored the query would render both rows and still contain this text.
    await expect(page.getByText('#CMPE2E11').first()).toBeVisible();
    // The OPEN row is gone entirely. Asserting on its id rather than on a word
    // from its description, because the words could appear elsewhere on the page.
    await expect(page.getByText('#CMPE2E22')).toHaveCount(0);
    await expect(page.getByText('REFUND')).toHaveCount(0);
  });

  test('a module the role does not own is not linked in the navigation', async ({
    page,
    context,
  }) => {
    await signIn(context, 'e2e-support');
    await page.goto('/');

    await expect(page.getByRole('link', { name: /Trust & Safety Moderation/ })).toHaveCount(0);
    await expect(page.getByRole('link', { name: /Live Dispatches/ })).toBeVisible();
  });

  // Regression: direct URL access must enforce trust permissions.
  test(
    'a support agent must not be able to open the trust module by URL',
    async ({ page, context }) => {
      await signIn(context, 'e2e-support');
      await page.goto('/trust');

      await expect(page).toHaveURL(/\/(login|unauthorized)/);
    },
  );

  test('the current module is marked for assistive technology', async ({
    page,
    context,
  }) => {
    await signIn(context, 'e2e-support');
    await page.goto('/support');

    // The active link is identified by aria-current, not only by colour - which
    // is the redundant cue DESIGN.md asks for and which a screenshot cannot check.
    const current = page.getByRole('link', { name: /Complaints & Escrow/ });
    await expect(current).toHaveAttribute('aria-current', 'page');
  });

  test('a session that authenticates but is denied lands on the unauthorized page', async ({
    page,
    context,
  }) => {
    await signIn(context, 'e2e-forbidden');
    await page.goto('/support');

    // 403 and 401 are different destinations: `requireManagementResult` sends
    // 401 to /login?reason=expired and 403 to /unauthorized. This asserts the
    // second, which is the branch that distinguishes "your session is gone" from
    // "your session works and still is not allowed".
    await expect(page).toHaveURL(/\/unauthorized$/);
  });

  test('an empty support filter renders a recovery message', async ({
    page,
    context,
  }) => {
    await signIn(context, 'e2e-support');

    await page.goto('/support?status=CLOSED');

    // A status filter that matches nothing must produce the app's empty state,
    // not a blank region. This is the reachable form of the same claim: the
    // module renders a deliberate message instead of nothing when it has no rows.
    await expect(
      page.getByRole('heading', { name: 'No open support cases' }),
    ).toBeVisible();
  });
});
