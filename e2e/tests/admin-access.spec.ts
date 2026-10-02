import { expect, test, type BrowserContext, type Page } from '@playwright/test';

/**
 * TEST-001: the admin console's access control, as a journey.
 *
 * These replace three specs that navigated to `about:blank`, wrote their own
 * `<h1>`, and asserted it - so they passed against a browser with no FixNow code
 * loaded, and CI never ran them.
 *
 * Everything here drives the real admin application. Only the API it depends on
 * is stubbed (see support/stub-api.ts), and the session is read server-side by a
 * React Server Component, so it has to be a real server rather than a browser
 * route interceptor.
 */

/** The access cookie `getSession()` reads. */
const accessCookie = 'fixnow_admin_access';

/** Tokens the stub API recognises, one per role the journeys need. */
const TOKENS = {
  analytics: 'e2e-analytics',
  auditor: 'e2e-auditor',
  support: 'e2e-support',
  trust: 'e2e-trust',
} as const;

/**
 * Signs a browser context in by setting the cookie the app reads.
 *
 * Going through the cookie rather than the login page is not a shortcut around
 * the journey - there is no login form to drive. `admin/src/app/login/page.tsx`
 * renders a static card and no inputs, so an authenticated session has to be
 * established the way a returning user would arrive with one.
 */
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

/** Replaces any existing session cookie with [token]. */
async function signInAs(context: BrowserContext, token: string): Promise<void> {
  await context.clearCookies();
  await signIn(context, token);
}

test.describe('admin access control', () => {
  /**
   * The login URL, with whatever query the app attached.
   *
   * Not `/login$`. The dashboard redirects anonymous visitors to a bare `/login`,
   * while the module pages redirect to `/login?reason=expired`, because
   * `classifySession` distinguishes "never had a session" from "had one that is
   * no longer valid" and the pages under `/` all take the second branch. Asserting
   * the bare form for a module route would have been wrong, and asserting nothing
   * about the reason would have let a genuine misclassification through - so the
   * distinction is asserted where it is meaningful and left open elsewhere.
   */
  const loginUrl = /\/login(?:\?|$)/;

  test('an anonymous visitor is sent to the login page', async ({ page }) => {
    // The assertion that matters most in this file: without it, a regression
    // that dropped the session check would render the operations dashboard to
    // anyone who asked, and every other test here would still pass.
    await page.goto('/');

    await expect(page).toHaveURL(loginUrl);
    await expect(
      page.getByRole('heading', { name: 'FixNow Admin Portal' }),
    ).toBeVisible();
  });

  test('an anonymous visitor cannot reach an operations module directly', async ({
    page,
  }) => {
    // Gating the dashboard is not the same as gating the routes. Someone with a
    // bookmark is the case a redirect on `/` alone would miss.
    for (const route of ['/bookings', '/providers', '/support', '/users']) {
      await page.goto(route);
      await expect(page, `${route} must not render for an anonymous visitor`)
        .toHaveURL(loginUrl);
    }
  });

  test('a recognised session reaches the dashboard', async ({ page, context }) => {
    await signIn(context, TOKENS.analytics);
    await page.goto('/');

    await expect(
      page.getByRole('heading', { name: 'FixNow Admin Portal' }),
    ).toHaveCount(0);
    await expect(page.getByText('Bookings pending')).toBeVisible();
  });

  test('a token the API rejects is treated as expired, not as a session', async ({
    page,
    context,
  }) => {
    // A forged or stale cookie must not produce a rendered console. 401 maps to
    // `expired` in classifySession, which redirects to /login?reason=expired -
    // distinct from the 403 path that goes to /unauthorized.
    await signIn(context, 'not-a-real-token');
    await page.goto('/');

    // The reason is the point of this test: `reason=expired` is what
    // classifySession produces for a token the API refused, and it is a different
    // code path from the bare `/login` an anonymous visitor gets. Getting the
    // classification wrong would still redirect to /login and still pass a
    // looser assertion.
    await expect(page).toHaveURL(/\/login\?reason=expired$/);
    await expect(page.getByText('Bookings pending')).toHaveCount(0);
  });

  test('an unrecognised role sees no analytics and no analytics navigation', async ({
    page,
    context,
  }) => {
    // The role gate, exercised end to end. The dashboard has two real branches
    // and this is the one that must not leak platform-wide figures to a
    // support agent.
    await signIn(context, TOKENS.support);
    await page.goto('/');

    // The heading text is the app's, not mine: `page.tsx` renders
    // "Your Staff Access" as the eyebrow above this heading.
    await expect(page.getByText('Your Staff Access')).toBeVisible();
    await expect(
      page.getByRole('heading', { name: 'Choose an operation from the navigation' }),
    ).toBeVisible();
    await expect(page.getByText('Bookings pending')).toHaveCount(0);

    // Support has the dispatches module but not analytics-only destinations.
    await expect(page.getByRole('link', { name: /Live Dispatches/ })).toBeVisible();
    await expect(page.getByRole('link', { name: /Trust & Safety Moderation/ })).toHaveCount(0);
  });

  test('navigation offers each module only to the roles that own it', async ({
    page,
    context,
  }) => {
    await signIn(context, TOKENS.support);
    await page.goto('/');
    const routesForSupport = await _moduleRoutes(page);

    // Swap the cookie rather than calling signIn again: `signIn` uses
    // `addCookies`, which appends, so a second call left *both* cookies set for
    // the same name and the server read the first one. The administrator's
    // navigation came back empty for that reason - and an empty list passes
    // `toContain('/trust')` as a failure rather than as the absence of a bug,
    // which is why it surfaced at all.
    await signInAs(context, TOKENS.analytics);
    await page.goto('/');
    const routesForAdmin = await _moduleRoutes(page);

    expect(routesForSupport).toContain('/bookings');
    expect(routesForSupport).toContain('/support');
    expect(routesForSupport).not.toContain('/trust');
    expect(routesForAdmin).toContain('/trust');
    // The administrator sees strictly more, and both see the same dashboard, so
    // the difference is the gate and not a missing shell.
    expect(routesForAdmin.length).toBeGreaterThan(routesForSupport.length);
  });
});


