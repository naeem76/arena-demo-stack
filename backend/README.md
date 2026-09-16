# Arena backend API

See the [root README](../README.md) for build and startup instructions.

## Structure

- `api/`: HTTP controllers and centralized exception handling.
- `api/event/`: Event request/response DTOs, mapping, and CRUD controller.
- `api/booking/`: shared user/admin reservation endpoints and DTOs.
- `application/event/`: transactional Event use cases and time-dependent creation validation.
- `application/booking/`: transactional reservation, ownership, and capacity checks.
- `domain/event/`: the Event model, status enum, and repository contract.
- `domain/booking/`: the reservation model, status enum, and repository contract.
- `domain/user/`: the account/profile model and repository contract.
- `infrastructure/persistence/event/`: Spring Data JPA repository and its adapter.
- `infrastructure/persistence/booking/`: Spring Data queries, event fetching, and reservation counts.
- `infrastructure/persistence/user/`: Spring Data JPA account lookup and its adapter.
- `configuration/`: OpenAPI, CORS, authorization-server, and security configuration.
- `security/`: API scopes and security-filter Problem Details responses.
- `api/diagnostics/`: diagnostic endpoints enabled only by the `diagnostics` profile.

The backend is a single Maven project. Controllers use application services, which
coordinate repository operations and invoke entity business methods. Shared
invalid-input, state-conflict, and not-found exceptions are mapped centrally to
Problem Details responses.

## Request failure observability

`web/RequestLoggingFilter` is registered for servlet `REQUEST` and `ERROR`
dispatches at `Ordered.HIGHEST_PRECEDENCE`, outside Spring Security. It logs
browser, OAuth, CSRF, and security-filter failures even when they do not
reach MVC's `ApiExceptionHandler`.

- Each request receives a new server-generated UUID in `X-Request-ID`; incoming
  IDs are ignored. The ID is retained across ERROR dispatches and installed in
  MDC as `requestId` during each dispatch, then the previous MDC value is restored.
- The failure summary includes method, original path, status, request ID, and
  source (`REQUEST`, `ERROR`, or `escaped_exception`). IDs are explicit in the
  message, so the default logging pattern needs no change.
- HTTP 4xx summaries use WARN and 5xx use ERROR. Successful responses and redirects
  do not emit failure summaries; this is not an authentication-event audit log.
- `sendError` summaries are deferred to the container's ERROR dispatch, using
  `jakarta.servlet.error.request_uri` and `jakarta.servlet.error.status_code` rather
  than merely `/error`. Escaping exceptions are logged immediately as 500 and
  rethrown unchanged. Request-scoped state limits this filter to one failure
  summary, including repeated/nested ERROR dispatches.
- The filter never reads/logs query parameters, request bodies, authorization
  headers, cookies, or exception messages/causes/stack traces. Paths are limited
  to 512 characters, stripped at `?` defensively, and whitespace/control/non-ASCII
  characters are replaced with `_` to prevent log injection. Methods are likewise
  sanitized and limited to 16 characters. Keep credentials out of URL paths.
- `ApiExceptionHandler` also logs 5xx stack traces. This
  filter does not change other framework/container logging or provide distributed
  tracing, async completion tracking, or OpenTelemetry instrumentation.

`RequestLoggingIntegrationTests` uses real embedded Tomcat and PostgreSQL to
exercise security rejection, OAuth token errors, unmapped paths, and actual
container ERROR dispatches. `RequestLoggingFilterTests` covers exception redaction,
ID reuse, MDC cleanup, original error attributes, bounds, and duplicate suppression.
Both capture Logback events to validate correlation and secret-sentinel exclusion.

Live checks against `http://localhost:8080` (inspect `X-Request-ID` in the response
and match it to the backend log):

| Request | Expected result |
| --- | --- |
| `GET /actuator/health` | 200, fresh ID, no failure summary |
| `GET /api/events` without bearer credentials | 401 summary |
| `POST /login` without CSRF | 403 with original `/login` in ERROR summary |
| `GET /scalar/unmapped-observability-check` | 404 summary |
| `POST /oauth2/token` without client credentials or grant parameters | 401 summary |
| `GET /oauth2/authorize` without authorization parameters | 400 summary |

The 500 servlet used by integration tests is test-only. Direct form login with no
saved authorization request defaults to `/`, which the browser security chain
denies for authenticated users with `403`. Start an OAuth flow from a client to
supply a saved authorization request. An anonymous GET `/` redirects to login.

