import { Component, input } from '@angular/core';

@Component({
  selector: 'app-status-badge',
  template: `<span class="status-badge" [attr.data-status]="status()"
    ><span aria-hidden="true" class="status-dot"></span>{{ label() }}</span
  >`,
})
export class StatusBadge {
  readonly status = input.required<string>();
  label(): string {
    return this.status().slice(0, 1) + this.status().slice(1).toLowerCase();
  }
}
