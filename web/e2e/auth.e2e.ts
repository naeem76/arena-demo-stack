import { test, expect } from './fixtures';

test('failed provider sign-in shows a generic error and preserves the app callback', async ({
  page,
}) => {
  await page.goto('/events');
  await page.getByRole('button', { name: 'Continue to sign in' }).click();
  await page.getByLabel('Username').fill('missing-account');
  await page.getByLabel('Password', { exact: true }).fill('incorrect-password');
  await page.getByRole('button', { name: 'Sign in', exact: true }).click();
  await expect(page.getByRole('alert')).toHaveText('Invalid username or password.');
  await expect(page.getByLabel('Password', { exact: true })).toHaveValue('');
  await expect(page.getByLabel('Username')).toHaveAttribute('aria-describedby', 'login-error');
  await page.getByLabel('Username').fill(process.env['E2E_ADMIN_USERNAME']!);
  await page.getByLabel('Password', { exact: true }).fill(process.env['E2E_ADMIN_PASSWORD']!);
  await page.getByRole('button', { name: 'Sign in', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Events', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await expect(page).toHaveURL(/\/signed-out/);
});

test('fresh admin login and logout protect direct routes and provider session', async ({
  admin: page,
}) => {
  await expect(page.getByRole('link', { name: 'Create event' })).toBeVisible();
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await expect(page).toHaveURL(/\/signed-out/);
  expect(await page.evaluate(() => sessionStorage.getItem('access_token'))).toBeNull();
  await page.goto('/events/new');
  await expect(page.getByRole('button', { name: 'Continue to sign in' })).toBeVisible();
  await expect(page.getByLabel('Event title', { exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Continue to sign in' }).click();
  await expect(page.getByLabel('Username')).toBeVisible();
  await expect(page.getByLabel('Password', { exact: true })).toBeVisible();
});
