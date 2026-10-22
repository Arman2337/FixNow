import { expect, test } from '@playwright/test';

test.beforeEach(async ({ context }) => {
  await context.addCookies([{ name: 'fixnow_admin_access', value: 'e2e-paging', domain: '127.0.0.1', path: '/', httpOnly: true, sameSite: 'Strict' }]);
});

test('support finds older matching records before paging and can continue filtered results', async ({ page }) => {
  await page.goto('/support?status=OPEN&search=OLDER_ONLY');
  await expect(page.getByRole('link', { name: /OLDER_ONLY/ }).first()).toBeVisible();
  await expect(page.getByRole('link', { name: /ARCHIVED/ })).toHaveCount(0);
  await page.getByRole('link', { name: 'Next page' }).click();
  await expect(page).toHaveURL(/page=2/);
  await expect(page.getByText('Page 2', { exact: true })).toBeVisible();
  await expect(page.getByRole('link', { name: /OLDER_ONLY/ })).toHaveCount(1);
});

test('trust OPEN filter finds a signal beyond the first unfiltered page', async ({ page }) => {
  await page.goto('/trust?status=OPEN');
  await expect(page.getByText('Older open signal needs review')).toBeVisible();
  await expect(page.getByText('Previously reviewed')).toHaveCount(0);
});

test('guarantees continue past fifty records and catalog continues past the first page', async ({ page }) => {
  await page.goto('/guarantees?page=7');
  await expect(page.getByText('Guarantee repair 60', { exact: true })).toBeVisible();
  await page.getByRole('link', { name: 'Next page' }).click();
  await expect(page.getByText('Guarantee repair 70', { exact: true })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Next page' })).toHaveCount(0);
  await page.goto('/services?page=2');
  await expect(page.locator('input[name="name"][value="Service category 8"]')).toBeVisible();
  await expect(page.locator('input[name="name"][value="Service category 0"]')).toHaveCount(0);
  await expect(page.getByRole('link', { name: 'Next page' })).toBeVisible();
});

test('global search finds an old complaint and links to the complete matching queue', async ({ page }) => {
  await page.goto('/search?q=OLDER_ONLY');
  await expect(page.getByRole('link', { name: 'All matching complaints' })).toHaveAttribute('href', '/support?search=OLDER_ONLY');
  await expect(page.getByText(/old.*case.*25/i).first()).toBeVisible();
});
