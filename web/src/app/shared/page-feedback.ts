import { Component, input, output } from '@angular/core';

@Component({
  selector: 'app-page-feedback',
  template: `
    <section
      class="page-feedback"
      [attr.role]="kind() === 'error' ? 'alert' : 'status'"
      aria-live="polite"
    >
      @if (kind() === 'loading') {
        <span class="loading loading-spinner loading-lg text-primary" aria-hidden="true"></span>
      } @else {
        <span class="feedback-symbol" aria-hidden="true">{{ kind() === 'empty' ? '↗' : '!' }}</span>
      }
      <h2>{{ title() }}</h2>
      <p>{{ message() }}</p>
      @if (kind() === 'error') {
        <button type="button" class="btn btn-outline btn-sm" (click)="retry.emit()">
          Try again
        </button>
      }
      <ng-content />
    </section>
  `,
})
export class PageFeedback {
  readonly kind = input.required<'loading' | 'error' | 'empty'>();
  readonly title = input.required<string>();
  readonly message = input('');
  readonly retry = output<void>();
}
