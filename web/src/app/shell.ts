import { Component, HostListener, inject, signal } from '@angular/core';
import { Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { AuthService } from './core/auth/auth.service';
import { Brand } from './shared/brand';

@Component({
  selector: 'app-shell',
  imports: [RouterLink, RouterLinkActive, RouterOutlet, Brand],
  template: `
    <a class="skip-link" href="#main-content">Skip to content</a>
    <div class="workspace">
      <aside id="workspace-navigation" class="sidebar" [class.is-open]="navOpen()">
        <a
          routerLink="/events"
          aria-label="Arena operations home"
          class="sidebar-brand"
          (click)="navOpen.set(false)"
          ><app-brand
        /></a>
        <p class="nav-caption">WORKSPACE</p>
        <nav aria-label="Main navigation">
          <a
            routerLink="/events"
            routerLinkActive="active"
            ariaCurrentWhenActive="page"
            (click)="navOpen.set(false)"
            ><svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.6"
              aria-hidden="true"
            >
              <rect x="3" y="5" width="18" height="16" rx="3" />
              <path d="M7 3v4m10-4v4M3 11h18m-14 4h3m4 0h3" /></svg
            >Events<span class="nav-arrow" aria-hidden="true">↗</span></a
          >
          <a
            routerLink="/bookings"
            routerLinkActive="active"
            ariaCurrentWhenActive="page"
            (click)="navOpen.set(false)"
            ><svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="1.6"
              aria-hidden="true"
            >
              <path
                d="M3 7a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v3a2 2 0 0 0 0 4v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-3a2 2 0 0 0 0-4V7Z"
              />
              <path d="M15 6v3m0 2v2m0 2v3" /></svg
            >Bookings<span class="nav-arrow" aria-hidden="true">↗</span></a
          >
        </nav>
      </aside>
      <div class="workspace-body">
        <header class="workspace-header">
          <button
            type="button"
            class="btn btn-ghost mobile-menu"
            aria-controls="workspace-navigation"
            [attr.aria-expanded]="navOpen()"
            (click)="navOpen.set(!navOpen())"
          >
            {{ navOpen() ? 'Close menu' : 'Menu' }} <span aria-hidden="true">☰</span>
          </button>
          <span class="workspace-location"
            >Operations <span aria-hidden="true">/</span> <strong>Admin workspace</strong></span
          >
          <div class="account">
            <span class="avatar-initial" aria-hidden="true">{{
              auth.displayName().slice(0, 1)
            }}</span
            ><span class="account-name">{{ auth.displayName() }}<small>Administrator</small></span
            ><button type="button" class="btn btn-ghost btn-sm" (click)="auth.logout()">
              Sign out
            </button>
          </div>
        </header>
        <main id="main-content" class="main-content" tabindex="-1">
          @if (auth.expired()) {
            <div class="alert session-alert" role="alert">
              <span
                ><strong>Your session has expired.</strong> Sign in again to continue. Your form
                draft is kept.</span
              ><button
                type="button"
                class="btn btn-sm btn-primary"
                [disabled]="auth.busy()"
                (click)="auth.login(router.url)"
              >
                Sign in again
              </button>
            </div>
          }
          @if (auth.error()) {
            <div class="alert alert-error" role="alert">{{ auth.error() }}</div>
          }
          <router-outlet />
        </main>
      </div>
    </div>
  `,
})
export class Shell {
  readonly auth = inject(AuthService);
  readonly router = inject(Router);
  readonly navOpen = signal(false);
  @HostListener('document:keydown.escape') closeNavigation(): void {
    this.navOpen.set(false);
  }
}
