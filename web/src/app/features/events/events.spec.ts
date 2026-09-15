import { TestBed } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { ActivatedRoute, convertToParamMap, provideRouter, Router } from '@angular/router';
import { BehaviorSubject, of, Subject } from 'rxjs';
import { EventRequest } from '../../api/models/event-request';
import { EventResponse } from '../../api/models/event-response';
import { EventsService } from '../../api/services/events.service';
import { AuthService } from '../../core/auth/auth.service';
import { EventEditor } from './event-editor';
import { EventDraft, EventForm, toInstant, toLocalDateTime } from './event-form';
import { EventsList } from './events-list';
import { EventPageResponse } from '../../api/models/event-page-response';

const body: EventRequest = {
  title: 'Evening athletics',
  sport: 'Athletics',
  location: 'North stadium',
  capacity: 80,
  startsAt: '2099-06-15T18:30:12.345Z',
  endsAt: '2099-06-15T20:30:12.345Z',
  description: 'Track finals',
};
const event: EventResponse = {
  ...body,
  id: 'event-1',
  status: 'SCHEDULED',
  createdAt: '2026-01-01T00:00:00Z',
  updatedAt: '2026-01-01T00:00:00Z',
};
const draft: EventDraft = {
  ...body,
  description: body.description!,
  startsAt: toLocalDateTime(body.startsAt),
  endsAt: toLocalDateTime(body.endsAt),
};

describe('EventsList pagination', () => {
  let queryParamMap: BehaviorSubject<ReturnType<typeof convertToParamMap>>;
  let list: ReturnType<typeof vi.fn>;
  let navigate: ReturnType<typeof vi.fn>;
  const emptyPage: EventPageResponse = {
    items: [],
    page: 0,
    size: 20,
    totalElements: 0,
    totalPages: 0,
  };

  beforeEach(() => {
    queryParamMap = new BehaviorSubject(convertToParamMap({}));
    list = vi.fn().mockReturnValue(of(emptyPage));
    navigate = vi.fn().mockResolvedValue(true);
    TestBed.configureTestingModule({
      providers: [
        { provide: EventsService, useValue: { list } },
        { provide: ActivatedRoute, useValue: { queryParamMap } },
        { provide: Router, useValue: { navigate } },
      ],
    });
  });
  afterEach(() => TestBed.resetTestingModule());

  it('sends paging and filters to the server, retaining size and resetting page for filters', () => {
    queryParamMap.next(
      convertToParamMap({ page: '2', size: '10', sport: 'Tennis', status: 'LIVE' }),
    );
    list.mockReturnValue(
      of({ ...emptyPage, page: 2, size: 10, items: [event], totalElements: 31, totalPages: 4 }),
    );
    const component = TestBed.runInInjectionContext(() => new EventsList());
    expect(list).toHaveBeenCalledExactlyOnceWith({
      page: 2,
      size: 10,
      sport: 'Tennis',
      status: 'LIVE',
    });
    expect(component.events()).toEqual([event]);
    component.goToPage(3);
    expect(navigate).toHaveBeenLastCalledWith(
      [],
      expect.objectContaining({ queryParams: { page: 3, size: 10 }, queryParamsHandling: 'merge' }),
    );
    component.goToPage(1);
    expect(navigate).toHaveBeenLastCalledWith(
      [],
      expect.objectContaining({ queryParams: { page: 1, size: 10 } }),
    );
    component.filter(' Athletics ', 'SCHEDULED');
    expect(navigate).toHaveBeenLastCalledWith(
      [],
      expect.objectContaining({
        queryParams: { page: 0, size: 10, sport: 'Athletics', status: 'SCHEDULED' },
      }),
    );
    component.filter('', '');
    expect(navigate).toHaveBeenLastCalledWith(
      [],
      expect.objectContaining({ queryParams: { page: 0, size: 10, sport: null, status: null } }),
    );
  });

  it('cancels stale page requests when navigating back or forward', () => {
    const old = new Subject<EventPageResponse>();
    list
      .mockReturnValueOnce(old)
      .mockReturnValueOnce(
        of({ ...emptyPage, page: 1, totalPages: 2, totalElements: 21, items: [event] }),
      );
    const component = TestBed.runInInjectionContext(() => new EventsList());
    queryParamMap.next(convertToParamMap({ page: '1' }));
    expect(old.observed).toBe(false);
    old.next(emptyPage);
    expect(component.events()).toEqual([event]);
    expect(list).toHaveBeenLastCalledWith(expect.objectContaining({ page: 1, size: 20 }));
  });

  it('recovers a deleted last row on refresh, then loads the last available page', () => {
    queryParamMap.next(convertToParamMap({ page: '2' }));
    list.mockReturnValueOnce(
      of({ ...emptyPage, page: 2, totalPages: 3, totalElements: 41, items: [event] }),
    );
    const component = TestBed.runInInjectionContext(() => new EventsList());
    list.mockReturnValueOnce(of({ ...emptyPage, page: 2, totalPages: 2, totalElements: 40 }));
    component.refresh();
    expect(navigate).toHaveBeenCalledExactlyOnceWith(
      [],
      expect.objectContaining({ queryParams: { page: 1, size: 20 }, replaceUrl: true }),
    );
    list.mockReturnValueOnce(
      of({ ...emptyPage, page: 1, totalPages: 2, totalElements: 40, items: [event] }),
    );
    queryParamMap.next(convertToParamMap({ page: '1' }));
    expect(component.events()).toEqual([event]);
    expect(component.loading()).toBe(false);
    expect(navigate).toHaveBeenCalledTimes(1);
  });

  it('recovers an out-of-range URL to zero without looping on an empty dataset', () => {
    queryParamMap.next(convertToParamMap({ page: '99' }));
    list.mockReturnValueOnce(of({ ...emptyPage, page: 99 }));
    const component = TestBed.runInInjectionContext(() => new EventsList());
    expect(navigate).toHaveBeenCalledExactlyOnceWith(
      [],
      expect.objectContaining({ queryParams: { page: 0, size: 20 }, replaceUrl: true }),
    );
    queryParamMap.next(convertToParamMap({ page: '0' }));
    expect(component.loading()).toBe(false);
    expect(component.events()).toEqual([]);
    expect(navigate).toHaveBeenCalledTimes(1);
    expect(list).toHaveBeenCalledTimes(2);
  });
});

