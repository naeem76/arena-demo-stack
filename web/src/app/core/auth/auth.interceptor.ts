import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, throwError } from 'rxjs';
import { APP_SETTINGS } from '../app-settings';
import { AuthService } from './auth.service';

export function isApiRequest(url: string, baseUrl: string, origin: string): boolean {
  const target = new URL(url, origin);
  const api = new URL(baseUrl, origin);
  const prefix = `${api.pathname.replace(/\/$/, '')}/api`;
  return (
    target.origin === api.origin &&
    (target.pathname === prefix || target.pathname.startsWith(`${prefix}/`))
  );
}

export const authInterceptor: HttpInterceptorFn = (request, next) => {
  if (!isApiRequest(request.url, inject(APP_SETTINGS).apiBaseUrl, location.origin))
    return next(request);
  const auth = inject(AuthService);
  const token = auth.accessToken();
  if (!token) {
    auth.markExpired();
    return throwError(() => new HttpErrorResponse({ status: 401, statusText: 'Sign in required' }));
  }
  return next(request.clone({ setHeaders: { Authorization: `Bearer ${token}` } })).pipe(
    catchError((error: unknown) => {
      if (error instanceof HttpErrorResponse && error.status === 401) auth.markExpired();
      return throwError(() => error);
    }),
  );
};
