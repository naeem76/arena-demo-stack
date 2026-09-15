import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

export const adminGuard: CanActivateFn = (_route, state) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  if (!auth.authenticated())
    return router.createUrlTree(['/sign-in'], { queryParams: { returnUrl: state.url } });
  return auth.isAdmin() || router.createUrlTree(['/forbidden']);
};