describe('EventForm', () => {
  beforeEach(() => TestBed.configureTestingModule({ imports: [EventForm] }));
  afterEach(() => TestBed.resetTestingModule());

  it('requires nonblank text, valid times, and positive integer total capacity', () => {
    const fixture = TestBed.createComponent(EventForm);
    fixture.detectChanges();
    const component = fixture.componentInstance;
    expect(component.form.valid).toBe(false);
    component.form.setValue(draft);
    expect(component.form.valid).toBe(true);
    for (const capacity of [0, -1, 1.5, null]) {
      component.form.controls.capacity.setValue(capacity);
      expect(component.form.controls.capacity.invalid).toBe(true);
    }
    component.form.controls.title.setValue('   ');
    expect(component.form.controls.title.hasError('required')).toBe(true);
    component.form.controls.startsAt.setValue('not a date');
    expect(component.form.controls.startsAt.hasError('date')).toBe(true);
  });

  it('enforces each DTO text limit including the optional description', () => {
    const fixture = TestBed.createComponent(EventForm);
    fixture.detectChanges();
    const form = fixture.componentInstance.form;
    form.setValue(draft);
    for (const [key, limit] of [
      ['title', 150],
      ['sport', 50],
      ['location', 200],
      ['description', 2000],
    ] as const) {
      form.controls[key].setValue('a'.repeat(limit));
      expect(form.controls[key].valid).toBe(true);
      form.controls[key].setValue('a'.repeat(limit + 1));
      expect(form.controls[key].hasError('maxlength')).toBe(true);
    }
    form.controls.description.setValue('');
    expect(form.controls.description.valid).toBe(true);
  });

  it('rejects past starts for creation, permits them when editing, and always requires end after start', () => {
    const fixture = TestBed.createComponent(EventForm);
    fixture.detectChanges();
    const form = fixture.componentInstance.form;
    const past = { ...draft, startsAt: '2020-01-01T10:00', endsAt: '2020-01-01T11:00' };
    form.setValue(past);
    expect(form.hasError('future')).toBe(true);
    fixture.componentRef.setInput('initial', event);
    fixture.detectChanges();
    form.setValue(past);
    expect(form.valid).toBe(true);
    form.controls.endsAt.setValue(past.startsAt);
    expect(form.hasError('order')).toBe(true);
    form.controls.endsAt.setValue('2020-01-01T09:00');
    expect(form.hasError('order')).toBe(true);
  });

  it('rechecks the clock on submit and emits nothing for invalid or busy forms', () => {
    const fixture = TestBed.createComponent(EventForm);
    fixture.detectChanges();
    const component = fixture.componentInstance;
    const emitted = vi.fn();
    component.validEventRequest.subscribe(emitted);
    component.submit();
    expect(emitted).not.toHaveBeenCalled();
    component.form.setValue(draft);
    fixture.componentRef.setInput('busy', true);
    component.submit();
    expect(emitted).not.toHaveBeenCalled();
    fixture.componentRef.setInput('busy', false);
    const clock = vi.spyOn(Date, 'now').mockReturnValue(new Date(body.startsAt).getTime());
    component.submit();
    expect(component.form.hasError('future')).toBe(true);
    expect(emitted).not.toHaveBeenCalled();
    clock.mockRestore();
  });

  it.each(['2099-01-15T10:20:30.123Z', '2099-07-15T10:20:30.456Z'])(
    'round-trips local datetime without losing the instant: %s',
    (iso) => {
      const local = toLocalDateTime(iso);
      expect(Number(local.slice(11, 13))).toBe(new Date(iso).getHours());
      expect(toInstant(local)).toBe(iso);
    },
  );

  it('preserves unchanged API instants across repeated daylight-saving wall times', () => {
    const fixture = TestBed.createComponent(EventForm);
    const fallbackEvent = {
      ...event,
      startsAt: '2026-11-01T05:45:00.000Z',
      endsAt: '2026-11-01T06:15:00.000Z',
    };
    fixture.componentRef.setInput('initial', fallbackEvent);
    fixture.detectChanges();
    const emitted = vi.fn();
    fixture.componentInstance.validEventRequest.subscribe(emitted);
    fixture.componentInstance.submit();
    expect(emitted).toHaveBeenCalledWith(
      expect.objectContaining({ startsAt: fallbackEvent.startsAt, endsAt: fallbackEvent.endsAt }),
    );
  });
});

