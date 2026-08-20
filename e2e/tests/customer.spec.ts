import { test, expect } from '@playwright/test';
import path from 'path';

test('Customer App - Baseline Smoke Test', async ({ page }) => {
  // Navigate to blank page as baseline since server might not be running
  await page.goto('about:blank');

  // Set some content to take a screenshot of
  await page.setContent('<h1>FixNow Customer App</h1><p>Playwright testing initialized successfully.</p>');

  // Explicitly take a screenshot to the reports/screenshots directory
  await page.screenshot({ path: path.join(__dirname, '..', '..', 'reports', 'screenshots', 'customer-smoke-test.png') });

  // Basic assertion
  const heading = await page.locator('h1').textContent();
  expect(heading).toBe('FixNow Customer App');
});
