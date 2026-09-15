import {
  ApplicationConfig,
  inject,
  provideAppInitializer,
  provideBrowserGlobalErrorListeners,
} from '@angular/core';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideRouter, withInMemoryScrolling } from '@angular/router';
import { OAuthStorage, provideOAuthClient } from 'angular-oauth2-oidc';
import { routes } from './app.routes';
import { provideApiConfiguration } from './api/api-configuration';
import { APP_SETTINGS, AppSettings } from './core/app-settings';
import { AuthService } from './core/auth/auth.service';
import { authInterceptor } from './core/auth/auth.interceptor';

export function applicationConfig(settings: AppSettings): ApplicationConfig {
  return {
    providers: [
      provideBrowserGlobalErrorListeners(),
      provideRouter(routes, withInMemoryScrolling({ scrollPositionRestoration: 'enabled' })),
      provideHttpClient(withInterceptors([authInterceptor])),
      provideOAuthClient(),
      { provide: OAuthStorage, useFactory: () => sessionStorage },
      { provide: APP_SETTINGS, useValue: settings },
      provideApiConfiguration(settings.apiBaseUrl),
      provideAppInitializer(() => inject(AuthService).initialize()),
    ],
  };
}
