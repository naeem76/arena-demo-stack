import { computed, inject, Injectable, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { OAuthService } from 'angular-oauth2-oidc';
import { APP_SETTINGS } from '../app-settings';

const RETURN_URL = 'arena:return-url';

export function safeReturnUrl(value: string | null | undefined): string {
  if (!value?.startsWith('/') || value.startsWith('//')) return '/events';
  const target = new URL(value, location.origin);
  if (target.origin !== location.origin || !/^\/(events|bookings)(?:\/|$)/.test(target.pathname))
    return '/events';
  return `${target.pathname}${target.search}${target.hash}`;
}

export function tokenRoles(token: string): string[] {
  try {
    const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
    return Array.isArray(payload.roles)
      ? payload.roles.filter((role: unknown) => typeof role === 'string')
      : [];
  } catch {
    return [];
  }
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly oauth = inject(OAuthService);
  private readonly settings = inject(APP_SETTINGS);
  private readonly session = signal({
    authenticated: false,
    expired: false,
    userId: '',
    name: '',
    roles: [] as string[],
  });
  readonly authenticated = computed(() => this.session().authenticated);
  readonly expired = computed(() => this.session().expired);
  readonly userId = computed(() => this.session().userId);
  readonly displayName = computed(() => this.session().name);
  readonly isAdmin = computed(() => this.session().roles.includes('ADMIN'));
  readonly error = signal('');
  readonly busy = signal(false);

  constructor() {
    this.oauth.configure({
      issuer: this.settings.issuerUrl,
      clientId: 'arena-web',
      redirectUri: `${location.origin}/auth/callback`,
      postLogoutRedirectUri: `${location.origin}/signed-out`,
      responseType: 'code',
      scope: 'openid profile api.access',
      timeoutFactor: 1,
      showDebugInformation: false,
    });
    this.oauth.events.pipe(takeUntilDestroyed()).subscribe((event) => {
      if (event.type === 'token_received') this.synchronize();
      if (event.type === 'token_expires' && !this.oauth.hasValidAccessToken()) this.markExpired();
      if (event.type === 'logout')
        this.session.set({ authenticated: false, expired: false, userId: '', name: '', roles: [] });
    });
  }

  async initialize(): Promise<void> {
    try {
      await this.oauth.loadDiscoveryDocumentAndTryLogin();
      this.synchronize();
    } catch {
      this.error.set(
        'Sign-in could not be initialized. Check that the backend is running, then try again.',
      );
    }
  }

  async login(returnUrl?: string): Promise<void> {
    this.busy.set(true);
    this.error.set('');
    try {
      if (!this.oauth.discoveryDocumentLoaded) await this.oauth.loadDiscoveryDocument();
      sessionStorage.setItem(RETURN_URL, safeReturnUrl(returnUrl));
      this.oauth.initCodeFlow();
    } catch {
      this.error.set('We could not connect to the sign-in service. Please try again.');
    } finally {
      this.busy.set(false);
    }
  }

  consumeReturnUrl(): string {
    const result = safeReturnUrl(sessionStorage.getItem(RETURN_URL));
    sessionStorage.removeItem(RETURN_URL);
    return result;
  }

  accessToken(): string {
    return this.oauth.hasValidAccessToken() ? this.oauth.getAccessToken() : '';
  }

  markExpired(): void {
    this.session.update((value) => ({ ...value, authenticated: false, expired: true }));
  }

  logout(): void {
    sessionStorage.removeItem(RETURN_URL);
    this.oauth.logOut();
  }

  private synchronize(): void {
    const identity = this.oauth.getIdentityClaims() as Record<string, unknown> | null;
    const authenticated = this.oauth.hasValidAccessToken() && this.oauth.hasValidIdToken();
    this.session.set({
      authenticated,
      expired: !authenticated && !!this.oauth.getAccessToken(),
      userId: typeof identity?.['sub'] === 'string' ? identity['sub'] : '',
      name: typeof identity?.['name'] === 'string' ? identity['name'] : 'Administrator',
      roles: tokenRoles(this.oauth.getAccessToken()),
    });
  }
}