describe('EventEditor shared form and drafts', () => {
  let params: BehaviorSubject<ReturnType<typeof convertToParamMap>>;
  let result: Subject<EventResponse>;
  let api: {
    get: ReturnType<typeof vi.fn>;
    create: ReturnType<typeof vi.fn>;
    update: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    sessionStorage.clear();
    params = new BehaviorSubject(convertToParamMap({}));
    result = new Subject<EventResponse>();
    api = { get: vi.fn(() => of(event)), create: vi.fn(() => result), update: vi.fn(() => result) };
    TestBed.configureTestingModule({
      imports: [EventEditor],
      providers: [
        provideRouter([]),
        { provide: ActivatedRoute, useValue: { paramMap: params } },
        { provide: EventsService, useValue: api },
        { provide: AuthService, useValue: { userId: () => 'admin-1' } },
      ],
    });
    vi.spyOn(TestBed.inject(Router), 'navigate').mockResolvedValue(true);
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    sessionStorage.clear();
    vi.restoreAllMocks();
  });

  it.each([false, true])(
    'submits the reused form to the correct API operation (editing=%s)',
    (editing) => {
      if (editing) params.next(convertToParamMap({ id: event.id }));
      const fixture = TestBed.createComponent(EventEditor);
      fixture.detectChanges();
      const form = fixture.debugElement.query(By.directive(EventForm))
        .componentInstance as EventForm;
      form.form.setValue(draft);
      const key = `arena:event-draft:admin-1:${editing ? event.id : 'new'}`;
      expect(JSON.parse(sessionStorage.getItem(key)!)).toEqual(draft);
      fixture.debugElement.query(By.css('form')).triggerEventHandler('ngSubmit', {});
      expect(editing ? api.update : api.create).toHaveBeenCalledWith(
        editing ? { id: event.id, body } : { body },
      );
      expect(editing ? api.create : api.update).not.toHaveBeenCalled();
      expect(fixture.componentInstance.canLeave()).toBe(false);
      result.next(event);
      expect(sessionStorage.getItem(key)).toBeNull();
      expect(fixture.componentInstance.canLeave()).toBe(true);
      expect(TestBed.inject(Router).navigate).toHaveBeenCalledWith(['/events', event.id], {
        queryParamsHandling: 'preserve',
        state: { notice: editing ? 'Event updated.' : 'Event created.' },
      });
    },
  );

  it.each([400, 409, 0])(
    'retains current form values and the draft when saving fails with %s',
    (status) => {
      const fixture = TestBed.createComponent(EventEditor);
      fixture.detectChanges();
      const form = fixture.debugElement.query(By.directive(EventForm))
        .componentInstance as EventForm;
      form.form.setValue(draft);
      form.submit();
      result.error({ status, error: { detail: 'Unable to save these details.' } });
      fixture.detectChanges();
      expect(form.form.getRawValue()).toEqual(draft);
      expect(JSON.parse(sessionStorage.getItem('arena:event-draft:admin-1:new')!)).toEqual(draft);
      expect(fixture.componentInstance.dirty()).toBe(true);
      expect(fixture.componentInstance.busy()).toBe(false);
      expect(fixture.componentInstance.saveError()).toBeTruthy();
      expect(TestBed.inject(Router).navigate).not.toHaveBeenCalled();
    },
  );

  it('restores only the signed-in user’s event draft after remount', () => {
    sessionStorage.setItem(
      'arena:event-draft:someone-else:new',
      JSON.stringify({ ...draft, title: 'Private draft' }),
    );
    let fixture = TestBed.createComponent(EventEditor);
    fixture.detectChanges();
    expect(fixture.componentInstance.draft()).toBeUndefined();
    const form = fixture.debugElement.query(By.directive(EventForm)).componentInstance as EventForm;
    form.form.setValue(draft);
    fixture.destroy();
    fixture = TestBed.createComponent(EventEditor);
    fixture.detectChanges();
    const restored = fixture.debugElement.query(By.directive(EventForm))
      .componentInstance as EventForm;
    expect(restored.form.getRawValue()).toEqual(draft);
    expect(fixture.componentInstance.dirty()).toBe(true);
  });

  it('confirms leaving and removes the draft only on explicit discard', async () => {
    const fixture = TestBed.createComponent(EventEditor);
    fixture.detectChanges();
    fixture.componentInstance.persistDraft(draft);
    const ask = vi.spyOn(fixture.componentInstance.confirm(), 'ask').mockResolvedValue(false);
    expect(await fixture.componentInstance.canLeave()).toBe(false);
    expect(sessionStorage.getItem('arena:event-draft:admin-1:new')).not.toBeNull();
    ask.mockResolvedValue(true);
    expect(await fixture.componentInstance.canLeave()).toBe(true);
    expect(sessionStorage.getItem('arena:event-draft:admin-1:new')).not.toBeNull();
    await fixture.componentInstance.discard();
    expect(sessionStorage.getItem('arena:event-draft:admin-1:new')).toBeNull();
  });

  it('does not expose the editor or call update for a non-scheduled event', () => {
    params.next(convertToParamMap({ id: event.id }));
    api.get.mockReturnValue(of({ ...event, status: 'LIVE' }));
    const fixture = TestBed.createComponent(EventEditor);
    fixture.detectChanges();
    expect(fixture.debugElement.query(By.directive(EventForm))).toBeNull();
    fixture.componentInstance.save(body);
    expect(api.update).not.toHaveBeenCalled();
  });
});
