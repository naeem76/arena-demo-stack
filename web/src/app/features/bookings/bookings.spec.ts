import { HttpErrorResponse } from '@angular/common/http';
import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, Router } from '@angular/router';
import { BehaviorSubject, of, Subject, throwError } from 'rxjs';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { BookingResponse } from '../../api/models/booking-response';
import { BookingsService } from '../../api/services/bookings.service';
import { EventsService } from '../../api/services/events.service';
import { AuthService } from '../../core/auth/auth.service';
import { ConfirmDialog } from '../../shared/confirm-dialog';
import { BookingDetails } from './booking-details';
import { BookingsList } from './bookings-list';

function reservation(): BookingResponse {
  const timestamp = new Date().toISOString();
  return {
    id: 'booking-1',
    status: 'CONFIRMED',
    createdAt: timestamp,
    updatedAt: timestamp,
    participant: { id: 'participant-1', displayName: 'Alex Rivera' },
    event: {
      id: 'event-1',
      title: 'Evening tennis',
      status: 'SCHEDULED',
      location: 'Court 1',
      sport: 'Tennis',
      capacity: 8,
      startsAt: new Date(Date.now() + 3_600_000).toISOString(),
      endsAt: new Date(Date.now() + 7_200_000).toISOString(),
      createdAt: timestamp,
      updatedAt: timestamp,
    },
  };
}

afterEach(() => TestBed.resetTestingModule());

describe('BookingsList admin scope and filters', () => {
  const queryParamMap = new BehaviorSubject(convertToParamMap({}));
  let list1: ReturnType<typeof vi.fn>;
  let navigate: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    queryParamMap.next(convertToParamMap({}));
    list1 = vi.fn().mockReturnValue(of([]));
    navigate = vi.fn().mockResolvedValue(true);
    TestBed.configureTestingModule({
      providers: [
        { provide: BookingsService, useValue: { list1 } },
        { provide: EventsService, useValue: { list: vi.fn().mockReturnValue(of([])) } },
        { provide: ActivatedRoute, useValue: { queryParamMap } },
        { provide: Router, useValue: { navigate } },
      ],
    });
  });

  it('always sends scope=all, including incoming event filters, refresh and retry', () => {
    queryParamMap.next(
      convertToParamMap({ eventId: 'event-1', status: 'CANCELLED', scope: 'mine' }),
    );
    const component = TestBed.runInInjectionContext(() => new BookingsList());
    expect(list1).toHaveBeenLastCalledWith({
      scope: 'all',
      eventId: 'event-1',
      status: 'CANCELLED',
    });
    component.refresh();
    queryParamMap.next(convertToParamMap({ status: 'invalid' }));
    expect(list1).toHaveBeenLastCalledWith({ scope: 'all' });
    list1.mockReturnValueOnce(throwError(() => new HttpErrorResponse({ status: 500 })));
    component.refresh();
    expect(component.error()).not.toBe('');
    expect(component.loading()).toBe(false);
    component.refresh();
    expect(component.error()).toBe('');
    expect(list1.mock.calls.every(([params]) => params.scope === 'all')).toBe(true);
  });

  it('cancels stale requests when URL filters change', () => {
    const oldRequest = new Subject<BookingResponse[]>();
    const newRequest = new Subject<BookingResponse[]>();
    list1.mockReturnValueOnce(oldRequest).mockReturnValueOnce(newRequest);
    const component = TestBed.runInInjectionContext(() => new BookingsList());
    queryParamMap.next(convertToParamMap({ eventId: 'event-1' }));
    expect(oldRequest.observed).toBe(false);
    newRequest.next([reservation()]);
    oldRequest.next([]);
    expect(component.bookings()).toHaveLength(1);
    expect(component.loading()).toBe(false);
  });

  it('writes filters to the URL and clears only booking filters', () => {
    const component = TestBed.runInInjectionContext(() => new BookingsList());
    component.setFilter('eventId', 'event-1');
    expect(navigate).toHaveBeenLastCalledWith(
      [],
      expect.objectContaining({
        queryParams: { eventId: 'event-1' },
        queryParamsHandling: 'merge',
      }),
    );
    component.clearFilters();
    expect(navigate).toHaveBeenLastCalledWith(
      [],
      expect.objectContaining({
        queryParams: { eventId: null, status: null },
        queryParamsHandling: 'merge',
      }),
    );
  });
});

