import { bootstrapApplication } from '@angular/platform-browser';
import { applicationConfig } from './app/app.config';
import { App } from './app/app';
import { AppSettings } from './app/core/app-settings';

async function start(): Promise<void> {
  const response = await fetch('/config.json', { cache: 'no-store' });
  if (!response.ok) throw new Error('Runtime configuration is unavailable.');
  const settings = (await response.json()) as AppSettings;
  for (const value of [settings.apiBaseUrl, settings.issuerUrl]) {
    if (typeof value !== 'string' || !/^https?:\/\//.test(value))
      throw new Error('Invalid runtime configuration.');
  }
  await bootstrapApplication(App, applicationConfig(settings));
}

start().catch(() => {
  const root = document.querySelector('app-root');
  if (root)
    root.textContent =
      'Arena could not start. Check the web runtime configuration and reload the page.';
});