## Event API

All endpoints require a bearer token with `api.access` and a `USER` or `ADMIN`
role. Both roles can read events; creating, editing, changing status and deleting
events additionally require `ADMIN`.

| Method | Path | Behavior |
| --- | --- | --- |
| GET | `/api/events` | Page through events; optional `sport` and `status` filters |
| GET | `/api/events/{id}` | Read one event |
| POST | `/api/events` | Create; returns `201` and a `Location` header |
| PUT | `/api/events/{id}` | Replace editable details; returns `200` |
| PATCH | `/api/events/{id}/status` | Change lifecycle status; returns `200` |
| DELETE | `/api/events/{id}` | Delete; returns bodyless `204` |

POST and PUT share the same request fields. The server manages the ID, audit
timestamps, and initial `SCHEDULED` status:

```json
{
  "title": "Community football",
  "description": "A friendly local match",
  "sport": "Football",
  "location": "Riverside Park",
  "startsAt": "2030-01-01T10:00:00Z",
  "endsAt": "2030-01-01T11:00:00Z",
  "capacity": 20
}
```

Use future dates when creating an event. Times are ISO-8601 instants; `description`
is optional. Status changes use a separate body, for example `{"status":"LIVE"}`.
Sport filtering is case-insensitive and ignores surrounding whitespace. Status
filters use the enum names. Lists are ordered by start time ascending and then UUID
ascending. See **Pagination** below for the shared list response contract.

### Pagination

`GET /api/events` and `GET /api/bookings` accept:

| Parameter | Default | Accepted values |
| --- | --- | --- |
| `page` | `0` | Zero-based, nonnegative integer |
| `size` | `20` | Integer from `1` through `100` |

Invalid bounds, blank/nonnumeric/fractional values, and values outside the Java
integer range return `400 application/problem+json` through the existing error
handler, with pagination field errors. Omitting a parameter applies its default;
an explicitly blank value is invalid. Clients cannot choose a different sort order.

Both endpoints return a page object:

```json
{
  "items": [],
  "page": 0,
  "size": 20,
  "totalElements": 0,
  "totalPages": 0
}
```

All five properties are required. `items` contains the existing Event or Booking
response DTOs. `totalElements` counts all matching, authorized records before
pagination; `totalPages` is the ceiling of that count divided by `size`. A page
beyond the matching results returns `200` with empty `items`, the requested
`page` and `size`, and the correct totals. No matches means both totals are zero.

Filtering and booking ownership are applied in the database before offset/limit
and counting, so totals do not disclose other users' records. Stable UUID
tie-breakers make ordering deterministic for unchanged data; separate page
requests do not provide a snapshot across concurrent inserts/deletes.

The generated OpenAPI schemas are **`EventPageResponse`** and
**`BookingPageResponse`**, matching the frontend contract. Their `items` reference
`EventResponse` and `BookingResponse`, with required item fields preserved (Event
`description` remains optional and nullable). Internal services/repositories use
Spring Data `Page`/`Pageable` pragmatically; the HTTP boundary maps into explicit
DTOs using shared `PageResponse` metadata, never Spring `Page` serialization.

```text
GET /api/events?sport=Football&status=SCHEDULED&page=0&size=20
GET /api/bookings?scope=all&status=CONFIRMED&page=1&size=10
```

The shared `api/PaginationRequest` query DTO centralizes defaults, Bean Validation
bounds, and `toPageRequest()`. Controllers bind it using `@Valid @ModelAttribute`;
`@ParameterObject` exposes flat optional `page` and `size` query parameters in
OpenAPI, including defaults and minimum/maximum values. Resource-specific filters
remain separate controller parameters.

### Business rules

- New events must start in the future, checked using an injected `Clock`.
- Only `SCHEDULED` events allow detail edits. Capacity must remain positive and
  the end time must be after the start time.
- Allowed transitions: `SCHEDULED → LIVE`, `SCHEDULED → CANCELLED`,
  `LIVE → COMPLETED`, and `LIVE → CANCELLED`.
- `COMPLETED` and `CANCELLED` are terminal states. Repeating the current status
  succeeds without changing it, so status updates are idempotent.
- Transitions are manual, not driven by a scheduler or restricted to the scheduled start time.
- Missing resources return `404`, invalid input returns `400`, and disallowed
  edits/transitions return `409`. Rejected changes leave stored data unchanged.

