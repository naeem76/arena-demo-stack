import { randomUUID } from 'node:crypto';
import { test as base, expect, type APIRequestContext, type Page } from '@playwright/test';
import type { EventRequest } from '../src/app/api/models/event-request';
import type { EventResponse } from '../src/app/api/models/event-response';
import type { EventPageResponse } from '../src/app/api/models/event-page-response';

export async function signIn(page: Page) {
  const username = process.env['E2E_ADMIN_USERNAME'];
  const password = process.env['E2E_ADMIN_PASSWORD'];
  if (!username || !password) throw new Error('Set E2E_ADMIN_USERNAME and E2E_ADMIN_PASSWORD.');
  await page.goto('/events');
  await page.getByRole('button', { name: 'Continue to sign in' }).click();
  // Preserve the provider's pending authorization request in this same tab.
  await page.getByLabel('Username').fill(username);
  await page.getByLabel('Password', { exact: true }).fill(password);
  await page.getByRole('button', { name: 'Sign in', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Events', exact: true })).toBeVisible();
}

type Events = {
  sport: string;
  draft: (label: string) => EventRequest;
  create: (label: string) => Promise<EventResponse>;
};

export const test = base.extend<{ admin: Page; api: APIRequestContext; events: Events }>({
  admin: async ({ page }, use) => {
    await signIn(page);
    await use(page);
  },
  api: async ({ admin, playwright }, use) => {
    const config = await admin.request.get('/config.json');
    expect(config.status()).toBe(200);
    const { apiBaseUrl } = await config.json();
    const token = await admin.evaluate(() => sessionStorage.getItem('access_token'));
    if (!token) throw new Error('Sign-in did not establish an access token.');
    const api = await playwright.request.newContext({
      baseURL: new URL(apiBaseUrl, admin.url()).origin,
      extraHTTPHeaders: { Authorization: `Bearer ${token}` },
      timeout: 10_000,
    });
    try {
      await use(api);
    } finally {
      await api.dispose();
    }
  },
  events: async ({ api }, use) => {
    const sport = `e2e-${randomUUID()}`;
    const titles = new Set<string>();
    const draft = (label: string): EventRequest => {
      const title = `${sport}-${label}`;
      titles.add(title);
      return {
        title,
        sport,
        description: 'Playwright-owned fixture',
        location: 'E2E court',
        capacity: 12,
        startsAt: new Date(Date.now() + 7 * 86_400_000).toISOString(),
        endsAt: new Date(Date.now() + 7 * 86_400_000 + 3_600_000).toISOString(),
      };
    };
    try {
      await use({
        sport,
        draft,
        create: async (label) => {
          const response = await api.post('/api/events', { data: draft(label) });
          expect(response.status()).toBe(201);
          return response.json();
        },
      });
    } finally {
      // Query after failures too: a successful POST may have lost its response.
      const response = await api.get('/api/events', { params: { sport, size: 100 } });
      expect(response.status(), `Cleanup lookup for ${sport}`).toBe(200);
      const result: EventPageResponse = await response.json();
      expect(result.totalPages).toBeLessThanOrEqual(1);
      const failures: string[] = [];
      for (const event of result.items) {
        if (event.sport !== sport || !titles.has(event.title)) continue;
        try {
          const deleted = await api.delete(`/api/events/${event.id}`);
          if (![204, 404].includes(deleted.status())) failures.push(event.id);
        } catch {
          failures.push(event.id);
        }
      }
      expect(failures, `Cleanup failed for own records in ${sport}`).toEqual([]);
      const remaining = await api.get('/api/events', { params: { sport } });
      expect(remaining.status()).toBe(200);
      expect((await remaining.json()).totalElements).toBe(0);
    }
  },
});

export { expect } from '@playwright/test';

export async function fillEvent(page: Page, event: EventRequest) {
  await page.getByLabel('Event title', { exact: true }).fill(event.title);
  await page.getByLabel('Sport', { exact: true }).fill(event.sport);
  await page.getByLabel('Location', { exact: true }).fill(event.location);
  await page.getByLabel('Total capacity', { exact: true }).fill(String(event.capacity));
  await page.getByLabel('Starts at (local time)').fill(event.startsAt.slice(0, -1));
  await page.getByLabel('Ends at (local time)').fill(event.endsAt.slice(0, -1));
  await page.getByLabel('Description').fill(event.description || '');
}
