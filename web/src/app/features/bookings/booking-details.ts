import { DatePipe } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, RouterLink } from '@angular/router';
import {
  catchError,
  combineLatest,
  distinctUntilChanged,
  EMPTY,
  finalize,
  interval,
  map,
  startWith,
  Subject,
  switchMap,
} from 'rxjs';
import { BookingResponse } from '../../api/models/booking-response';
import { BookingsService } from '../../api/services/bookings.service';
import { describeApiError } from '../../core/api-error';
import { AuthService } from '../../core/auth/auth.service';
import { ConfirmDialog } from '../../shared/confirm-dialog';
import { PageFeedback } from '../../shared/page-feedback';
import { StatusBadge } from '../../shared/status-badge';

@Component({
  selector: 'app-booking-details',
  standalone: true,
  imports: [DatePipe, RouterLink, ConfirmDialog, PageFeedback, StatusBadge],
  templateUrl: './booking-details.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class BookingDetails {
  private readonly api = inject(BookingsService);
  private readonly route = inject(ActivatedRoute);
  private readonly auth = inject(AuthService);
  private readonly destroyRef = inject(DestroyRef);
  private readonly reload = new Subject<void>();
  private readonly now = signal(Date.now());
  private currentId = '';
  readonly confirmDialog = viewChild.required(ConfirmDialog);
  readonly booking = signal<BookingResponse | null>(null);
  readonly loading = signal(true);
  readonly error = signal('');
  readonly notFound = signal(false);
  readonly cancelError = signal('');
  readonly success = signal('');
  readonly cancelling = signal(false);

  constructor() {
    interval(1000)
      .pipe(takeUntilDestroyed())
      .subscribe(() => this.now.set(Date.now()));
    combineLatest([
      this.route.paramMap.pipe(
        map((params) => params.get('id') || ''),
        distinctUntilChanged(),
      ),
      this.reload.pipe(startWith(undefined)),
    ])
      .pipe(
        switchMap(([id]) => {
          if (id !== this.currentId) {
            this.cancelError.set('');
            this.success.set('');
          }
          this.currentId = id;
          this.loading.set(true);
          this.error.set('');
          this.notFound.set(false);
          this.booking.set(null);
          if (!id) {
            this.notFound.set(true);
            this.error.set('No booking ID was provided.');
            this.loading.set(false);
            return EMPTY;
          }
          return this.api.get1({ id }).pipe(
            catchError((error) => {
              this.notFound.set(error instanceof HttpErrorResponse && error.status === 404);
              this.error.set(
                this.notFound()
                  ? 'This booking does not exist or is no longer available.'
                  : describeApiError(error).message,
              );
              this.loading.set(false);
              return EMPTY;
            }),
          );
        }),
        takeUntilDestroyed(),
      )
      .subscribe((booking) => {
        this.booking.set(booking);
        this.loading.set(false);
      });
  }

  refresh(): void {
    this.reload.next();
  }

  cancellationUnavailable(): string {
    const booking = this.booking();
    if (!booking || this.loading()) return 'Wait for the booking to load.';
    if (booking.status === 'CANCELLED')
      return 'This booking is already cancelled. Its history is retained.';
    if (this.auth.expired() || !this.auth.authenticated())
      return 'Sign in again before cancelling this booking.';
    if (booking.event.status === 'LIVE' || booking.event.status === 'COMPLETED')
      return 'Bookings cannot be cancelled for live or completed events.';
    if (!(Date.parse(booking.event.startsAt) > Math.max(this.now(), Date.now())))
      return 'Bookings can only be cancelled before the event starts.';
    return '';
  }

  async cancelBooking(): Promise<void> {
    if (this.cancelling() || this.cancellationUnavailable()) return;
    const booking = this.booking()!;
    this.cancelling.set(true);
    this.cancelError.set('');
    this.success.set('');
    let confirmed: boolean;
    try {
      confirmed = await this.confirmDialog().ask({
        title: 'Cancel booking?',
        message: `Cancel ${booking.participant.displayName}'s booking for ${booking.event.title}? The booking will remain in the history.`,
        confirmLabel: 'Cancel booking',
      });
    } catch (error) {
      this.cancelling.set(false);
      if (!this.destroyRef.destroyed && this.currentId === booking.id)
        this.cancelError.set(describeApiError(error).message);
      return;
    }
    if (
      this.destroyRef.destroyed ||
      !confirmed ||
      this.currentId !== booking.id ||
      this.cancellationUnavailable()
    ) {
      this.cancelling.set(false);
      return;
    }
    this.api
      .cancel({ id: booking.id })
      .pipe(
        takeUntilDestroyed(this.destroyRef),
        finalize(() => this.cancelling.set(false)),
      )
      .subscribe({
        next: (updated) => {
          if (this.currentId !== booking.id) return;
          this.booking.set(updated);
          this.success.set('Booking cancelled. The booking history has been retained.');
        },
        error: (error) => {
          if (this.currentId !== booking.id) return;
          this.cancelError.set(describeApiError(error).message);
          if (error instanceof HttpErrorResponse && error.status === 409) this.refresh();
        },
      });
  }
}
