# Backend API foundation

See the [root README](../README.md) for build and startup instructions.

## Structure

- `api/`: HTTP controllers and centralized exception handling.
- `api/event/`: Event request/response DTOs, mapping, and CRUD controller.
- `api/booking/`: owner-scoped reservation endpoints and DTOs.
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

## Event API

All endpoints require a bearer token. GET requests use `api.read`; mutations use
`api.write`.

| Method | Path | Behavior |
| --- | --- | --- |
| GET | `/api/events` | List events; optional `sport` and `status` filters |
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
filters use the enum names. Lists are ordered by start time and then ID.

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
| GET | `/api/bookings` | List the signed-in user's complete booking history, newest first |
| GET | `/api/bookings/{id}` | Read an owned booking |
| POST | `/api/bookings` | Reserve one place; returns `201` and `Location` |
| POST | `/api/bookings/{id}/cancel` | Cancel an owned booking; returns `200` |

Creation accepts `{"eventId":"<event-uuid>"}`. The owner is taken from the JWT
subject; no user ID or status is accepted as an input field. Reads require
`api.read` and mutations require `api.write`. Missing bookings and bookings owned
by another user both return `404`.

### Reservation rules and availability

- Booking is allowed only while the event is `SCHEDULED` and its start time is
  still in the future.
- Each booking reserves one place. Availability is calculated from
  `event.capacity - confirmed booking count`; there is no separate stored counter.
- A user can have only one `CONFIRMED` booking per event. Duplicate active
  reservations and full events return `409`.
- Cancellation is allowed before the scheduled start time unless the event has
  already become `LIVE` or `COMPLETED`. Repeated cancellation succeeds without
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
owned booking's event ID, then reloads the booking after obtaining the lock.

Tests use concurrent transactions against PostgreSQL to exercise last-place
reservations, duplicate requests, capacity reductions, and repeated cancellations.

## Event persistence

`Event` is both the domain model and JPA-mapped entity. A separate persistence
model would duplicate its current fields without providing a useful mapping
boundary. Future API request/response DTOs will define the external contract.

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
`EventPersistenceAdapter` implements that contract through `JpaEventRepository`,
keeping Spring Data-specific operations inside infrastructure. Entity fields are
validated on persistence, and database constraints also protect direct SQL writes.

PostgreSQL-backed tests verify CRUD, filtering, UUID generation, audit timestamps,
status mapping, schema constraints, and HTTP contracts. Unit tests verify the
entity's lifecycle rules and the service's time-dependent creation rules.

## User persistence

`User` stores a UUID, username (up to 50 characters), display name (up to 100
characters), password hash, enabled flag, and audit timestamps. Usernames are
unique and looked up case-insensitively. The schema is defined in
[V2__create_users.sql](src/main/resources/db/migration/V2__create_users.sql).

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
not part of this persistence step.

## API documentation

- `/scalar`: interactive Scalar reference.
- `/v3/api-docs`: generated OpenAPI JSON.

The document is generated from the running application's `/api/**` endpoints.
Scalar's own page and JavaScript routes are excluded. Diagnostic endpoints appear
only when their profile is enabled. The Scalar integration serves its JavaScript
bundle from `/scalar/scalar.js`.

## Authentication and authorization

Spring Authorization Server issues signed JWT access tokens, and Spring Security's
resource-server support validates them for `/api/**` requests.

| Endpoint | Purpose |
| --- | --- |
| `/oauth2/authorize` | OAuth2 authorization-code flow |
| `/oauth2/token` | Exchange an authorization code and PKCE verifier for an access token |
| `/oauth2/jwks` | Public signing keys |
| `/.well-known/oauth-authorization-server` | Authorization-server metadata |
| `/login` | Spring's demo-user sign-in form |

These protocol endpoints are supplied by Spring Security filters. In Scalar they
are represented by the `arenaOAuth` security scheme, rather than duplicate
controller definitions.

The `scalar` client is public and requires authorization code + PKCE (SHA-256).
It has no client secret. Access tokens last 15 minutes; refresh tokens and the
password/client-credentials grants are not configured.

- GET and HEAD requests under `/api/**` require `api.read`.
- Mutating requests require `api.write`.
- Missing or invalid bearer tokens produce `401`; insufficient scope produces `403`.
- Documentation and health endpoints remain public.

The API uses a stateless security chain. Browser login sessions are used for the
authorization flow, but do not authenticate API requests. CSRF protection remains
enabled for browser login; it is disabled only in the bearer-token API chain.
JWT validation checks the signature, issuer, and token lifetime.

### Sign in through Scalar

1. Enable the diagnostic endpoints using the command in **Manual error testing** below.
2. Open `/scalar` on the configured issuer origin.
3. In **Authentication**, keep `arenaOAuth`, client ID `scalar`, PKCE `SHA-256`,
   and the selected `api.read` / `api.write` scopes. Leave **Client Secret** empty.
4. Click **Authorize**. In the popup, sign in with username `demo` and password
   `arena-demo`.
5. Scalar exchanges the authorization code and attaches the access token to
   requests made with **Test Request**.

To exercise a real authorization failure, obtain a token with only `api.read`
selected and send a POST to the validation endpoint; it returns `403`.

### Local configuration and lifecycle

`AUTH_ISSUER_URI` defaults to `http://localhost:8080`. Compose derives it from
`BACKEND_PORT` unless explicitly overridden. Open Scalar using that exact origin;
`localhost` and `127.0.0.1` are different OAuth redirect origins. The registered
callback is `${AUTH_ISSUER_URI}/scalar`.

For a local Java process on a different port, set `AUTH_ISSUER_URI` to the matching
external URL. On first startup, `DEMO_USERNAME` and `DEMO_PASSWORD` supply the demo
account credentials. The initializer creates that account only if its username
is absent; it never overwrites an existing password, profile, or enabled flag.
Changing these environment variables does not reset an existing account.
Set `SEED_DEMO_USER=false` to disable initialization (`app.security.seed-demo-user`).

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

The policy applies to `/api/**`. By default it permits the Angular development
origin `http://localhost:4200`. Set `CORS_ALLOWED_ORIGINS` to a comma-separated
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
