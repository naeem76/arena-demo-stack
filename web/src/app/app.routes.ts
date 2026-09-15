import { Routes } from '@angular/router';
import { adminGuard } from './core/auth/auth.guard';
import { pendingChangesGuard } from './shared/pending-changes.guard';

export const routes: Routes = [
  {
    path: 'sign-in',
    loadComponent: () => import('./core/auth/sign-in').then((m) => m.SignIn),
    title: 'Sign in · Arena',
  },
  {
    path: 'signed-out',
    loadComponent: () => import('./core/auth/sign-in').then((m) => m.SignIn),
    data: { mode: 'signed-out' },
    title: 'Signed out · Arena',
  },
  {
    path: 'forbidden',
    loadComponent: () => import('./core/auth/sign-in').then((m) => m.SignIn),
    data: { mode: 'forbidden' },
    title: 'Admin access · Arena',
  },
  {
    path: 'auth/callback',
    loadComponent: () => import('./core/auth/sign-in').then((m) => m.AuthCallback),
    title: 'Signing in · Arena',
  },
  {
    path: '',
    loadComponent: () => import('./shell').then((m) => m.Shell),
    canActivate: [adminGuard],
    canActivateChild: [adminGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'events' },
      {
        path: 'events',
        loadComponent: () => import('./features/events/events-list').then((m) => m.EventsList),
        title: 'Events · Arena',
      },
      {
        path: 'events/new',
        loadComponent: () => import('./features/events/event-editor').then((m) => m.EventEditor),
        canDeactivate: [pendingChangesGuard],
        title: 'Create event · Arena',
      },
      {
        path: 'events/:id/edit',
        loadComponent: () => import('./features/events/event-editor').then((m) => m.EventEditor),
        canDeactivate: [pendingChangesGuard],
        title: 'Edit event · Arena',
      },
      {
        path: 'events/:id',
        loadComponent: () => import('./features/events/events-details').then((m) => m.EventDetails),
        title: 'Event details · Arena',
      },
      {
        path: 'bookings',
        loadComponent: () =>
          import('./features/bookings/bookings-list').then((m) => m.BookingsList),
        title: 'Bookings · Arena',
      },
      {
        path: 'bookings/:id',
        loadComponent: () =>
          import('./features/bookings/booking-details').then((m) => m.BookingDetails),
        title: 'Booking details · Arena',
      },
    ],
  },
  { path: '**', redirectTo: 'events' },
];
