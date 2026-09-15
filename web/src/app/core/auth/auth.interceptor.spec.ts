import {
  HttpClient,
  HttpErrorResponse,
  provideHttpClient,
  withInterceptors,
} from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { firstValueFrom } from 'rxjs';
import { APP_SETTINGS } from '../app-settings';
import { authInterceptor, isApiRequest } from './auth.interceptor';
import { AuthService } from './auth.service';
import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest';

describe('authInterceptor', () => {
  const base = 'https://api.arena.test/backend';
  let http: HttpClient;
  let backend: HttpTestingController;
  let auth: {
    accessToken: ReturnType<typeof vi.fn>;
    markExpired: ReturnType<typeof vi.fn>;
    login: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    auth = { accessToken: vi.fn(() => 'access-token'), markExpired: vi.fn(), login: vi.fn() };
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
        {
          provide: APP_SETTINGS,
          useValue: { apiBaseUrl: base, issuerUrl: 'https://identity.arena.test' },
        },
        { provide: AuthService, useValue: auth },
      ],
    });
    http = TestBed.inject(HttpClient);
    backend = TestBed.inject(HttpTestingController);
  });

  afterEach(() => backend.verify());

  it('attaches the bearer only to the configured API origin and path boundary', async () => {
    const cases: [string, boolean][] = [
      [`${base}/api`, true],
      [`${base}/api/events?page=2`, true],
      ['//api.arena.test/backend/api/bookings', location.protocol === 'https:'],
      ['https://api.arena.test.evil.test/backend/api/events', false],
      ['https://api.arena.test@evil.test/backend/api/events', false],
      ['https://api.arena.test:444/backend/api/events', false],
      ['http://api.arena.test/backend/api/events', false],
      [`${base}/apiary/events`, false],
      [`${base}/api-v2/events`, false],
      [`${base}/other?next=/api/events`, false],
      ['https://external.test/backend/api/events', false],
      ['/assets/settings.json', false],
    ];
    for (const [url, protectedRequest] of cases) {
      const response = firstValueFrom(
        http.get(url, { headers: { 'X-Correlation-ID': 'request-42' } }),
      );
      const request = backend.expectOne(url);
      expect(request.request.headers.get('Authorization'), url).toBe(
        protectedRequest ? 'Bearer access-token' : null,
      );
      expect(request.request.headers.get('X-Correlation-ID')).toBe('request-42');
      request.flush({ ok: true });
      await expect(response).resolves.toEqual({ ok: true });
    }
    expect(auth.accessToken).toHaveBeenCalledTimes(location.protocol === 'https:' ? 3 : 2);
    expect(auth.markExpired).not.toHaveBeenCalled();
  });

  it('resolves protocol-relative URLs using the page scheme without downgrading bearer transport', () => {
    expect(
      isApiRequest('//api.arena.test/backend/api/events', base, 'https://workspace.arena.test'),
    ).toBe(true);
    expect(
      isApiRequest('//api.arena.test/backend/api/events', base, 'http://workspace.arena.test'),
    ).toBe(false);
  });

  it('fails locally with 401 when no token exists while public requests still reach the backend', async () => {
    auth.accessToken.mockReturnValue('');
    const url = `${base}/api/bookings`;
    await expect(firstValueFrom(http.post(url, { eventId: 7 }))).rejects.toMatchObject({
      status: 401,
    });
    backend.expectNone(url);
    expect(auth.markExpired).toHaveBeenCalledOnce();
    expect(auth.login).not.toHaveBeenCalled();
    const publicResponse = firstValueFrom(http.get('/assets/settings.json'));
    backend.expectOne('/assets/settings.json').flush({ title: 'Arena' });
    await expect(publicResponse).resolves.toEqual({ title: 'Arena' });
  });

  it.each([401, 403])(
    'propagates backend %s without replaying a mutation or starting login',
    async (status) => {
      const url = `${base}/api/bookings`;
      const response = firstValueFrom(http.post(url, { eventId: 7 })).catch(
        (error: HttpErrorResponse) => error,
      );
      const request = backend.expectOne(url);
      request.flush({ detail: 'Rejected' }, { status, statusText: 'Rejected' });
      const error = await response;
      expect(error).toBeInstanceOf(HttpErrorResponse);
      expect(error).toMatchObject({ status, error: { detail: 'Rejected' } });
      expect(auth.markExpired).toHaveBeenCalledTimes(status === 401 ? 1 : 0);
      expect(auth.login).not.toHaveBeenCalled();
      backend.expectNone(url);
    },
  );
});
