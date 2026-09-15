import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { firstValueFrom } from 'rxjs';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { provideApiConfiguration } from './api/api-configuration';
import { EventsService } from './api/services/events.service';
import { BookingsService } from './api/services/bookings.service';
import { describeApiError } from './core/api-error';

describe('generated JSON API contracts', () => {
  let http: HttpTestingController;
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideApiConfiguration('https://api.arena.test'),
      ],
    });
    http = TestBed.inject(HttpTestingController);
  });
  afterEach(() => http.verify());

  it('decodes event lists and created records as JSON rather than blobs', async () => {
    const events = TestBed.inject(EventsService);
    const listing = firstValueFrom(events.list());
    const listRequest = http.expectOne('https://api.arena.test/api/events');
    expect(listRequest.request.responseType).toBe('json');
    listRequest.flush([{ id: 'event-1', title: 'Football' }]);
    await expect(listing).resolves.toEqual([{ id: 'event-1', title: 'Football' }]);

    const creation = firstValueFrom(
      events.create({
        body: {
          title: 'Football',
          sport: 'Football',
          location: 'Park',
          capacity: 10,
          startsAt: '2030-01-01T10:00:00Z',
          endsAt: '2030-01-01T11:00:00Z',
        },
      }),
    );
    const createRequest = http.expectOne('https://api.arena.test/api/events');
    expect(createRequest.request.responseType).toBe('json');
    expect(createRequest.request.method).toBe('POST');
    createRequest.flush(
      { id: 'event-2', title: 'Football' },
      { status: 201, statusText: 'Created' },
    );
    expect((await creation).id).toBe('event-2');
  });

  it('preserves Problem Details when a bodyless delete returns a text-encoded conflict', async () => {
    const result = firstValueFrom(TestBed.inject(EventsService).delete({ id: 'event-1' })).catch(
      describeApiError,
    );
    const request = http.expectOne('https://api.arena.test/api/events/event-1');
    request.flush(JSON.stringify({ detail: 'Events with booking history cannot be deleted.' }), {
      status: 409,
      statusText: 'Conflict',
    });
    await expect(result).resolves.toEqual({
      message: 'Events with booking history cannot be deleted.',
      fields: {},
    });
  });

  it('decodes admin booking lists as JSON and sends explicit all-user scope', async () => {
    const result = firstValueFrom(
      TestBed.inject(BookingsService).list1({ scope: 'all', status: 'CONFIRMED' }),
    );
    const request = http.expectOne(
      (candidate) => candidate.url === 'https://api.arena.test/api/bookings',
    );
    expect(request.request.params.get('scope')).toBe('all');
    expect(request.request.responseType).toBe('json');
    request.flush([{ id: 'booking-1', participant: { id: 'user-1', displayName: 'Demo User' } }]);
    expect((await result)[0].participant.displayName).toBe('Demo User');
  });
});