/**
 * The module routes the sidebar offers to the current role.
 *
 * Identified by `href`, not by label text. The label is not recoverable from the
 * anchor: each link contains a Material Symbols ligature alongside its caption,
 * so `textContent` returns "dashboardOverview Dashboard" - icon glyph concatenated
 * with the real label - and the first version of this stripped lowercase runs to
 * recover the text, which produced "OD" and "Live D& R". Stripping the *words* out
 * of the caption to remove the icon also removes most of the caption.
 *
 * The route is unambiguous, and it is what the role filter actually controls:
 * `AdminShell` filters `navigation` by `item.roles` and renders the href.
 *
 * Scoped to the labelled nav, because the desktop and mobile shells both render
 * the same links and an unscoped query returns every module twice.
 */
async function _moduleRoutes(page: Page): Promise<string[]> {
  const links = page
    .getByRole('navigation', { name: 'Admin navigation' })
    .getByRole('link');
  // The shell renders a loading state first, and `evaluateAll` on a page that
  // has not finished booting returns an empty list rather than waiting - which
  // read as "this role sees no modules at all" and failed the role-gate
  // assertions on a retry that happened to boot faster or slower than the run
  // before. Waiting here makes the helper report the routes the nav actually
  // offers instead of the routes that happened to be mounted when we looked.
  await links.first().waitFor({ state: 'visible' });
  const hrefs = await links.evaluateAll((nodes) =>
    nodes.map((node) => new URL((node as HTMLAnchorElement).href).pathname),
  );
  return [...new Set(hrefs)].sort();
}