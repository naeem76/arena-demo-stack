import { TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';
import { of } from 'rxjs';
import { EventResponse } from './api/models/event-response';
import { EventsService } from './api/services/events.service';
import { BookingsService } from './api/services/bookings.service';
import { AuthService } from './core/auth/auth.service';
import { EventsList } from './features/events/events-list';
import { EventDetails } from './features/events/events-details';
import { EventEditor } from './features/events/event-editor';
import { BookingsList } from './features/bookings/bookings-list';
import { BookingDetails } from './features/bookings/booking-details';

describe('List navigation context', () => {
  const event: EventResponse = {
    id: 'event-1',
    title: 'Tennis session',
    sport: 'Tennis',
    location: 'Court 1',
    status: 'SCHEDULED',
    capacity: 10,
    startsAt: '2099-01-01T10:00:00Z',
    endsAt: '2099-01-01T11:00:00Z',
    createdAt: '2026-01-01T10:00:00Z',
    updatedAt: '2026-01-01T10:00:00Z',
  };
  const booking = {
    id: 'booking-1',
    event,
    status: 'CONFIRMED',
    participant: { id: 'user-1', displayName: 'Alex' },
    createdAt: event.createdAt,
    updatedAt: event.updatedAt,
  };
  const eventContext = { page: '2', size: '10', sport: 'Tennis', status: 'SCHEDULED' };
  let harness: RouterTestingHarness;
  let events: {
    list: ReturnType<typeof vi.fn>;
    get: ReturnType<typeof vi.fn>;
    update: ReturnType<typeof vi.fn>;
    delete: ReturnType<typeof vi.fn>;
  };
  let bookings: { list1: ReturnType<typeof vi.fn>; get1: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    sessionStorage.clear();
    events = {
      list: vi.fn(({ page = 0, size = 20 }) =>
        of({ items: [event], page, size, totalElements: 21, totalPages: Math.ceil(21 / size) }),
      ),
      get: vi.fn(() => of(event)),
      update: vi.fn(() => of(event)),
      delete: vi.fn(() => of(undefined)),
    };
    bookings = {
      list1: vi.fn(({ page = 0, size = 20 }) =>
        of({ items: [booking], page, size, totalElements: 41, totalPages: Math.ceil(41 / size) }),
      ),
      get1: vi.fn(() => of(booking)),
    };
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: 'events', component: EventsList },
          { path: 'events/new', component: EventEditor },
          { path: 'events/:id/edit', component: EventEditor },
          { path: 'events/:id', component: EventDetails },
          { path: 'bookings', component: BookingsList },
          { path: 'bookings/:id', component: BookingDetails },
        ]),
        { provide: EventsService, useValue: events },
        { provide: BookingsService, useValue: bookings },
        {
          provide: AuthService,
          useValue: { userId: () => 'admin-1', expired: () => false, authenticated: () => true },
        },
      ],
    });
    harness = await RouterTestingHarness.create();
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    sessionStorage.clear();
  });

  function link(text: string): string {
    const anchor = [...harness.routeNativeElement!.querySelectorAll('a')].find((item) =>
      item.textContent?.includes(text),
    );
    expect(anchor, `Link containing ${text}`).toBeDefined();
    return anchor!.getAttribute('href')!;
  }

  function expectContext(path: string, context = eventContext): void {
    const router = TestBed.inject(Router);
    expect(router.url.split('?')[0]).toBe(path);
    expect(router.parseUrl(router.url).queryParams).toEqual(context);
  }

  it('retains event list context through details, edit back, discard, save and list return', async () => {
    await harness.navigateByUrl('/events?page=2&size=10&sport=Tennis&status=SCHEDULED');
    await harness.navigateByUrl(link('Tennis session'));
    expectContext('/events/event-1');
    await harness.navigateByUrl(link('Edit details'));
    expectContext('/events/event-1/edit');
    await harness.navigateByUrl(link('Event overview'));
    expectContext('/events/event-1');
    let editor = await harness.navigateByUrl(link('Edit details'), EventEditor);
    await editor.discard();
    await harness.fixture.whenStable();
    expectContext('/events/event-1');
    harness.detectChanges();
    editor = await harness.navigateByUrl(link('Edit details'), EventEditor);
    editor.save({ ...event, description: event.description ?? undefined });
    await harness.fixture.whenStable();
    expectContext('/events/event-1');
    harness.detectChanges();
    await harness.navigateByUrl(link('All events'));
    expectContext('/events');
    expect(events.list).toHaveBeenLastCalledWith({
      page: 2,
      size: 10,
      sport: 'Tennis',
      status: 'SCHEDULED',
    });
  });

  it('returns deletion to the original last page before recovering to the new last page', async () => {
    await harness.navigateByUrl('/events?page=2&size=10&sport=Tennis&status=SCHEDULED');
    const details = await harness.navigateByUrl(link('Tennis session'), EventDetails);
    vi.spyOn(details.confirm(), 'ask').mockResolvedValue(true);
    events.list.mockImplementation(({ page, size }) =>
      of({ items: page > 1 ? [] : [event], page, size, totalElements: 20, totalPages: 2 }),
    );
    events.list.mockClear();
    await details.deleteEvent();
    await harness.fixture.whenStable();
    expect(events.delete).toHaveBeenCalledExactlyOnceWith({ id: 'event-1' });
    expect(events.list.mock.calls.map(([params]) => params.page)).toEqual([2, 1]);
    expectContext('/events', { ...eventContext, page: '1' });
    expect(events.list).toHaveBeenLastCalledWith({
      page: 1,
      size: 10,
      sport: 'Tennis',
      status: 'SCHEDULED',
    });
  });

  it('starts bookings at page zero with only the event filter when crossing from event details', async () => {
    await harness.navigateByUrl('/events/event-1?page=2&size=10&sport=Tennis&status=SCHEDULED');
    await harness.navigateByUrl(link('View bookings'));
    const router = TestBed.inject(Router);
    expect(router.parseUrl(router.url).queryParams).toEqual({
      eventId: 'event-1',
      page: '0',
      size: '20',
    });
    expect(bookings.list1).toHaveBeenLastCalledWith({
      eventId: 'event-1',
      scope: 'all',
      page: 0,
      size: 20,
    });
  });

  it('retains booking page, size, filters and option page through detail and back', async () => {
    const url = '/bookings?page=2&size=10&eventId=event-1&status=CONFIRMED&eventPage=1';
    await harness.navigateByUrl(url);
    await harness.navigateByUrl(link('View details'));
    const router = TestBed.inject(Router);
    const context = router.parseUrl(url).queryParams;
    expect(router.parseUrl(router.url).queryParams).toEqual(context);
    await harness.navigateByUrl(link('Back to bookings'));
    expect(router.url.split('?')[0]).toBe('/bookings');
    expect(router.parseUrl(router.url).queryParams).toEqual(context);
    expect(bookings.list1).toHaveBeenLastCalledWith({
      page: 2,
      size: 10,
      eventId: 'event-1',
      status: 'CONFIRMED',
      scope: 'all',
    });
  });
});
