import { TestBed } from '@angular/core/testing';
import { OAuthEvent, OAuthService } from 'angular-oauth2-oidc';
import { Subject } from 'rxjs';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { APP_SETTINGS } from '../app-settings';
import { AuthService, safeReturnUrl, tokenRoles } from './auth.service';

function token(payload: unknown): string {
  return `header.${btoa(JSON.stringify(payload)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')}.signature`;
}

describe('AuthService', () => {
  let events: Subject<OAuthEvent>;
  let oauth: ReturnType<typeof createOAuthMock>;
  let auth: AuthService;

  function createOAuthMock() {
    return {
      events,
      configure: vi.fn(),
      discoveryDocumentLoaded: true,
      loadDiscoveryDocumentAndTryLogin: vi.fn().mockResolvedValue(true),
      loadDiscoveryDocument: vi.fn().mockResolvedValue({}),
      hasValidAccessToken: vi.fn(() => true),
      hasValidIdToken: vi.fn(() => true),
      getAccessToken: vi.fn(() => token({ roles: ['USER', 'ADMIN'] })),
      getIdentityClaims: vi.fn((): Record<string, unknown> | null => ({
        sub: 'admin-42',
        name: 'Arena Admin',
      })),
      initCodeFlow: vi.fn(),
      logOut: vi.fn(),
    };
  }

  beforeEach(() => {
    sessionStorage.removeItem('arena:return-url');
    events = new Subject<OAuthEvent>();
    oauth = createOAuthMock();
    TestBed.configureTestingModule({
      providers: [
        { provide: OAuthService, useValue: oauth },
        {
          provide: APP_SETTINGS,
          useValue: { apiBaseUrl: '/backend', issuerUrl: 'https://identity.arena.test' },
        },
      ],
    });
    auth = TestBed.inject(AuthService);
  });

  afterEach(() => {
    sessionStorage.removeItem('arena:return-url');
    events.complete();
  });

  it('configures code flow and restores persisted identity and access-token roles at initialization', async () => {
    expect(auth.authenticated()).toBe(false);
    await auth.initialize();
    expect(oauth.configure).toHaveBeenCalledWith(
      expect.objectContaining({
        issuer: 'https://identity.arena.test',
        clientId: 'arena-web',
        responseType: 'code',
        redirectUri: `${location.origin}/auth/callback`,
        scope: 'openid profile api.access',
      }),
    );
    expect(oauth.loadDiscoveryDocumentAndTryLogin).toHaveBeenCalledOnce();
    expect(auth.authenticated()).toBe(true);
    expect(auth.userId()).toBe('admin-42');
    expect(auth.displayName()).toBe('Arena Admin');
    expect(auth.isAdmin()).toBe(true);
    expect(auth.accessToken()).toBe(oauth.getAccessToken());
    expect(oauth.initCodeFlow).not.toHaveBeenCalled();

    oauth.getAccessToken.mockReturnValue(token({ roles: ['USER'] }));
    oauth.getIdentityClaims.mockReturnValue({ sub: 'user-7', name: 'Ticket Buyer' });
    events.next({ type: 'token_received' } as OAuthEvent);
    expect(auth.authenticated()).toBe(true);
    expect(auth.userId()).toBe('user-7');
    expect(auth.displayName()).toBe('Ticket Buyer');
    expect(auth.isAdmin()).toBe(false);
  });

  it('requires both valid tokens and handles absent or malformed identity claims', async () => {
    oauth.hasValidIdToken.mockReturnValue(false);
    oauth.getIdentityClaims.mockReturnValue({ sub: 42, name: false });
    await auth.initialize();
    expect(auth.authenticated()).toBe(false);
    expect(auth.expired()).toBe(true);
    expect(auth.userId()).toBe('');
    expect(auth.displayName()).toBe('Administrator');
    oauth.getIdentityClaims.mockReturnValue(null);
    oauth.getAccessToken.mockReturnValue('');
    oauth.hasValidAccessToken.mockReturnValue(false);
    events.next({ type: 'token_received' } as OAuthEvent);
    expect(auth.expired()).toBe(false);
    expect(auth.isAdmin()).toBe(false);
    expect(auth.accessToken()).toBe('');
  });

  it('exposes expiration for a sign-in prompt without automatic redirect and recovers on new tokens', async () => {
    await auth.initialize();
    events.next({ type: 'token_expires' } as OAuthEvent);
    expect(auth.authenticated()).toBe(true);
    oauth.hasValidAccessToken.mockReturnValue(false);
    events.next({ type: 'token_expires' } as OAuthEvent);
    expect(auth.authenticated()).toBe(false);
    expect(auth.expired()).toBe(true);
    expect(auth.accessToken()).toBe('');
    expect(oauth.initCodeFlow).not.toHaveBeenCalled();
    expect(oauth.loadDiscoveryDocument).not.toHaveBeenCalled();
    oauth.hasValidAccessToken.mockReturnValue(true);
    events.next({ type: 'token_received' } as OAuthEvent);
    expect(auth.authenticated()).toBe(true);
    expect(auth.expired()).toBe(false);
    auth.markExpired();
    expect(auth.authenticated()).toBe(false);
    expect(auth.expired()).toBe(true);
    expect(oauth.initCodeFlow).not.toHaveBeenCalled();
  });

  it('loads discovery before explicit login, stores the return route, and consumes it only once', async () => {
    oauth.discoveryDocumentLoaded = false;
    let finishDiscovery!: (value: unknown) => void;
    oauth.loadDiscoveryDocument.mockReturnValue(
      new Promise((resolve) => {
        finishDiscovery = resolve;
      }),
    );
    auth.error.set('previous failure');
    const login = auth.login('/bookings?eventId=42');
    expect(auth.busy()).toBe(true);
    expect(auth.error()).toBe('');
    expect(oauth.initCodeFlow).not.toHaveBeenCalled();
    finishDiscovery({});
    await login;
    expect(oauth.initCodeFlow).toHaveBeenCalledOnce();
    expect(auth.busy()).toBe(false);
    expect(sessionStorage.getItem('arena:return-url')).toBe('/bookings?eventId=42');
    expect(auth.consumeReturnUrl()).toBe('/bookings?eventId=42');
    expect(sessionStorage.getItem('arena:return-url')).toBeNull();
    expect(auth.consumeReturnUrl()).toBe('/events');
  });

  it('sanitizes login and persisted return routes and clears route storage on logout', async () => {
    await auth.initialize();
    await auth.login('https://evil.test/events');
    expect(oauth.loadDiscoveryDocument).not.toHaveBeenCalled();
    expect(oauth.initCodeFlow).toHaveBeenCalledOnce();
    expect(sessionStorage.getItem('arena:return-url')).toBe('/events');
    sessionStorage.setItem('arena:return-url', '//evil.test/bookings');
    expect(auth.consumeReturnUrl()).toBe('/events');
    expect(sessionStorage.getItem('arena:return-url')).toBeNull();
    sessionStorage.setItem('arena:return-url', '/bookings');
    auth.logout();
    expect(oauth.logOut).toHaveBeenCalledOnce();
    expect(sessionStorage.getItem('arena:return-url')).toBeNull();
    events.next({ type: 'logout' } as OAuthEvent);
    expect(auth.authenticated()).toBe(false);
    expect(auth.expired()).toBe(false);
    expect(auth.userId()).toBe('');
    expect(auth.displayName()).toBe('');
    expect(auth.isAdmin()).toBe(false);
  });

  it('exposes initialization and login failures without redirecting or remaining busy', async () => {
    oauth.loadDiscoveryDocumentAndTryLogin.mockRejectedValue(new Error('private issuer details'));
    await auth.initialize();
    expect(auth.error()).toBe(
      'Sign-in could not be initialized. Check that the backend is running, then try again.',
    );
    expect(auth.authenticated()).toBe(false);
    oauth.discoveryDocumentLoaded = false;
    oauth.loadDiscoveryDocument.mockRejectedValue(new Error('private issuer details'));
    await auth.login('/bookings');
    expect(auth.error()).toBe('We could not connect to the sign-in service. Please try again.');
    expect(auth.busy()).toBe(false);
    expect(sessionStorage.getItem('arena:return-url')).toBeNull();
    expect(oauth.initCodeFlow).not.toHaveBeenCalled();
  });
});

describe('authentication input parsing', () => {
  it('decodes role arrays while rejecting malformed tokens and non-string roles', () => {
    expect(tokenRoles(token({ roles: ['USER', null, 1, 'ADMIN', { role: 'ADMIN' }] }))).toEqual([
      'USER',
      'ADMIN',
    ]);
    for (const value of [
      '',
      'broken',
      'header.%%%.signature',
      token({ roles: 'ADMIN' }),
      token({}),
      token(null),
    ]) {
      expect(tokenRoles(value), value).toEqual([]);
    }
  });

  it('preserves allowed internal routes and rejects external or unrelated destinations', () => {
    for (const route of ['/events', '/events/42?tab=bookings', '/bookings?eventId=7']) {
      expect(safeReturnUrl(route)).toBe(route);
    }
    for (const route of [
      null,
      undefined,
      '',
      'https://evil.test/events',
      '//evil.test/events',
      '/\\evil.test/events',
      'javascript:alert(1)',
      '/events-admin',
      '/admin',
      'events',
      '/events/../sign-in',
      '/events/%2e%2e/sign-in',
    ]) {
      expect(safeReturnUrl(route)).toBe('/events');
    }
  });
});
