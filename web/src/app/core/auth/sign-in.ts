import { Component, inject } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Brand } from '../../shared/brand';
import { AuthService, safeReturnUrl } from './auth.service';

@Component({
  selector: 'app-sign-in',
  imports: [Brand, RouterLink],
  template: `
    <main class="entry-page">
      <section class="entry-story">
        <app-brand />
        <div class="entry-copy">
          <h1>Events<br />and bookings</h1>
        </div>
      </section>
      <section class="entry-action">
        <div class="entry-card">
          <p class="eyebrow">Arena administration</p>
          <h2>
            {{
              mode === 'forbidden'
                ? 'Admin access needed'
                : mode === 'signed-out'
                  ? 'Signed out'
                  : 'Sign in'
            }}
          </h2>
          <p class="muted">
            {{
              mode === 'forbidden'
                ? 'Sign in with an administrator account.'
                : mode === 'signed-out'
                  ? 'Your session has ended.'
                  : 'Use your administrator account.'
            }}
          </p>
          @if (auth.error()) {
            <div class="alert alert-error" role="alert">{{ auth.error() }}</div>
          }
          @if (auth.expired()) {
            <div class="alert" role="status">
              Your session has expired. Your saved form draft will be restored after sign-in.
            </div>
          }
          @if (auth.authenticated() && !auth.isAdmin()) {
            <button type="button" class="btn btn-primary entry-button" (click)="auth.logout()">
              Sign out to switch account <span aria-hidden="true">↗</span>
            </button>
          } @else if (auth.authenticated()) {
            <a class="btn btn-primary entry-button" routerLink="/events"
              >Open workspace <span aria-hidden="true">↗</span></a
            >
          } @else {
            <button
              type="button"
              class="btn btn-primary entry-button"
              [disabled]="auth.busy()"
              (click)="signIn()"
            >
              {{ auth.busy() ? 'Connecting…' : 'Continue to sign in' }}
              <span aria-hidden="true">↗</span>
            </button>
          }
          <p class="entry-help">Sign-in opens in this tab and returns you here.</p>
        </div>
      </section>
    </main>
  `,
})
export class SignIn {
  readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  readonly mode = this.route.snapshot.data['mode'] as string | undefined;
  signIn(): void {
    void this.auth.login(safeReturnUrl(this.route.snapshot.queryParamMap.get('returnUrl')));
  }
}

@Component({
  selector: 'app-auth-callback',
  imports: [RouterLink],
  template: `<main class="callback-page">
    <p class="eyebrow">Arena operations</p>
    <h1>{{ auth.error() ? 'Sign-in failed' : 'Signing in…' }}</h1>
    @if (auth.error()) {
      <p role="alert">{{ auth.error() }}</p>
      <a class="btn btn-primary" routerLink="/sign-in">Return to sign in</a>
    } @else {
      <span class="loading loading-spinner loading-lg" aria-label="Loading"></span>
    }
  </main>`,
})
export class AuthCallback {
  readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  constructor() {
    if (!this.auth.error()) {
      const target = this.auth.authenticated()
        ? this.auth.isAdmin()
          ? this.auth.consumeReturnUrl()
          : '/forbidden'
        : '/sign-in';
      void this.router.navigateByUrl(target, { replaceUrl: true });
    }
  }
}
