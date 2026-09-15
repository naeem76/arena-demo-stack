import { Component } from '@angular/core';

@Component({
  selector: 'app-brand',
  template: `<span class="brand"
    ><svg class="brand-mark" viewBox="0 0 36 36" fill="none" aria-hidden="true">
      <path d="M12 3H24L33 12V24L24 33H12L3 24V12L12 3Z" stroke="currentColor" stroke-width="5" />
      <path d="M12 12H24V24H12Z" fill="currentColor" /></svg
    ><span><strong>ARENA</strong><small>OPERATIONS</small></span></span
  >`,
})
export class Brand {}
