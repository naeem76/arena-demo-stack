import { test, expect } from './fixtures';

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
