import { DatePipe } from '@angular/common';
import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import {
  catchError,
  combineLatest,
  distinctUntilChanged,
  EMPTY,
  map,
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

@Component({
  selector: 'app-bookings-list',
  standalone: true,
  imports: [DatePipe, RouterLink, PageFeedback, StatusBadge],
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
      })),
      distinctUntilChanged((a, b) => a.eventId === b.eventId && a.status === b.status),
    );
    combineLatest([filters, this.reload.pipe(startWith(undefined))])
      .pipe(
        switchMap(([filter]) => {
          this.eventId.set(filter.eventId);
          this.status.set(filter.status);
          this.loading.set(true);
          this.error.set('');
          this.bookings.set([]);
          return this.api
            .list1({
              scope: 'all',
              ...(filter.eventId ? { eventId: filter.eventId } : {}),
              ...(filter.status ? { status: filter.status } : {}),
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
      .subscribe((bookings) => {
        this.bookings.set(bookings);
        this.loading.set(false);
      });
    this.reloadEvents
      .pipe(
        startWith(undefined),
        switchMap(() => {
          this.eventsLoading.set(true);
          this.eventsError.set('');
          return this.eventsApi.list().pipe(
            catchError((error) => {
              this.eventsError.set(describeApiError(error).message);
              this.eventsLoading.set(false);
              return EMPTY;
            }),
          );
        }),
        takeUntilDestroyed(),
      )
      .subscribe((events) => {
        this.events.set(events);
        this.eventsLoading.set(false);
      });
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
      queryParams: { [key]: value || null },
      queryParamsHandling: 'merge',
    });
  }

  clearFilters(): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { eventId: null, status: null },
      queryParamsHandling: 'merge',
    });
  }

  refresh(): void {
    this.reload.next();
  }
  retryEvents(): void {
    this.reloadEvents.next();
  }
}
