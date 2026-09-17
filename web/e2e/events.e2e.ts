import { test, expect, fillEvent } from './fixtures';

test('admin creates, inspects, edits and deletes an event', async ({
  admin: page,
  api,
  events,
}) => {
  const event = events.draft('crud');
  await page.getByRole('link', { name: 'Create event' }).click();
  await fillEvent(page, event);
  await page.getByRole('button', { name: 'Create event', exact: true }).click();
  await expect(page.getByRole('heading', { name: event.title, exact: true })).toBeVisible();
  const id = new URL(page.url()).pathname.split('/').pop()!;
  await page.reload();
  await expect(page.getByText(event.description!, { exact: true })).toBeVisible();
  await expect(page.getByText('12 places', { exact: true })).toBeVisible();
  await page.getByRole('link', { name: 'Edit details' }).click();
  const edited = {
    ...event,
    title: events.draft('edited').title,
    capacity: 18,
    location: 'Updated E2E court',
  };
  await fillEvent(page, edited);
  await page.getByRole('button', { name: 'Save changes' }).click();
  await expect(page.getByRole('heading', { name: edited.title, exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByText('18 places', { exact: true })).toBeVisible();
  await expect(page.getByText(edited.location, { exact: true }).first()).toBeVisible();
  await page.getByRole('button', { name: 'Delete event', exact: true }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Cancel', exact: true }).click();
  await expect(page.getByRole('dialog')).not.toBeVisible();
  await expect(page.getByRole('heading', { name: edited.title, exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Delete event', exact: true }).click();
  await page.getByRole('dialog').getByRole('button', { name: 'Delete event', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Events', exact: true })).toBeVisible();
  await expect(page.getByRole('status').filter({ hasText: 'Event deleted.' })).toBeVisible();
  expect((await api.get(`/api/events/${id}`)).status()).toBe(404);
});

test('sport and status filters paginate and preserve list context', async ({
  admin: page,
  api,
  events,
}) => {
  const first = await events.create('first');
  const second = await events.create('second');
  const cancelled = await events.create('cancelled');
  expect(
    (
      await api.patch(`/api/events/${cancelled.id}/status`, { data: { status: 'CANCELLED' } })
    ).status(),
  ).toBe(200);
  await page.goto('/events?size=1');
  await page.getByLabel('Sport', { exact: true }).fill(events.sport);
  await page.getByLabel('Status', { exact: true }).selectOption('SCHEDULED');
  await page.getByRole('button', { name: 'Apply filters' }).click();
  const pagination = page.getByRole('navigation', { name: 'Event pages' });
  await expect(pagination).toContainText('Page 1 of 2 · 2 total');
  await expect(pagination.getByRole('button', { name: 'Previous' })).toBeDisabled();
  const firstTitle = await page.locator('tbody a').innerText();
  await pagination.getByRole('button', { name: 'Next' }).click();
  await expect(pagination).toContainText('Page 2 of 2 · 2 total');
  await expect(pagination.getByRole('button', { name: 'Next' })).toBeDisabled();
  await expect(page.locator('tbody a')).not.toHaveText(firstTitle);
  const secondTitle = await page.locator('tbody a').innerText();
  expect([firstTitle, secondTitle].map((title) => title.replace('↗', '').trim()).sort()).toEqual(
    [first.title, second.title].sort(),
  );
  await page.locator('tbody a').click();
  await page.getByRole('link', { name: 'All events' }).click();
  await page.reload();
  await expect(pagination).toContainText('Page 2 of 2 · 2 total');
  await expect(page.getByLabel('Sport', { exact: true })).toHaveValue(events.sport);
  await pagination.getByRole('button', { name: 'Previous' }).click();
  await expect(page.locator('tbody a')).toHaveText(firstTitle);
  await page.getByLabel('Status', { exact: true }).selectOption('CANCELLED');
  await page.getByRole('button', { name: 'Apply filters' }).click();
  await expect(page.getByRole('link', { name: cancelled.title })).toBeVisible();
  await expect(pagination).toContainText('Page 1 of 1 · 1 total');
  await page.getByLabel('Status', { exact: true }).selectOption('COMPLETED');
  await page.getByRole('button', { name: 'Apply filters' }).click();
  await expect(page.getByText('No events found', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Clear filters' }).click();
  await expect(page.getByLabel('Sport', { exact: true })).toHaveValue('');
  await expect(page.getByLabel('Status', { exact: true })).toHaveValue('');
  await expect(page).not.toHaveURL(/sport=|status=|page=1/);
});

test('invalid fields block creation and a corrected form saves', async ({
  admin: page,
  events,
}) => {
  const event = events.draft('validation');
  let posts = 0;
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === '/api/events') posts++;
  });
  await page.getByRole('link', { name: 'Create event' }).click();
  await page.getByRole('button', { name: 'Create event', exact: true }).click();
  await expect(page.getByRole('alert')).toContainText('Please review');
  await expect(page.getByLabel('Event title', { exact: true })).toHaveAttribute(
    'aria-invalid',
    'true',
  );
  await fillEvent(page, { ...event, capacity: 0, endsAt: event.startsAt });
  await page.getByRole('button', { name: 'Create event', exact: true }).click();
  await expect(page.getByLabel('Total capacity', { exact: true })).toHaveAttribute(
    'aria-invalid',
    'true',
  );
  expect(posts).toBe(0);
  await expect(page.getByText('End time must be after start time.', { exact: true })).toBeVisible();
  await page.getByLabel('Total capacity', { exact: true }).fill('12');
  await page.getByRole('button', { name: 'Create event', exact: true }).click();
  await expect(page.getByLabel('Ends at (local time)')).toHaveAttribute('aria-invalid', 'true');
  expect(posts).toBe(0);
  await fillEvent(page, event);
  await page.getByRole('button', { name: 'Create event', exact: true }).click();
  await expect(page.getByRole('heading', { name: event.title, exact: true })).toBeVisible();
  expect(posts).toBe(1);
});

test('stale editor surfaces a real backend rejection without changing saved details', async ({
  admin: page,
  api,
  events,
}) => {
  const event = await events.create('stale');
  await page.goto(`/events/${event.id}`);
  await page.getByRole('link', { name: 'Edit details' }).click();
  await page.getByLabel('Location', { exact: true }).fill('Rejected location');
  expect(
    (await api.patch(`/api/events/${event.id}/status`, { data: { status: 'CANCELLED' } })).status(),
  ).toBe(200);
  const rejected = page.waitForResponse(
    (response) =>
      response.request().method() === 'PUT' &&
      new URL(response.url()).pathname === `/api/events/${event.id}`,
  );
  await page.getByRole('button', { name: 'Save changes' }).click();
  expect((await rejected).status()).toBe(409);
  await expect(page.getByRole('alert')).toContainText(
    'Only scheduled events can have their details edited.',
  );
  await expect(page.getByLabel('Location', { exact: true })).toHaveValue('Rejected location');
  const saved = await api.get(`/api/events/${event.id}`);
  expect(await saved.json()).toMatchObject({ location: event.location, status: 'CANCELLED' });
});