Events with any booking records cannot be deleted, including when all bookings
are cancelled. Cancel the event instead. Capacity cannot be reduced below the
confirmed booking count. Event edits, status changes, and deletion lock the same
event row used by reservation transactions.

## Booking API

| Method | Path | Behavior |
| --- | --- | --- |
| GET | `/api/bookings` | Page through personal booking history by default; admins can request `scope=all` |
| GET | `/api/bookings/{id}` | Read a booking as its owner or an admin |
| POST | `/api/bookings` | Reserve one place; returns `201` and `Location` |
| POST | `/api/bookings/{id}/cancel` | Cancel as the owner or an admin; returns `200` |

Creation accepts `{"eventId":"<event-uuid>"}`. The owner is taken from the JWT
subject, including for admins; no user ID or status is accepted as an input field.
All operations require `api.access` and a recognized role. Ordinary users receive
`404` for both missing bookings and bookings owned by someone else.

Listing defaults to `scope=mine` for **both** roles. Only admins may request
`scope=all`; a regular user receives `403`. Both modes accept optional `eventId`
and `status=CONFIRMED|CANCELLED` filters and return creation time descending, with
UUID descending as a tie-breaker. For example:

```text
GET /api/bookings?scope=all&eventId=<event-uuid>&status=CONFIRMED
```

Both listing modes use the shared **Pagination** contract above. Responses include
a `participant` summary with only the user's `id` and `displayName`, alongside the
existing Event and booking fields. No user entity, password hash or account role
is serialized.

The service uses the verified caller's authorities to choose an unrestricted
primary-key lookup for admins or an owner-scoped lookup for users. Admin access
does not bypass lifecycle, capacity or history rules, and does not transfer
booking ownership. Roles or owner IDs supplied as request parameters do not
grant access.

### Reservation rules and availability

- Booking is allowed only while the event is `SCHEDULED` and its start time is
  still in the future.
- Each booking reserves one place. Availability is calculated from
  `event.capacity - confirmed booking count`; there is no separate stored counter.
- A user can have only one `CONFIRMED` booking per event. Duplicate active
  reservations and full events return `409`.
- Cancellation, including by admins, is allowed before the scheduled start time
  unless the event has already become `LIVE` or `COMPLETED`. Repeated cancellation succeeds without
  creating another row or changing the original cancellation result.
- Rebooking always creates a **new row and UUID**. The previous cancelled row
  remains in history and does not consume capacity.
- Responses include current Event details. Cancelling an event leaves reservation
  rows intact; clients can see `event.status = CANCELLED` alongside booking status.

### Persistence and concurrency

[V3__create_bookings.sql](src/main/resources/db/migration/V3__create_bookings.sql)
adds Event/User foreign keys, audit timestamps, and a partial unique index on
`(event_id, user_id)` for `CONFIRMED` rows only. Foreign keys prevent deleting
parents with reservation history.

Creation and cancellation acquire a Spring Data JPA `PESSIMISTIC_WRITE` lock on
the event row before checking current state and capacity. Event mutations follow
the same lock order, keeping capacity reductions, status changes, and deletion
consistent with concurrent reservations. Cancellation initially reads only the
authorized booking's event ID, then reloads the booking after obtaining the lock.
Owner/admin simultaneous cancellations use the same transaction path.

Tests use concurrent transactions against PostgreSQL to exercise last-place
reservations, duplicate requests, capacity reductions, and repeated cancellations.

## Event persistence

`Event` is both the domain model and JPA-mapped entity. API request/response DTOs
define the external contract independently of the persistence model.

| Field | Storage and constraints |
| --- | --- |
| `id` | Application-generated UUID primary key |
| `title` | Required, nonblank, up to 150 characters |
| `description` | Optional, up to 2,000 characters |
| `sport` | Required, nonblank, up to 50 characters; new sport names require no enum/schema change |
| `location` | Required, nonblank, up to 200 characters |
| `startsAt`, `endsAt` | Required instants; end must be after start |
| `capacity` | Positive integer |
| `status` | `SCHEDULED`, `LIVE`, `COMPLETED`, or `CANCELLED`; new events default to `SCHEDULED` |
| `createdAt`, `updatedAt` | Automatically maintained through Spring Data JPA auditing |

