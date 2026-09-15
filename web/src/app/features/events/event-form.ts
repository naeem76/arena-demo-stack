import { Component, DestroyRef, effect, inject, input, output, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import {
  AbstractControl,
  FormControl,
  FormGroup,
  ReactiveFormsModule,
  ValidationErrors,
  Validators,
} from '@angular/forms';
import { EventRequest } from '../../api/models/event-request';
import { EventResponse } from '../../api/models/event-response';

/** datetime-local has no zone; keep local wall time through millisecond precision. */
export function toLocalDateTime(iso: string): string {
  const date = new Date(iso);
  if (!Number.isFinite(date.getTime())) return '';
  const pad = (value: number, length = 2) => String(value).padStart(length, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}.${pad(date.getMilliseconds(), 3)}`;
}

export function toInstant(local: string, original?: string): string {
  // A repeated wall time at the DST fallback has two possible instants.
  // Preserve the API instant when that field has not changed.
  if (original && toLocalDateTime(original) === local) return new Date(original).toISOString();
  return new Date(local).toISOString();
}

const nonBlank = (control: AbstractControl): ValidationErrors | null =>
  typeof control.value === 'string' && !control.value.trim() ? { required: true } : null;
const validDate = (control: AbstractControl): ValidationErrors | null =>
  control.value && !Number.isFinite(new Date(control.value).getTime()) ? { date: true } : null;

export interface EventDraft {
  title: string;
  sport: string;
  location: string;
  startsAt: string;
  endsAt: string;
  capacity: number | null;
  description: string;
}

@Component({
  selector: 'app-event-form',
  standalone: true,
  imports: [ReactiveFormsModule],
  templateUrl: './event-form.html',
})
export class EventForm {
  readonly initial = input<EventResponse>();
  readonly draft = input<EventDraft>();
  readonly busy = input(false);
  readonly serverErrors = input<Record<string, string>>({});
  readonly validEventRequest = output<EventRequest>();
  readonly draftChange = output<EventDraft>();
  readonly discard = output<void>();
  readonly submitted = signal(false);

  readonly form = new FormGroup(
    {
      title: new FormControl('', {
        nonNullable: true,
        validators: [nonBlank, Validators.maxLength(150)],
      }),
      sport: new FormControl('', {
        nonNullable: true,
        validators: [nonBlank, Validators.maxLength(50)],
      }),
      location: new FormControl('', {
        nonNullable: true,
        validators: [nonBlank, Validators.maxLength(200)],
      }),
      startsAt: new FormControl('', {
        nonNullable: true,
        validators: [Validators.required, validDate],
      }),
      endsAt: new FormControl('', {
        nonNullable: true,
        validators: [Validators.required, validDate],
      }),
      capacity: new FormControl<number | null>(null, [
        Validators.required,
        Validators.min(1),
        (control) =>
          control.value !== null && !Number.isInteger(control.value) ? { integer: true } : null,
      ]),
      description: new FormControl('', {
        nonNullable: true,
        validators: [Validators.maxLength(2000)],
      }),
    },
    {
      validators: (control) => {
        const timestamp = (name: 'startsAt' | 'endsAt') => {
          const value = control.get(name)?.value;
          return value && Number.isFinite(new Date(value).getTime())
            ? Date.parse(toInstant(value, this.initial()?.[name]))
            : NaN;
        };
        const start = timestamp('startsAt');
        const end = timestamp('endsAt');
        const errors: ValidationErrors = {};
        if (!this.initial() && Number.isFinite(start) && start <= Date.now())
          errors['future'] = true;
        if (Number.isFinite(start) && Number.isFinite(end) && end <= start) errors['order'] = true;
        return Object.keys(errors).length ? errors : null;
      },
    },
  );

  constructor() {
    effect(() => {
      const initial = this.initial();
      const draft = this.draft();
      this.form.reset(
        draft ??
          (initial
            ? {
                title: initial.title,
                sport: initial.sport,
                location: initial.location,
                startsAt: toLocalDateTime(initial.startsAt),
                endsAt: toLocalDateTime(initial.endsAt),
                capacity: initial.capacity,
                description: initial.description ?? '',
              }
            : {
                title: '',
                sport: '',
                location: '',
                startsAt: '',
                endsAt: '',
                capacity: null,
                description: '',
              }),
        { emitEvent: false },
      );
      if (draft) this.form.markAsDirty();
    });
    this.form.valueChanges.pipe(takeUntilDestroyed(inject(DestroyRef))).subscribe(() => {
      this.draftChange.emit(this.form.getRawValue());
    });
  }

  error(name: keyof EventDraft): string {
    const control = this.form.controls[name];
    if (this.serverErrors()[name]) return this.serverErrors()[name];
    if (!control.touched) return '';
    if (control.hasError('required')) return 'This field is required.';
    if (control.hasError('maxlength'))
      return `Use at most ${control.getError('maxlength').requiredLength} characters.`;
    if (control.hasError('min') || control.hasError('integer'))
      return 'Enter a whole number of at least 1.';
    if (control.hasError('date')) return 'Enter a valid date and time.';
    if (name === 'startsAt' && this.form.hasError('future'))
      return 'New events must start in the future.';
    if (name === 'endsAt' && this.form.hasError('order'))
      return 'End time must be after start time.';
    return '';
  }

  submit(): void {
    if (this.busy()) return;
    this.submitted.set(true);
    this.form.markAllAsTouched();
    this.form.updateValueAndValidity({ emitEvent: false });
    if (this.form.invalid) return;
    const value = this.form.getRawValue();
    this.validEventRequest.emit({
      title: value.title.trim(),
      sport: value.sport.trim(),
      location: value.location.trim(),
      startsAt: toInstant(value.startsAt, this.initial()?.startsAt),
      endsAt: toInstant(value.endsAt, this.initial()?.endsAt),
      capacity: value.capacity!,
      description: value.description.trim(),
    });
  }
}
