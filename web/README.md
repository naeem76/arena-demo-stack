# Arena web administration

Angular 22 standalone SPA with Node.js 24, Tailwind CSS and daisyUI. See the
[root README](../README.md) for single-command Docker startup and demo credentials.

## Workflows

- **Events:** list/filter by sport and status, inspect, create, edit, change
  lifecycle status, and delete with confirmation.
- **Bookings:** inspect all users' reservations, filter by event/status, view
  participant information and cancel eligible reservations with confirmation.
- Event details links to the same Bookings view with an event filter applied.
- Lists adapt from desktop tables to stacked rows on mobile; navigation collapses.
- Loading, empty, error, pending and success states are explicit. Failed mutations
  are not retried automatically. Cancellation retains historical booking rows.

This is an admin workspace. The backend independently enforces permissions;
normal user accounts are shown an access explanation and an account-switch action.
Personal booking creation remains available through the API for participant clients.

## Structure and state

```text
src/app/
  api/                 Generated models, operations and injectable API services
  core/auth/           OIDC integration, route guard and scoped token interceptor
  core/api-error.ts    Shared Problem Details translation
  features/events/     Event list, details, editor and shared create/edit form
  features/bookings/   Booking list and details
  shared/              Status, feedback, brand and confirmation components
  shell.ts             Responsive administration layout
```

Authentication is the only application-global state. Feature data, filters,
pending actions and errors are local to their owning pages. Signals represent
UI state and RxJS handles asynchronous requests, cancellation and cleanup. Filter
values live in query parameters so refresh/back/forward navigation preserves them.

Events and bookings use server-side filters and pagination (`page` is zero-based,
`size` defaults to 20 and is capped at 100). Previous/next controls show the current
page, page count and total matching records. Applying or clearing filters resets
the page. If deletion leaves a page beyond the end, the URL is replaced with the
last available page; an empty dataset settles on page zero.
List context is preserved through event details/edit/save/discard/delete and booking
details/back. Opening bookings from event details starts at booking page zero with
only that event filter, without carrying over event-list filters or pagination.

The booking event filter loads only 20 event options at a time. Its separate
`eventPage` URL parameter and previous/next controls make every event reachable
without downloading the whole directory. The selected event is retained separately
and fetched by ID when off-page, keeping its title visible while browsing options.
Bookings always request `scope=all`.

Create/edit share one typed Reactive Form component. The editor coordinates the
generated API calls and navigation. Form controls enforce the backend's field
limits and cross-field time rules, while the API remains authoritative. Local
date/time controls convert to ISO instants at JavaScript's millisecond precision.
Unchanged local values retain the original choice of instant during repeated
wall times at daylight-saving transitions.

Unsaved Event drafts are stored in session storage under a user-and-event-specific
key. They survive a full-page login redirect and are removed after successful save
or explicit discard. Storage failures are surfaced rather than claiming a draft
was saved. Navigation with unsaved changes asks for confirmation.

## Authentication

`angular-oauth2-oidc` discovers the backend's OIDC endpoints and uses authorization
code + PKCE with client `arena-web` and scopes `openid profile api.access`.
Sign-in redirects in the **same browser tab**; the SPA does not collect passwords.

- Callback: `${WEB_ORIGIN}/auth/callback`.
- Post-logout callback: `${WEB_ORIGIN}/signed-out`.
- Tokens use the library's session-storage integration.
- OIDC identity claims provide user ID/name; access-token roles drive UI access.
- The interceptor attaches access tokens only to the configured API origin and
  `/api` path boundary, including requests made by generated services.
- Expiry or `401` shows an explicit sign-in-again action without automatically
  redirecting during work. `403` is a permission error. Mutations are not replayed.
- Logout clears client authentication and invokes the provider's OIDC logout.

Access tokens last 15 minutes. Refresh tokens and silent iframe renewal are not
used. The existing Spring login session may avoid another password prompt during
reauthorization. Roles are server-managed and enforced by Spring on every API call.

## Generated API contracts

`contracts/openapi.json`, `ng-openapi-gen.json`, the npm lockfile and generated
`src/app/api/` are committed. Do not hand-edit generated files.

```sh
# Export the live backend specification, then regenerate.
API_BASE_URL=http://localhost:8080 npm run update:api

# Regenerate from the saved snapshot; backend not required.
npm run generate:api
```

`npm run build` regenerates from the saved snapshot automatically. It does not
fetch the backend. Refresh the snapshot explicitly after changing the API, then
compile/test and review the generated diff. Response schemas declare required
properties, so generated TypeScript accurately represents those guarantees.
Generated types are compile-time contracts, not runtime response validators.

## Runtime configuration and Docker

The browser loads `/config.json` before bootstrap. Local `npm start`/build scripts
generate it using `API_BASE_URL` (default `http://localhost:8080`) and
`AUTH_ISSUER_URL` (defaults to the API base URL). The file is ignored by Git.

The Docker build uses the local contract snapshot. An unprivileged Nginx container
serves the production bundle, supports direct SPA route refreshes and writes
runtime configuration at startup. API and issuer URLs refer to addresses reachable
by the **browser**, not Docker service names. Configuration is served without
caching; hashed assets can be cached independently.

The root Compose stack passes `WEB_ORIGIN` to Spring for exact callback registration
and CORS. All containers expose ports on loopback for local assessment use.

## Verification

```sh
npm test
npm run build
```

Vitest tests cover HTTP token scoping, auth initialization/expiry/guards, safe
return routes, error translation, typed form validation, timestamp conversion,
draft recovery, create/update coordination, booking cancellation and all-user
query scope, paged navigation, last-page recovery and bounded event selection.
Tests mock the API/auth provider and do not require a live backend.

For a manual CRUD walkthrough, create a future event, edit it, filter and inspect
it, then delete it with confirmation. Use another event for booking history:
reserve via a participant API client, inspect and cancel from the web app, and
observe the backend's restriction against deleting events with booking history.

## Deliberate trade-offs

- Per-feature components and framework facilities keep the assessment small;
  there is no global domain-data store or generic schema-driven form engine.
- daisyUI provides CSS styling; Angular and native HTML handle behavior. Dialogs
  use native modal focus handling, labels are explicit, and motion respects the
  reduced-motion preference. Fonts are bundled locally.
- Total event capacity is displayed; the API does not expose remaining places.