Times use Java `Instant` and PostgreSQL `TIMESTAMP WITH TIME ZONE`. Status is stored
by name, with a database check constraint, rather than by enum ordinal. The initial
schema is defined in [V1__create_events.sql](src/main/resources/db/migration/V1__create_events.sql).
Subsequent schema changes belong in new versioned migrations; applied migrations
should not be edited. Historical event times are valid persisted data.

`EventRepository` exposes save, find-by-ID, list, and delete-by-ID operations.
`EventPersistenceAdapter` implements that contract through `JpaEventRepository`.
Spring Data page types are shared internally; query execution remains in
infrastructure. Entity fields are validated on persistence, and database
constraints also protect direct SQL writes.

PostgreSQL-backed tests verify CRUD, filtering, UUID generation, audit timestamps,
status mapping, schema constraints, and HTTP contracts. Unit tests verify the
entity's lifecycle rules and the service's time-dependent creation rules.

## User persistence

`User` stores a UUID, username (up to 50 characters), display name (up to 100
characters), password hash, role, enabled flag, and audit timestamps. Usernames are
unique and looked up case-insensitively. The schema is defined in
[V2__create_users.sql](src/main/resources/db/migration/V2__create_users.sql).

[V4__add_user_roles.sql](src/main/resources/db/migration/V4__add_user_roles.sql)
adds a non-null `USER`/`ADMIN` role with a database check constraint. Existing
accounts default to `USER`; roles are server-managed, with no public role-update
endpoint. The separately seeded admin account receives `ADMIN` when first created.

Spring's `UserDetailsService` loads accounts through `UserRepository` and returns
the framework's standard `UserDetails`. Password hashing and verification use
Spring's `BCryptPasswordEncoder` at cost 12 with a fresh random salt per hash.
Raw passwords are never stored in PostgreSQL. The database enforces BCrypt hash
format, and the entity's password hash is excluded from JSON serialization.

Passwords exceeding 72 UTF-8 bytes are rejected at creation and login, preventing
BCrypt suffix truncation. Incorrect credentials and disabled accounts receive the
same public login failure message. The JWT `sub` claim contains the persisted
user UUID; the username remains the login identifier.

Disabling an account prevents new password logins. Previously issued JWTs retain
their normal lifetime. User registration and profile-management endpoints are
not exposed by the API.

## API documentation

- `/scalar`: interactive Scalar reference.
- `/v3/api-docs`: generated OpenAPI JSON.

The document is generated from the running application's `/api/**` endpoints.
Scalar's own page and JavaScript routes are excluded. Diagnostic endpoints appear
only when their profile is enabled. The Scalar integration serves its JavaScript
bundle from `/scalar/scalar.js`.

## Authentication and authorization

Spring Authorization Server supports OAuth2 and OpenID Connect (OIDC), issuing
signed JWT access tokens and ID tokens. Spring Security's resource-server support
validates access tokens for `/api/**` requests.

| Endpoint | Purpose |
| --- | --- |
| `/oauth2/authorize` | OAuth2 authorization-code flow |
| `/oauth2/token` | Exchange an authorization code and PKCE verifier for tokens |
| `/oauth2/jwks` | Public signing keys |
| `/.well-known/oauth-authorization-server` | Authorization-server metadata |
| `/.well-known/openid-configuration` | OIDC discovery document |
| `/userinfo` | OIDC subject and scope-authorized profile claims; requires an access token |
| `/connect/logout` | OIDC RP-initiated logout with an ID-token hint and registered redirect |
| `/login` | Spring's demo-user sign-in form |

These protocol endpoints are supplied by Spring Security filters. In Scalar they
are represented by the `arenaOAuth` security scheme, rather than duplicate
controller definitions.

The `scalar`, `arena-web`, and `arena-mobile` clients are public and require authorization code +
PKCE (SHA-256). None has a client secret. Access tokens last 15 minutes; refresh tokens and the
password/client-credentials grants are not configured.

`arena-web` is the Angular client, with registered scopes `openid`, `profile`, and
`api.access`. Its callback is `${app.security.web-origin}/auth/callback` and its
registered post-logout redirect is `${app.security.web-origin}/signed-out`.
`WEB_ORIGIN` sets this property and defaults to `http://localhost:4200`; configure
`CORS_ALLOWED_ORIGINS` to allow that origin when changing it. Scalar's callback
remains `${app.security.issuer}/scalar`.

For Angular sign-out, navigate to `/connect/logout` with `id_token_hint` containing
the issued ID token and `post_logout_redirect_uri` set to the registered
`/signed-out` URL. Optional `state` is returned to that URL. Spring invalidates
the browser login session and rejects unregistered logout redirects. Issued
access JWTs retain their normal lifetime.

