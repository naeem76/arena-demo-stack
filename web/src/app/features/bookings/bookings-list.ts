import { DatePipe } from '@angular/common';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import {
  catchError,
  combineLatest,
  distinctUntilChanged,
  EMPTY,
  map,
  of,
  startWith,
  Subject,
  switchMap,
} from 'rxjs';
import { BookingResponse } from '../../api/models/booking-response';
import { EventResponse } from '../../api/models/event-response';
import { BookingsService } from '../../api/services/bookings.service';
import { EventsService } from '../../api/services/events.service';
import { describeApiError } from '../../core/api-error';
import { PageFeedback } from '../../shared/page-feedback';
import { StatusBadge } from '../../shared/status-badge';
import { PageInfo, Pagination, readPagination, recoveryPage } from '../../shared/pagination';

@Component({
  selector: 'app-bookings-list',
  standalone: true,
  imports: [DatePipe, RouterLink, PageFeedback, StatusBadge, Pagination, FormsModule],
  templateUrl: './bookings-list.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class BookingsList {
  private readonly api = inject(BookingsService);
  private readonly eventsApi = inject(EventsService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly reload = new Subject<void>();
  private readonly reloadEvents = new Subject<void>();
  readonly bookings = signal<BookingResponse[]>([]);
  readonly events = signal<EventResponse[]>([]);
  readonly selectedEvent = signal<EventResponse | null>(null);
  readonly selectedEventError = signal('');
  readonly pagination = signal<PageInfo>({ page: 0, size: 20, totalElements: 0, totalPages: 0 });
  readonly eventPagination = signal<PageInfo>({
    page: 0,
    size: 20,
    totalElements: 0,
    totalPages: 0,
  });
  readonly loading = signal(true);
  readonly error = signal('');
  readonly eventsLoading = signal(true);
  readonly eventsError = signal('');
  readonly eventId = signal('');
  readonly status = signal<BookingResponse['status'] | ''>('');

  constructor() {
    const filters = this.route.queryParamMap.pipe(
      map((params) => ({
        eventId: params.get('eventId') || '',
        status: this.validStatus(params.get('status')),
        ...readPagination(params),
      })),
      distinctUntilChanged(
        (a, b) =>
          a.eventId === b.eventId &&
          a.status === b.status &&
          a.page === b.page &&
          a.size === b.size,
      ),
    );
    combineLatest([filters, this.reload.pipe(startWith(undefined))])
      .pipe(
        switchMap(([filter]) => {
          this.eventId.set(filter.eventId);
          this.status.set(filter.status);
          this.pagination.update((current) => ({
            ...current,
            page: filter.page,
            size: filter.size,
          }));
          this.loading.set(true);
          this.error.set('');
          this.bookings.set([]);
          return this.api
            .list1({
              scope: 'all',
              ...(filter.eventId ? { eventId: filter.eventId } : {}),
              ...(filter.status ? { status: filter.status } : {}),
              page: filter.page,
              size: filter.size,
            })
            .pipe(
              catchError((error) => {
                this.error.set(describeApiError(error).message);
                this.loading.set(false);
                return EMPTY;
              }),
            );
        }),
        takeUntilDestroyed(),
      )
      .subscribe((response) => {
        const last = recoveryPage(this.pagination().page, response.totalPages);
        this.pagination.set(response);
        if (last !== null) {
          this.goToPage(last, true);
          return;
        }
        this.bookings.set(response.items);
        this.loading.set(false);
      });
    const eventPages = this.route.queryParamMap.pipe(
      map((params) => readPagination(params, 'eventPage').page),
      distinctUntilChanged(),
    );
    combineLatest([eventPages, this.reloadEvents.pipe(startWith(undefined))])
      .pipe(
        switchMap(([page]) => {
          this.eventsLoading.set(true);
          this.eventsError.set('');
          return this.eventsApi.list({ page, size: 20 }).pipe(
            catchError((error) => {
              this.eventsError.set(describeApiError(error).message);
              this.eventsLoading.set(false);
              return EMPTY;
            }),
          );
        }),
        takeUntilDestroyed(),
      )
      .subscribe((response) => {
        this.eventPagination.set(response);
        const last = recoveryPage(response.page, response.totalPages);
        if (last !== null) {
          this.goToEventPage(last, true);
          return;
        }
        this.events.set(response.items);
        this.eventsLoading.set(false);
      });
    const selectedId = this.route.queryParamMap.pipe(
      map((params) => params.get('eventId') || ''),
      distinctUntilChanged(),
    );
    combineLatest([selectedId, this.reloadEvents.pipe(startWith(undefined))])
      .pipe(
        switchMap(([id]) => {
          this.selectedEventError.set('');
          if (this.selectedEvent()?.id !== id) this.selectedEvent.set(null);
          if (!id) return of(null);
          const selected = this.selectedEvent() ?? this.events().find((event) => event.id === id);
          if (selected) return of(selected);
          return this.eventsApi.get({ id }).pipe(
            catchError((error) => {
              this.selectedEventError.set(describeApiError(error).message);
              return EMPTY;
            }),
          );
        }),
        takeUntilDestroyed(),
      )
      .subscribe((event) => this.selectedEvent.set(event));
  }

  private validStatus(value: string | null): BookingResponse['status'] | '' {
    return value === 'CONFIRMED' || value === 'CANCELLED' ? value : '';
  }

  hasSelectedEvent(): boolean {
    return this.events().some((event) => event.id === this.eventId());
  }

  setFilter(key: 'eventId' | 'status', value: string): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { [key]: value || null, page: 0, size: this.pagination().size },
      queryParamsHandling: 'merge',
    });
  }

  clearFilters(): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { eventId: null, status: null, page: 0, size: this.pagination().size },
      queryParamsHandling: 'merge',
    });
  }

  goToPage(page: number, replaceUrl = false): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { page, size: this.pagination().size },
      queryParamsHandling: 'merge',
      replaceUrl,
    });
  }

  goToEventPage(eventPage: number, replaceUrl = false): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { eventPage },
      queryParamsHandling: 'merge',
      replaceUrl,
    });
  }

  refresh(): void {
    this.reload.next();
  }
  retryEvents(): void {
    this.reloadEvents.next();
  }
}
