import { Component, DestroyRef, HostListener, inject, signal, viewChild } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import {
  catchError,
  combineLatest,
  EMPTY,
  finalize,
  of,
  startWith,
  Subject,
  switchMap,
  tap,
} from 'rxjs';
import { EventRequest } from '../../api/models/event-request';
import { EventResponse } from '../../api/models/event-response';
import { EventsService } from '../../api/services/events.service';
import { describeApiError } from '../../core/api-error';
import { AuthService } from '../../core/auth/auth.service';
import { ConfirmDialog } from '../../shared/confirm-dialog';
import { PageFeedback } from '../../shared/page-feedback';
import { EventDraft, EventForm } from './event-form';

@Component({
  selector: 'app-event-editor',
  standalone: true,
  imports: [RouterLink, EventForm, ConfirmDialog, PageFeedback],
  templateUrl: './event-editor.html',
})
export class EventEditor {
  private readonly api = inject(EventsService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly auth = inject(AuthService);
  private readonly destroyRef = inject(DestroyRef);
  private readonly reload = new Subject<void>();
  private draftKey = '';
  private saved = false;
  readonly confirm = viewChild.required(ConfirmDialog);
  readonly id = signal<string | null>(null);
  readonly initial = signal<EventResponse | undefined>(undefined);
  readonly draft = signal<EventDraft | undefined>(undefined);
  readonly loading = signal(true);
  readonly busy = signal(false);
  readonly dirty = signal(false);
  readonly loadError = signal('');
  readonly saveError = signal('');
  readonly storageError = signal('');
  readonly serverErrors = signal<Record<string, string>>({});

  constructor() {
    combineLatest([this.route.paramMap, this.reload.pipe(startWith(undefined))])
      .pipe(
        switchMap(([params]) => {
          const id = params.get('id');
          this.id.set(id);
          this.initial.set(undefined);
          this.loading.set(true);
          this.loadError.set('');
          this.saveError.set('');
          this.serverErrors.set({});
          this.saved = false;
          this.draftKey = `arena:event-draft:${encodeURIComponent(this.auth.userId())}:${encodeURIComponent(id ?? 'new')}`;
          this.restoreDraft();
          return (id ? this.api.get({ id }) : of<EventResponse | undefined>(undefined)).pipe(
            tap((event) => {
              this.initial.set(event);
              this.loading.set(false);
            }),
            catchError((error) => {
              this.loadError.set(describeApiError(error).message);
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
    this.reload.next();
  }

  private restoreDraft(): void {
    this.draft.set(undefined);
    this.dirty.set(false);
    this.storageError.set('');
    try {
      const stored = sessionStorage.getItem(this.draftKey);
      if (!stored) return;
      const value: unknown = JSON.parse(stored);
      if (!value || typeof value !== 'object') throw new Error('Invalid draft');
      const draft = value as Record<string, unknown>;
      if (
        !['title', 'sport', 'location', 'startsAt', 'endsAt', 'description'].every(
          (key) => typeof draft[key] === 'string',
        ) ||
        !(draft['capacity'] === null || typeof draft['capacity'] === 'number')
      )
        throw new Error('Invalid draft');
      this.draft.set(value as EventDraft);
      this.dirty.set(true);
    } catch {
      this.storageError.set(
        'The saved draft could not be restored. Keep this page open until your changes are saved.',
      );
    }
  }

  persistDraft(value: EventDraft): void {
    this.dirty.set(true);
    this.saved = false;
    this.serverErrors.set({});
    try {
      sessionStorage.setItem(this.draftKey, JSON.stringify(value));
      this.storageError.set('');
    } catch {
      this.storageError.set(
        'Draft storage is unavailable. Keep this page open until your changes are saved.',
      );
    }
  }

  private removeDraft(): void {
    try {
      sessionStorage.removeItem(this.draftKey);
    } catch {
      this.storageError.set('The saved draft could not be removed from this browser.');
    }
  }

  save(body: EventRequest): void {
    if (
      this.busy() ||
      this.loading() ||
      this.loadError() ||
      (this.id() && this.initial()?.status !== 'SCHEDULED')
    )
      return;
    this.busy.set(true);
    this.saveError.set('');
    this.serverErrors.set({});
    const id = this.id();
    const request = id ? this.api.update({ id, body }) : this.api.create({ body });
    request
      .pipe(
        finalize(() => this.busy.set(false)),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe({
        next: (event) => {
          this.saved = true;
          this.dirty.set(false);
          this.removeDraft();
          void this.router.navigate(['/events', event.id], {
            queryParamsHandling: 'preserve',
            state: { notice: id ? 'Event updated.' : 'Event created.' },
          });
        },
        error: (error) => {
          const problem = describeApiError(error);
          this.saveError.set(problem.message);
          this.serverErrors.set(problem.fields);
        },
      });
  }

  canLeave(): boolean | Promise<boolean> {
    if (this.saved) return true;
    if (this.busy()) return false;
    if (!this.dirty()) return true;
    return this.confirm().ask({
      title: 'Leave with unsaved changes?',
      message:
        'Your changes have not been saved to the event. Any stored draft will be available when you return in this browser tab.',
      confirmLabel: 'Leave page',
    });
  }

  async discard(): Promise<void> {
    if (this.busy()) return;
    if (
      this.dirty() &&
      !(await this.confirm().ask({
        title: 'Discard your changes?',
        message: 'This will remove your unsaved changes and the stored draft.',
        confirmLabel: 'Discard changes',
      }))
    )
      return;
    if (this.destroyRef.destroyed) return;
    this.removeDraft();
    this.dirty.set(false);
    this.saved = true;
    void this.router.navigate(this.id() ? ['/events', this.id()] : ['/events'], {
      queryParamsHandling: 'preserve',
    });
  }

  @HostListener('window:beforeunload', ['$event'])
  beforeUnload(event: BeforeUnloadEvent): void {
    if (this.dirty() && !this.saved) {
      event.preventDefault();
      event.returnValue = '';
    }
  }
}