Request `openid` alongside `api.access` to receive an ID token. Add `profile`
to include the user's display name in the standard `name` claim. Both access and
ID tokens use the persisted user UUID as `sub`; ID tokens also identify the
client in `aud` and return the authorization request's `nonce` when supplied.
Use the access token for API calls, not the ID token.

Spring's default UserInfo implementation returns `sub` and, when `profile` was
authorized, `name`, derived from the ID token. Profile data reflects token issuance
time. Credentials and password hashes are never included. OAuth-only requests
without `openid` continue to work and do not receive an ID token or UserInfo access.

- Every request under `/api/**` requires `api.access` and a `USER` or `ADMIN` role.
- Event mutations additionally require `ADMIN`; booking access is owner-or-admin.
- Access-token `roles` claims come from the persisted account and are mapped by
  Spring's JWT converters to `ROLE_USER` or `ROLE_ADMIN`, alongside scope authorities.
  ID tokens do not carry API roles and cannot authorize API requests.
- Missing or invalid bearer tokens produce `401`; missing scope or role produces `403`.
- Documentation and health endpoints remain public.

The `api.access` scope grants API access. Roles and ownership
determine permitted operations; separate read-only client delegation is not
provided.
Account role changes affect newly issued tokens; existing tokens retain their
claims until expiry or backend restart.

The API uses a stateless security chain. Browser login sessions are used for the
authorization flow, but do not authenticate API requests. CSRF protection remains
enabled for browser login; it is disabled only in the bearer-token API chain.
JWT validation checks the signature, issuer, and token lifetime.

### Sign in through Scalar

1. Enable the diagnostic endpoints using the command in **Manual error testing** below.
2. Open `/scalar` on the configured issuer origin.
3. In **Authentication**, keep `arenaOAuth`, client ID `scalar`, PKCE `SHA-256`,
   and the selected `api.access` scope. Leave **Client Secret** empty.
4. Click **Authorize**. In Scalar's popup, sign in as `admin` / `arena-admin` for
   Event management and cross-user bookings, or `demo` / `arena-demo` for normal
   user access.
5. Scalar exchanges the authorization code and attaches the access token to
   requests made with **Test Request**.

Optionally select `openid` and `profile` as well to exercise OIDC token issuance.
Discovery and UserInfo are framework protocol endpoints rather than CRUD routes
in the OpenAPI document.

To exercise a real authorization failure, sign in as `demo` with `api.access`
and try creating an event or listing `/api/bookings?scope=all`; both return `403`.
When switching accounts in Scalar, sign out of the Spring browser session first
using `/logout`, then authorize again with the other account.

### Native client authentication

`arena-mobile` is the Flutter native client, registered through the same public-client
factory with `openid`, `profile`, and `api.access`. Its server-managed redirect URIs
are exact constants:

- Authorization callback: `com.arena.mobile:/oauth/callback`
- Post-logout redirect: `com.arena.mobile:/signed-out`

Use the existing authorization-code flow with an S256 PKCE challenge and verifier.
For sign-out, use `/connect/logout` with the issued `id_token_hint`, the exact
post-logout URI above, and optional `state`. Unregistered redirect URIs are rejected.

For **debug-only LAN HTTP** authentication, Flutter uses a discovered or explicitly
configured backend address and supplies reachable endpoint aliases through AppAuth's manual
`serviceConfiguration`. Flutter decides the debug transport configuration. These
LAN URLs are connection endpoints, not additional issuer identities:
`AUTH_ISSUER_URI` stays fixed at the configured localhost issuer (default
`http://localhost:8080`), including discovery metadata and token `iss` claims.
The backend retains single-issuer validation; its issuer and Angular registration
do not change to match the phone's discovered LAN address.

### Local configuration and lifecycle

`AUTH_ISSUER_URI` defaults to `http://localhost:8080`. Compose derives it from
`BACKEND_PORT` unless explicitly overridden. Open Scalar using that exact origin;
`localhost` and `127.0.0.1` are different OAuth redirect origins. The registered
callback is `${AUTH_ISSUER_URI}/scalar`.

