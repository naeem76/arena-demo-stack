import { InjectionToken } from '@angular/core';

export interface AppSettings {
  apiBaseUrl: string;
  issuerUrl: string;
}

export const APP_SETTINGS = new InjectionToken<AppSettings>('Application settings');
