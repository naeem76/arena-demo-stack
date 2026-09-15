import { Component, input, output } from '@angular/core';
import { ParamMap } from '@angular/router';
import { EventPageResponse } from '../api/models/event-page-response';

export type PageInfo = Pick<EventPageResponse, 'page' | 'size' | 'totalElements' | 'totalPages'>;

export function readPagination(params: ParamMap, pageKey = 'page') {
  const page = Number(params.get(pageKey) ?? 0);
  const size = Number(params.get('size') ?? 20);
  return {
    page: Number.isInteger(page) && page >= 0 && page <= 2_147_483_647 ? page : 0,
    size: Number.isSafeInteger(size) && size > 0 ? Math.min(size, 100) : 20,
  };
}

export function recoveryPage(page: number, totalPages: number): number | null {
  const last = Math.max(0, totalPages - 1);
  return page > last ? last : null;
}

@Component({
  selector: 'app-pagination',
  template: `
    <nav class="toolbar" [attr.aria-label]="label()">
      <button
        type="button"
        class="btn btn-outline btn-sm"
        [disabled]="busy() || info().page === 0"
        (click)="pageChange.emit(info().page - 1)"
      >
        Previous
      </button>
      <span role="status"
        >Page {{ info().totalPages ? info().page + 1 : 0 }} of {{ info().totalPages }} ·
        {{ info().totalElements }} total</span
      >
      <button
        type="button"
        class="btn btn-outline btn-sm"
        [disabled]="busy() || info().page + 1 >= info().totalPages"
        (click)="pageChange.emit(info().page + 1)"
      >
        Next
      </button>
    </nav>
  `,
})
export class Pagination {
  readonly info = input.required<PageInfo>();
  readonly label = input.required<string>();
  readonly busy = input(false);
  readonly pageChange = output<number>();
}
