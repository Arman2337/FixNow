import { defineConfig, devices } from '@playwright/test';
import path from 'path';

/**
 * TEST-001.
 *
 * `baseURL` and `webServer` used to be commented out, which is why the only three
 * specs in this directory navigated to `about:blank` and asserted against markup
 * they had written themselves: there was nothing to navigate to. Both are
 * configured now, so a journey has a real application to drive and CI has
 * something to run.
 */
/**
 * Not 3100, which is the admin app's own `dev` script port.
 *
 * That port is routinely occupied on a developer machine by WSL's port relay or
 * a container, and when it is, `next dev` exits with EADDRINUSE and Playwright
 * reports only "process was not able to start" - which says nothing about the
 * cause. Running e2e on its own port keeps the two concerns separate: 3100 is
 * for a human looking at the app, this is for the journeys.
 */
const adminPort = Number(process.env.E2E_ADMIN_PORT ?? 3110);
const stubApiPort = Number(process.env.E2E_STUB_API_PORT ?? 3199);
const baseURL = `http://127.0.0.1:${adminPort}`;

/** The stub API the admin app talks to. See support/stub-api.ts for why it exists. */
const stubApi = {
  command: 'npx tsx support/stub-api.ts',
  cwd: __dirname,
  url: `http://127.0.0.1:${stubApiPort}/api/v1/auth/admin/session`,
  reuseExistingServer: !process.env.CI,
  // A 401 is the healthy response for that URL with no bearer token. Probing for
  // 2xx instead would mean waiting out the 30s timeout on every run, because the
  // stub deliberately refuses anonymous requests.
  ignoreHTTPSErrors: true,
};

/**
 * The real admin application.
 *
 * `NEXT_PUBLIC_API_BASE_URL` points at the stub, so the app under test is the
 * real one - real server components, real session classification, real role
 * gates - while its dependency is faked. `NEXT_PUBLIC_APP_ENV` is `test` so the
 * app's own environment validation is exercised on the way in.
 */
const admin = {
  // `next dev -p` directly rather than `npm run dev`, because the package script
  // hardcodes `-p 3100` and this config needs to choose the port.
  command: `npx next dev -p ${adminPort}`,
  cwd: path.join(__dirname, '..', 'admin'),
  url: baseURL,
  reuseExistingServer: !process.env.CI,
  // Generous: `next dev` compiles the app on first request, and the first journey
  // pays for that. 120s was the first guess and it is a timeout that should never
  // fire rather than a tuned value.
  timeout: 120_000,
  env: {
    // `test` rather than `development`: the app validates this value on boot and
    // the journeys are not development, and `development` would additionally
    // widen the realtime origin allowlist for reasons that have nothing to do
    // with what is being tested here.
    NEXT_PUBLIC_APP_ENV: 'test',
    NEXT_PUBLIC_API_BASE_URL: `http://127.0.0.1:${stubApiPort}/api/v1`,
  },
};

export default defineConfig({
  testDir: './tests',
  timeout: 30 * 1000,
  expect: { timeout: 5000 },
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? 'line' : 'html',
  use: {
    actionTimeout: 0,
    baseURL,
    trace: 'on-first-retry',
    screenshot: 'on',
  },

  outputDir: path.join(__dirname, '..', 'reports', 'screenshots'),
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: [stubApi, admin],
});
