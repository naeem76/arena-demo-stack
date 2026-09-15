import { DatePipe } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { catchError, combineLatest, EMPTY, startWith, Subject, switchMap, tap } from 'rxjs';
import { List$Params } from '../../api/fn/events/list';
import { EventResponse } from '../../api/models/event-response';
import { EventsService } from '../../api/services/events.service';
import { describeApiError } from '../../core/api-error';
import { PageFeedback } from '../../shared/page-feedback';
import { StatusBadge } from '../../shared/status-badge';
import { PageInfo, Pagination, readPagination, recoveryPage } from '../../shared/pagination';

@Component({
  selector: 'app-events-list',
  standalone: true,
  imports: [DatePipe, RouterLink, PageFeedback, StatusBadge, Pagination],
  templateUrl: './events-list.html',
})
export class EventsList {
  private readonly api = inject(EventsService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly reload = new Subject<void>();
  readonly events = signal<EventResponse[]>([]);
  readonly pagination = signal<PageInfo>({ page: 0, size: 20, totalElements: 0, totalPages: 0 });
  readonly loading = signal(true);
  readonly error = signal('');
  readonly sport = signal('');
  readonly status = signal('');
  readonly statuses: EventResponse['status'][] = ['SCHEDULED', 'LIVE', 'COMPLETED', 'CANCELLED'];
  readonly notice = signal<string>(
    typeof history.state?.notice === 'string' ? history.state.notice : '',
  );

  constructor() {
    combineLatest([this.route.queryParamMap, this.reload.pipe(startWith(undefined))])
      .pipe(
        switchMap(([params]) => {
          this.sport.set(params.get('sport') ?? '');
          this.status.set(params.get('status') ?? '');
          this.loading.set(true);
          this.error.set('');
          this.events.set([]);
          const status = this.statuses.find((value) => value === this.status());
          if (this.status() && !status) {
            this.loading.set(false);
            this.error.set('Unknown status filter. Choose a listed status and apply filters.');
            return EMPTY;
          }
          const paging = readPagination(params);
          this.pagination.update((current) => ({ ...current, ...paging }));
          const filters: List$Params = {
            sport: this.sport().trim() || undefined,
            status,
            ...paging,
          };
          return this.api.list(filters).pipe(
            tap((response) => {
              this.pagination.set(response);
              const last = recoveryPage(paging.page, response.totalPages);
              if (last !== null) {
                this.goToPage(last, true);
                return;
              }
              this.events.set(response.items);
              this.loading.set(false);
            }),
            catchError((error) => {
              this.error.set(describeApiError(error).message);
              this.loading.set(false);
              return EMPTY;
            }),
          );
        }),
        takeUntilDestroyed(),
      )
      .subscribe();
  }

  filter(sport: string, status: string): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: {
        sport: sport.trim() || null,
        status: status || null,
        page: 0,
        size: this.pagination().size,
      },
      queryParamsHandling: 'merge',
    });
  }

  refresh(): void {
    this.reload.next();
  }

  goToPage(page: number, replaceUrl = false): void {
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { page, size: this.pagination().size },
      queryParamsHandling: 'merge',
      replaceUrl,
    });
  }
}