describe('BookingDetails cancellation lifecycle', () => {
  let booking: BookingResponse;
  let get1: ReturnType<typeof vi.fn>;
  let cancel: ReturnType<typeof vi.fn>;
  const expired = signal(false);
  const authenticated = signal(true);
  const paramMap = new BehaviorSubject(convertToParamMap({ id: 'booking-1' }));

  beforeEach(() => {
    booking = reservation();
    expired.set(false);
    authenticated.set(true);
    paramMap.next(convertToParamMap({ id: 'booking-1' }));
    get1 = vi.fn().mockImplementation(() => of(booking));
    cancel = vi.fn().mockImplementation(() => of({ ...booking, status: 'CANCELLED' }));
    TestBed.configureTestingModule({
      providers: [
        { provide: BookingsService, useValue: { get1, cancel } },
        { provide: ActivatedRoute, useValue: { paramMap } },
        { provide: AuthService, useValue: { expired, authenticated } },
      ],
    });
  });

  function create() {
    const component = TestBed.runInInjectionContext(() => new BookingDetails());
    const ask = vi.fn().mockResolvedValue(true);
    vi.spyOn(component, 'confirmDialog').mockReturnValue({ ask } as unknown as ConfirmDialog);
    return { component, ask };
  }

  it('cancels a confirmed booking even for a cancelled event and retains its history', async () => {
    booking.event.status = 'CANCELLED';
    const { component, ask } = create();
    await component.cancelBooking();
    expect(ask).toHaveBeenCalledOnce();
    expect(cancel).toHaveBeenCalledWith({ id: 'booking-1' });
    expect(component.booking()?.status).toBe('CANCELLED');
    expect(component.booking()?.id).toBe('booking-1');
    expect(component.success()).toContain('history');
    await component.cancelBooking();
    expect(cancel).toHaveBeenCalledOnce();
  });

  it('does not mutate when confirmation is declined', async () => {
    const { component, ask } = create();
    ask.mockResolvedValue(false);
    await component.cancelBooking();
    expect(cancel).not.toHaveBeenCalled();
    expect(component.cancelling()).toBe(false);
  });

  it.each(['LIVE', 'COMPLETED'] as const)(
    'explains why %s events cannot be cancelled',
    async (status) => {
      booking.event.status = status;
      const { component, ask } = create();
      expect(component.cancellationUnavailable()).toContain('live or completed');
      await component.cancelBooking();
      expect(ask).not.toHaveBeenCalled();
      expect(cancel).not.toHaveBeenCalled();
    },
  );

  it('blocks cancellation at the start time and after session expiry', async () => {
    booking.event.startsAt = new Date(Date.now() - 1).toISOString();
    const { component } = create();
    expect(component.cancellationUnavailable()).toContain('before the event starts');
    await component.cancelBooking();
    expect(cancel).not.toHaveBeenCalled();
    component.booking.set(reservation());
    expired.set(true);
    expect(component.cancellationUnavailable()).toContain('Sign in again');
  });

  it('rechecks eligibility after confirmation and prevents duplicate submissions', async () => {
    const { component, ask } = create();
    let confirm!: (value: boolean) => void;
    ask.mockReturnValue(
      new Promise((resolve) => {
        confirm = resolve;
      }),
    );
    const pending = component.cancelBooking();
    await component.cancelBooking();
    expect(ask).toHaveBeenCalledOnce();
    expired.set(true);
    confirm(true);
    await pending;
    expect(cancel).not.toHaveBeenCalled();
    expect(component.cancelling()).toBe(false);
  });

  it('refreshes on 409 while preserving the cancellation error', async () => {
    const { component } = create();
    cancel.mockReturnValue(
      throwError(
        () => new HttpErrorResponse({ status: 409, error: { detail: 'Event already started.' } }),
      ),
    );
    get1.mockReturnValue(of({ ...booking, event: { ...booking.event, status: 'LIVE' } }));
    await component.cancelBooking();
    expect(get1).toHaveBeenCalledTimes(2);
    expect(component.booking()?.event.status).toBe('LIVE');
    expect(component.cancelError()).not.toBe('');
    expect(component.success()).toBe('');
    expect(component.cancelling()).toBe(false);
  });

  it('retains confirmed data on cancellation failure and allows retry', async () => {
    const { component } = create();
    cancel.mockReturnValueOnce(throwError(() => new HttpErrorResponse({ status: 500 })));
    await component.cancelBooking();
    expect(component.booking()?.status).toBe('CONFIRMED');
    expect(component.cancelError()).not.toBe('');
    expect(component.cancelling()).toBe(false);
    await component.cancelBooking();
    expect(component.booking()?.status).toBe('CANCELLED');
    expect(component.cancelError()).toBe('');
  });

  it('shows a missing-booking state on 404 and can retry loading', () => {
    get1.mockReturnValueOnce(throwError(() => new HttpErrorResponse({ status: 404 })));
    const { component } = create();
    expect(component.notFound()).toBe(true);
    expect(component.booking()).toBeNull();
    expect(component.error()).toContain('does not exist');
    expect(component.loading()).toBe(false);
    component.refresh();
    expect(component.notFound()).toBe(false);
    expect(component.booking()?.id).toBe('booking-1');
  });
});
