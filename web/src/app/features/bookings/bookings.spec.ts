import { HttpErrorResponse } from '@angular/common/http';
import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, Router } from '@angular/router';
import { BehaviorSubject, of, Subject, throwError } from 'rxjs';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { BookingResponse } from '../../api/models/booking-response';
import { BookingPageResponse } from '../../api/models/booking-page-response';
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
  let listEvents: ReturnType<typeof vi.fn>;
  let getEvent: ReturnType<typeof vi.fn>;
  const emptyPage = { items: [], page: 0, size: 20, totalElements: 0, totalPages: 0 };

  beforeEach(() => {
    queryParamMap.next(convertToParamMap({}));
    list1 = vi.fn().mockReturnValue(of(emptyPage));
    listEvents = vi.fn().mockReturnValue(of(emptyPage));
    getEvent = vi.fn().mockReturnValue(of(reservation().event));
    navigate = vi.fn().mockResolvedValue(true);
    TestBed.configureTestingModule({
      providers: [
        { provide: BookingsService, useValue: { list1 } },
        { provide: EventsService, useValue: { list: listEvents, get: getEvent } },
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
      page: 0,
      size: 20,
      eventId: 'event-1',
      status: 'CANCELLED',
    });
    component.refresh();
    queryParamMap.next(convertToParamMap({ status: 'invalid' }));
    expect(list1).toHaveBeenLastCalledWith({ scope: 'all', page: 0, size: 20 });
    list1.mockReturnValueOnce(throwError(() => new HttpErrorResponse({ status: 500 })));
    component.refresh();
    expect(component.error()).not.toBe('');
    expect(component.loading()).toBe(false);
    component.refresh();
    expect(component.error()).toBe('');
    expect(list1.mock.calls.every(([params]) => params.scope === 'all')).toBe(true);
  });

  it('cancels stale requests when URL filters change', () => {
    const oldRequest = new Subject<BookingPageResponse>();
    const newRequest = new Subject<BookingPageResponse>();
    list1.mockReturnValueOnce(oldRequest).mockReturnValueOnce(newRequest);
    const component = TestBed.runInInjectionContext(() => new BookingsList());
    queryParamMap.next(convertToParamMap({ eventId: 'event-1' }));
    expect(oldRequest.observed).toBe(false);
    newRequest.next({ ...emptyPage, items: [reservation()], totalElements: 1, totalPages: 1 });
    oldRequest.next(emptyPage);
    expect(component.bookings()).toHaveLength(1);
    expect(component.loading()).toBe(false);
  });

  it('writes filters to the URL and clears only booking filters', () => {
    const component = TestBed.runInInjectionContext(() => new BookingsList());
    component.setFilter('eventId', 'event-1');
    expect(navigate).toHaveBeenLastCalledWith(
      [],
      expect.objectContaining({
        queryParams: { eventId: 'event-1', page: 0, size: 20 },
        queryParamsHandling: 'merge',
      }),
    );
    component.clearFilters();
    expect(navigate).toHaveBeenLastCalledWith(
      [],
      expect.objectContaining({
        queryParams: { eventId: null, status: null, page: 0, size: 20 },
        queryParamsHandling: 'merge',
      }),
    );
  });

  it('pages server-side with URL size and retains filters during navigation', () => {
    queryParamMap.next(convertToParamMap({ page: '2', size: '10', status: 'CONFIRMED' }));
    list1.mockReturnValue(
      of({ ...emptyPage, page: 2, size: 10, totalElements: 31, totalPages: 4 }),
    );
    const component = TestBed.runInInjectionContext(() => new BookingsList());
    expect(list1).toHaveBeenLastCalledWith({
      scope: 'all',
      page: 2,
      size: 10,
      status: 'CONFIRMED',
    });
    component.goToPage(3);
    expect(navigate).toHaveBeenLastCalledWith(
      [],
      expect.objectContaining({ queryParams: { page: 3, size: 10 }, queryParamsHandling: 'merge' }),
    );
    component.setFilter('status', 'CANCELLED');
    expect(navigate).toHaveBeenLastCalledWith(
      [],
      expect.objectContaining({ queryParams: { page: 0, size: 10, status: 'CANCELLED' } }),
    );
  });

  it('recovers an empty last page after refresh and settles on an empty dataset', () => {
    queryParamMap.next(convertToParamMap({ page: '1' }));
    list1.mockReturnValueOnce(
      of({ ...emptyPage, page: 1, totalElements: 21, totalPages: 2, items: [reservation()] }),
    );
    const component = TestBed.runInInjectionContext(() => new BookingsList());
    list1.mockReturnValueOnce(of({ ...emptyPage, page: 1, totalElements: 20, totalPages: 1 }));
    component.refresh();
    expect(navigate).toHaveBeenCalledExactlyOnceWith(
      [],
      expect.objectContaining({ queryParams: { page: 0, size: 20 }, replaceUrl: true }),
    );
    queryParamMap.next(convertToParamMap({ page: '0' }));
    expect(component.bookings()).toEqual([]);
    expect(component.loading()).toBe(false);
    expect(navigate).toHaveBeenCalledTimes(1);
  });

  it('loads only the requested event-option page and retains an off-page selected title', () => {
    queryParamMap.next(convertToParamMap({ eventId: 'event-1', eventPage: '3' }));
    listEvents.mockImplementation(({ page }) =>
      of({
        ...emptyPage,
        page,
        totalPages: 5,
        totalElements: 100,
        items: [{ ...reservation().event, id: `option-${page}` }],
      }),
    );
    const component = TestBed.runInInjectionContext(() => new BookingsList());
    expect(listEvents).toHaveBeenCalledExactlyOnceWith({ page: 3, size: 20 });
    expect(getEvent).toHaveBeenCalledExactlyOnceWith({ id: 'event-1' });
    expect(component.selectedEvent()?.title).toBe('Evening tennis');
    component.goToEventPage(4);
    expect(navigate).toHaveBeenLastCalledWith(
      [],
      expect.objectContaining({ queryParams: { eventPage: 4 }, queryParamsHandling: 'merge' }),
    );
    queryParamMap.next(convertToParamMap({ eventId: 'event-1', eventPage: '4' }));
    expect(listEvents).toHaveBeenCalledTimes(2);
    expect(listEvents).toHaveBeenLastCalledWith({ page: 4, size: 20 });
    expect(list1).toHaveBeenCalledTimes(1);
    expect(getEvent).toHaveBeenCalledTimes(1);
    expect(component.selectedEvent()?.title).toBe('Evening tennis');
    expect(component.events()).toHaveLength(1);
  });

  it('keeps the native selected label when its option moves off-page and back', async () => {
    queryParamMap.next(convertToParamMap({ eventId: 'event-1' }));
    listEvents.mockImplementation(({ page }) =>
      of({
        ...emptyPage,
        page,
        totalElements: 21,
        totalPages: 2,
        items:
          page === 0
            ? [reservation().event]
            : [{ ...reservation().event, id: 'event-2', title: 'Other event' }],
      }),
    );
    const fixture = TestBed.createComponent(BookingsList);
    fixture.detectChanges();
    await fixture.whenStable();
    const select = fixture.nativeElement.querySelector('#booking-event') as HTMLSelectElement;
    expect(select.selectedOptions[0].textContent?.trim()).toBe('Evening tennis');
    queryParamMap.next(convertToParamMap({ eventId: 'event-1', eventPage: '1' }));
    fixture.detectChanges();
    await fixture.whenStable();
    expect(select.selectedOptions[0].textContent?.trim()).toBe('Evening tennis');
    expect(select.options).toHaveLength(3);
    queryParamMap.next(convertToParamMap({ eventId: 'event-1', eventPage: '0' }));
    fixture.detectChanges();
    await fixture.whenStable();
    expect(select.selectedOptions[0].textContent?.trim()).toBe('Evening tennis');
    expect(select.options).toHaveLength(2);
    expect(listEvents).toHaveBeenCalledTimes(3);
    expect(getEvent).not.toHaveBeenCalled();
  });

  it('cancels stale selected-event lookups and allows retry after lookup failure', () => {
    const pending = new Subject<BookingResponse['event']>();
    getEvent
      .mockReturnValueOnce(pending)
      .mockReturnValueOnce(throwError(() => new HttpErrorResponse({ status: 404 })));
    queryParamMap.next(convertToParamMap({ eventId: 'old-event' }));
    const component = TestBed.runInInjectionContext(() => new BookingsList());
    queryParamMap.next(convertToParamMap({ eventId: 'event-1' }));
    expect(pending.observed).toBe(false);
    expect(component.selectedEventError()).not.toBe('');
    component.retryEvents();
    expect(component.selectedEventError()).toBe('');
    expect(component.selectedEvent()?.title).toBe('Evening tennis');
    queryParamMap.next(convertToParamMap({}));
    expect(component.selectedEvent()).toBeNull();
  });

  it('uses an on-page event without a lookup and recovers out-of-range option pages', () => {
    listEvents.mockReturnValueOnce(
      of({ ...emptyPage, items: [reservation().event], totalElements: 1, totalPages: 1 }),
    );
    const component = TestBed.runInInjectionContext(() => new BookingsList());
    queryParamMap.next(convertToParamMap({ eventId: 'event-1' }));
    expect(getEvent).not.toHaveBeenCalled();
    expect(component.selectedEvent()?.title).toBe('Evening tennis');
    listEvents.mockReturnValueOnce(of({ ...emptyPage, page: 9 }));
    queryParamMap.next(convertToParamMap({ eventId: 'event-1', eventPage: '9' }));
    expect(navigate).toHaveBeenLastCalledWith(
      [],
      expect.objectContaining({ queryParams: { eventPage: 0 }, replaceUrl: true }),
    );
    queryParamMap.next(convertToParamMap({ eventId: 'event-1', eventPage: '0' }));
    expect(navigate).toHaveBeenCalledTimes(1);
    expect(component.eventsLoading()).toBe(false);
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
