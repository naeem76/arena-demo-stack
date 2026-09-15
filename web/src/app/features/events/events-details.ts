import { DatePipe } from '@angular/common';
import { Component, DestroyRef, inject, signal, viewChild } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import {
  catchError,
  combineLatest,
  EMPTY,
  finalize,
  startWith,
  Subject,
  switchMap,
  tap,
} from 'rxjs';
import { EventResponse } from '../../api/models/event-response';
import { EventsService } from '../../api/services/events.service';
import { describeApiError } from '../../core/api-error';
import { ConfirmDialog } from '../../shared/confirm-dialog';
import { PageFeedback } from '../../shared/page-feedback';
import { StatusBadge } from '../../shared/status-badge';

@Component({
  selector: 'app-event-details',
  standalone: true,
  imports: [DatePipe, RouterLink, ConfirmDialog, PageFeedback, StatusBadge],
  templateUrl: './events-details.html',
})
export class EventDetails {
  private readonly api = inject(EventsService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly destroyRef = inject(DestroyRef);
  private readonly reload = new Subject<void>();
  readonly confirm = viewChild.required(ConfirmDialog);
  readonly event = signal<EventResponse | undefined>(undefined);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly error = signal('');
  readonly actionError = signal('');
  readonly notice = signal<string>(
    typeof history.state?.notice === 'string' ? history.state.notice : '',
  );

  constructor() {
    combineLatest([this.route.paramMap, this.reload.pipe(startWith(undefined))])
      .pipe(
        switchMap(([params]) => {
          this.loading.set(true);
          this.error.set('');
          this.event.set(undefined);
          return this.api.get({ id: params.get('id') ?? '' }).pipe(
            tap((event) => {
              this.event.set(event);
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

  refresh(): void {
    if (!this.busy()) this.reload.next();
  }

  async changeStatus(status: EventResponse['status']): Promise<void> {
    const event = this.event();
    if (!event || this.busy()) return;
    const allowed =
      event.status === 'SCHEDULED'
        ? ['LIVE', 'CANCELLED']
        : event.status === 'LIVE'
          ? ['COMPLETED', 'CANCELLED']
          : [];
    if (!allowed.includes(status)) return;
    this.busy.set(true);
    const accepted = await this.confirm().ask({
      title: `Change status to ${status.toLowerCase()}?`,
      message: `“${event.title}” will move from ${event.status.toLowerCase()} to ${status.toLowerCase()}. This transition cannot be undone.`,
      confirmLabel: 'Change status',
    });
    if (!accepted || this.destroyRef.destroyed || this.event()?.id !== event.id) {
      this.busy.set(false);
      return;
    }
    this.actionError.set('');
    this.notice.set('');
    this.api
      .changeStatus({ id: event.id, body: { status } })
      .pipe(
        finalize(() => this.busy.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe({
        next: (updated) => {
          if (this.event()?.id === event.id) {
            this.event.set(updated);
            this.notice.set('Event status updated.');
          }
        },
        error: (error) => this.actionError.set(describeApiError(error).message),
      });
  }

  async deleteEvent(): Promise<void> {
    const event = this.event();
    if (!event || this.busy()) return;
    this.busy.set(true);
    const accepted = await this.confirm().ask({
      title: 'Delete event?',
      message: `Permanently delete “${event.title}”? Events with booking history cannot be deleted.`,
      confirmLabel: 'Delete event',
    });
    if (!accepted || this.destroyRef.destroyed || this.event()?.id !== event.id) {
      this.busy.set(false);
      return;
    }
    this.actionError.set('');
    this.notice.set('');
    this.api
      .delete({ id: event.id })
      .pipe(
        finalize(() => this.busy.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe({
        next: () => {
          void this.router.navigate(['/events'], { state: { notice: 'Event deleted.' } });
        },
        error: (error) => this.actionError.set(describeApiError(error).message),
      });
  }
}
