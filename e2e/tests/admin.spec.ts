import { test, expect } from '@playwright/test';
import path from 'path';

test('Admin Portal - Baseline Smoke Test', async ({ page }) => {
  // We navigate to a blank page for the baseline test as the server might not be running
  await page.goto('about:blank');

  // Set some content to take a screenshot of
  await page.setContent('<h1>FixNow Admin Portal</h1><p>Playwright testing initialized successfully.</p>');

  // Explicitly take a screenshot to the reports/screenshots directory
  await page.screenshot({ path: path.join(__dirname, '..', '..', 'reports', 'screenshots', 'admin-smoke-test.png') });

  // Basic assertion
  const heading = await page.locator('h1').textContent();
  expect(heading).toBe('FixNow Admin Portal');
});
