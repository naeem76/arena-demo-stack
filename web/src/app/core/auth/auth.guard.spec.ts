import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';
import { describe, expect, it, vi } from 'vitest';
import { adminGuard } from './auth.guard';
import { AuthService } from './auth.service';

@Component({ template: '<h1>Protected administration</h1>' })
class AdminPage {}

@Component({ template: '<h1>Sign in</h1>' })
class SignInPage {}

@Component({ template: '<h1>Forbidden</h1>' })
class ForbiddenPage {}

describe('adminGuard', () => {
  it('routes anonymous visitors to sign-in, denies USER access, and admits ADMIN after authentication', async () => {
    const authenticated = signal(false);
    const isAdmin = signal(false);
    const login = vi.fn();
    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: { authenticated, isAdmin, login } },
        provideRouter([
          { path: 'admin', component: AdminPage, canActivate: [adminGuard] },
          { path: 'sign-in', component: SignInPage },
          { path: 'forbidden', component: ForbiddenPage },
        ]),
      ],
    });
    const harness = await RouterTestingHarness.create();
    const router = TestBed.inject(Router);
    await harness.navigateByUrl('/admin?eventId=42', SignInPage);
    const redirect = router.parseUrl(router.url);
    expect(redirect.root.children['primary'].segments.map((segment) => segment.path)).toEqual([
      'sign-in',
    ]);
    expect(redirect.queryParams['returnUrl']).toBe('/admin?eventId=42');
    expect(harness.routeNativeElement?.textContent).toContain('Sign in');

    authenticated.set(true);
    await harness.navigateByUrl('/admin', ForbiddenPage);
    expect(router.url).toBe('/forbidden');
    expect(harness.routeNativeElement?.textContent).toContain('Forbidden');

    isAdmin.set(true);
    await harness.navigateByUrl('/admin', AdminPage);
    expect(router.url).toBe('/admin');
    expect(harness.routeNativeElement?.textContent).toContain('Protected administration');
    expect(login).not.toHaveBeenCalled();
  });
});
