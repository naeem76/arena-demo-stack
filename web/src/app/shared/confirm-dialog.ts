import { Component, ElementRef, OnDestroy, signal, viewChild } from '@angular/core';

export interface Confirmation {
  title: string;
  message: string;
  confirmLabel?: string;
}

@Component({
  selector: 'app-confirm-dialog',
  template: `
    <dialog
      #dialog
      class="modal"
      [attr.aria-labelledby]="titleId"
      (cancel)="finish(false)"
      (close)="finish(false)"
    >
      <div class="modal-box">
        <p class="eyebrow">Please confirm</p>
        <h2 [id]="titleId" class="dialog-title">{{ options()?.title }}</h2>
        <p class="dialog-copy">{{ options()?.message }}</p>
        <div class="modal-action">
          <button type="button" class="btn btn-ghost" autofocus (click)="finish(false)">
            Keep it
          </button>
          <button type="button" class="btn btn-error" (click)="finish(true)">
            {{ options()?.confirmLabel || 'Confirm' }}
          </button>
        </div>
      </div>
    </dialog>
  `,
})
export class ConfirmDialog implements OnDestroy {
  private readonly dialog = viewChild.required<ElementRef<HTMLDialogElement>>('dialog');
  private resolve: ((value: boolean) => void) | undefined;
  readonly options = signal<Confirmation | null>(null);
  readonly titleId = `confirm-${crypto.randomUUID()}`;

  ask(options: Confirmation): Promise<boolean> {
    if (this.resolve) return Promise.resolve(false);
    this.options.set(options);
    return new Promise<boolean>((resolve) => {
      this.resolve = resolve;
      this.dialog().nativeElement.showModal();
    });
  }

  finish(value: boolean): void {
    const resolve = this.resolve;
    this.resolve = undefined;
    if (this.dialog().nativeElement.open) this.dialog().nativeElement.close();
    resolve?.(value);
  }

  ngOnDestroy(): void {
    this.resolve?.(false);
  }
}