For a local Java process on a different port, set `AUTH_ISSUER_URI` to the matching
external URL. On first startup, `DEMO_USERNAME` / `DEMO_PASSWORD` supply the normal
demo account credentials; `DEMO_ADMIN_USERNAME` / `DEMO_ADMIN_PASSWORD` supply the
admin credentials. Defaults are `demo` / `arena-demo` and `admin` / `arena-admin`.
The initializer creates each account only if its username is absent; it never
overwrites an existing password, profile, enabled flag or role. Use distinct
usernames for the two accounts.
Changing these environment variables does not reset an existing account.
Set `SEED_DEMO_USER=false` to disable both demo accounts' initialization
(`app.security.seed-demo-user`).

User accounts and password hashes persist in PostgreSQL. OAuth client registration
and authorization state remain in memory, and a new RSA signing key is generated
at startup. Restarting the backend invalidates previously issued tokens; authorize
again in Scalar. Private keys and tokens are not stored in the repository.

## Error responses

MVC request errors use Spring's Problem Details support and
`application/problem+json`. The standard fields are `type`, `title`, `status`,
`detail`, and `instance`. Validation failures additionally contain an `errors`
array with `field` and `message` entries:

```json
{
  "type": "about:blank",
  "title": "Bad Request",
  "status": 400,
  "detail": "Request validation failed.",
  "instance": "/api/diagnostics/validation",
  "errors": [
    { "field": "quantity", "message": "must be greater than or equal to 1" }
  ]
}
```

Malformed JSON and parameter conversion failures receive safe `400` responses.
Server errors retain their HTTP status but return a generic message; exception
details are logged server-side. Framework responses preserve headers such as
`Allow` for unsupported methods.

API authentication and authorization failures also use Problem Details, produced
by security-specific handlers before controllers run. OAuth protocol endpoints
retain Spring Authorization Server's standard OAuth error payloads (such as
`invalid_grant`), rather than converting them to Problem Details.

## CORS

The shared security-filter CORS policy applies to `/api/**`, the OAuth/OIDC
metadata documents, `/oauth2/jwks`, `/oauth2/token`, and `/userinfo`. This includes
the protocol endpoints browser clients use for discovery and code exchange.
By default it permits the Angular development origin `http://localhost:4200`.
Set `CORS_ALLOWED_ORIGINS` to a comma-separated
list of exact browser origins to override it, for example:

```sh
CORS_ALLOWED_ORIGINS=http://localhost:4200,http://localhost:4300 docker compose up --wait
```

Run Compose commands from the repository root. Allowed methods are GET, POST,
PUT, PATCH, DELETE, and OPTIONS. Allowed request headers are Accept, Content-Type,
and Authorization; Location is exposed to clients. Cookie credentials are not
enabled. CORS rejections are handled by Spring's CORS processor with a `403`
response, before controller exception handling.

## Manual error testing

Enable diagnostics from the repository root:

```sh
SPRING_PROFILES_ACTIVE=diagnostics docker compose up --build --wait
```

For a locally running Java process, use
`SPRING_PROFILES_ACTIVE=diagnostics ./mvnw spring-boot:run` from `backend/`.
The normal startup configuration leaves these endpoints disabled.

| Request | Behavior |
| --- | --- |
| `GET /api/diagnostics/errors/{status}` | Returns the requested HTTP error (400–599) through the shared handler |
| `GET /api/diagnostics/errors/unexpected` | Throws an exception to exercise logging and masked `500` responses |
| `POST /api/diagnostics/validation` | Validates and echoes `name` (nonblank, up to 80 characters) and `quantity` (integer, 1–100) |

The diagnostics require the same bearer token and scopes as other API endpoints.
For command-line testing, set `ACCESS_TOKEN` to a token obtained through Scalar.
Examples, using the default backend port:

```sh
curl -i -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/diagnostics/errors/404
curl -i -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/diagnostics/errors/409
curl -i -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/diagnostics/errors/503
curl -i -H "Authorization: Bearer $ACCESS_TOKEN" http://localhost:8080/api/diagnostics/errors/unexpected

curl -i http://localhost:8080/api/diagnostics/validation \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"sample","quantity":0}'
```

Status values below 400 or above 599 trigger parameter validation; nonnumeric
values trigger conversion handling. The status endpoint simulates HTTP responses,
not real authentication, authorization, or rate-limiting behavior.

To disable diagnostics again:

```sh
SPRING_PROFILES_ACTIVE=default docker compose up --wait
```

Include the same `BACKEND_PORT` and `POSTGRES_PORT` overrides in Compose commands
if you are using nondefault ports.
