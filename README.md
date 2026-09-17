# Arena

Arena is an event and booking administration application with a Spring Boot
backend, Angular administration SPA, and Flutter mobile administration app.

The Angular app supports complete Event CRUD, lifecycle management and cross-user
booking inspection/cancellation, backed by database-persisted users and OAuth2/OIDC
login. Angular and Flutter generate their API clients from the same OpenAPI
snapshot. Flutter provides native administrator sign-in,
session handling, full Event CRUD and booking inspection/cancellation.

## Run locally

Prerequisites: Docker with Docker Compose v2 or later.

From the repository root:

```sh
docker compose up --build --wait
```

- Angular admin workspace: <http://localhost:4200>
- Backend health: <http://localhost:8080/actuator/health>
- Interactive API reference (Scalar): <http://localhost:8080/scalar>
- OpenAPI document: <http://localhost:8080/v3/api-docs>
- OpenID Connect discovery: <http://localhost:8080/.well-known/openid-configuration>
- Local admin sign-in: `admin` / `arena-admin` (Angular workspace and Scalar)
- Local user sign-in: `demo` / `arena-demo` (API personal bookings; no admin workspace access)
- PostgreSQL: `localhost:5432`, database `arena`
- Local development database credentials: `arena` / `arena_local`

The health endpoint returns `{"status":"UP"}` when the application and its
database connection are healthy. Database data persists in a Docker volume.
The bundled credentials are for local development only.

Stop the services with `docker compose down`. To also delete local database
data, use `docker compose down --volumes`.

If the default ports are occupied, set `WEB_PORT`, `BACKEND_PORT` and/or `POSTGRES_PORT`:

```sh
WEB_PORT=4201 BACKEND_PORT=8081 POSTGRES_PORT=5433 docker compose up --build --wait
```

Compose derives browser API/issuer URLs and the registered Angular callback from
these ports. Open the web app using `localhost`, matching the registered origin.
For custom hostnames, configure `WEB_ORIGIN`, `CORS_ALLOWED_ORIGINS`, `API_BASE_URL`
and `AUTH_ISSUER_URI` with the externally reachable URLs.

## Architecture decisions

- **Scope:** Events are the primary CRUD entity in both admin clients. Bookings
  add capacity, ownership and cancellation workflows while preserving history.
- **Backend structure:** One Spring Boot application separates HTTP, transactional
  services, domain rules and persistence. Separate API DTOs protect the contract;
  JPA-backed domain entities avoid duplicate models.
- **Persistence:** PostgreSQL constraints and shared event-row locking protect
  integrity and capacity. Flyway manages schema changes; Hibernate validates them.
  Booking history prevents event deletion.
- **API contracts:** Both clients generate transport code from one committed
  OpenAPI snapshot. Forms, state and application behavior remain handwritten.
- **Authentication:** Spring OAuth/OIDC with PKCE serves browser and native
  clients. The server enforces roles and ownership. Accounts persist;
  authorization state and signing keys reset on restart.
- **Client state and recovery:** Authentication is shared; feature state stays
  local. Identity-scoped drafts preserve edits, expiry requires sign-in, and
  mutations are never automatically replayed.
- **Data loading:** Server-side filtering and bounded pagination avoid
  whole-collection downloads. Angular preserves list context in URLs; Flutter
  refreshes on view activation and supports Load more.
- **Local deployment:** Compose runs the stack. Optional mDNS discovery simplifies
  physical-device access, with explicit endpoint configuration available.
- **Errors and testing:** Centralized errors mask internals; request IDs support
  diagnostics. Injectable dependencies enable focused client tests, while backend
  integration tests use real PostgreSQL through Testcontainers.

See the [backend](backend/README.md), [Angular](web/README.md) and
[Flutter](mobile/README.md) documentation for details and trade-offs.

## Local API discovery

The backend's published port binds to `0.0.0.0` so devices on the local network
can reach it. The `mdns` service advertises `_arena-api._tcp.local.` with the host's
LAN address, published backend port, and API metadata. PostgreSQL and Angular
bind to loopback.

The advertiser uses Linux host networking for local multicast. The phone must
be on a network that permits mDNS traffic between it and the development host.
`MDNS_ADDRESS` can select a particular host LAN IPv4 address when automatic
interface selection is unsuitable, for example with multiple network adapters:

```sh
MDNS_ADDRESS=192.168.1.50 docker compose up --build --wait
```

Flutter checks for the service at startup unless an explicit `API_BASE_URL` is
provided. Discovery supplies an API address; it does not configure HTTPS or
change the backend's OIDC issuer and callback settings. Debug mobile sign-in
connects through the discovered address while retaining the canonical issuer;
HTTPS deployment configuration remains a separate step.

## Angular development

Prerequisite: Node.js 24.15+ (24.x); `.nvmrc` pins 24.19.0. From `web/`:

```sh
npm ci
npm start
```

The backend must be running for sign-in and live data. If the Compose web service
already occupies port 4200, stop it with `docker compose stop web` from the root.
For a backend on a different port:

```sh
API_BASE_URL=http://localhost:18080 npm start
```

Build and run frontend tests from `web/`:

```sh
npm test
npm run build
```

Builds regenerate the typed API client from the shared OpenAPI snapshot, so
they do not require a running backend. To refresh the snapshot and regenerate:

```sh
API_BASE_URL=http://localhost:8080 npm run update:api
```

See [web application](web/README.md) for structure, authentication, runtime
configuration and testing.

## Flutter development

The mobile project targets Android and iOS. Use the Flutter SDK version pinned in
`mobile/.flutter-version`; Flutter includes the matching Dart SDK. Android builds
also require the Android SDK, and iOS builds require macOS and Xcode.

See [mobile application](mobile/README.md) for setup, generated API tooling,
test commands and supported workflows. Android debug builds
support LAN HTTP sign-in using discovered or explicitly configured endpoint addresses;
the backend's canonical issuer remains unchanged. Release/profile authentication
requires HTTPS and normal discovery.

## Backend development

The backend uses Java 21, Spring Boot 3.5.16, Spring Data JPA, PostgreSQL, Flyway,
and Actuator. The Maven Wrapper is included; a separate Maven installation is
not required.

To run the backend directly, install JDK 21 and start PostgreSQL from the root:

```sh
docker compose up --wait postgres
```

Then, from `backend/`:

```sh
./mvnw spring-boot:run
```

Use `mvnw.cmd` on Windows. If the containerized backend is already running, stop
it with `docker compose stop backend` before starting the local process.
Database settings can be overridden through `DATABASE_URL`, `DATABASE_USERNAME`,
and `DATABASE_PASSWORD`; the defaults match the local Compose database.

Build and verify from `backend/` with Docker running:

```sh
./mvnw verify
```

Tests cover API errors, validation, CORS, documentation, OAuth authorization-code
and PKCE exchanges, OIDC discovery/ID tokens/UserInfo, JWT validation, scope
and role enforcement, password storage, account login, Event CRUD,
booking ownership/history, concurrent capacity enforcement, persistence and
schema constraints, and application startup
against a disposable PostgreSQL instance managed by Testcontainers. They do not
use the Compose database. Docker image builds skip test execution; run the
verification command above separately.

See [backend API](backend/README.md) for Scalar sign-in instructions,
error conventions, CORS configuration, and the opt-in diagnostic controller.

The authenticated Event and Booking APIs are available at `/api/events` and
`/api/bookings`, and documented in Scalar. Both lists accept zero-based `page`
(default `0`) and `size` (default `20`, maximum `100`). Responses contain
`items`, `page`, `size`, `totalElements`, and `totalPages`. Filtering and
authorization are applied before database pagination. The Angular lists and
booking event selector load one page at a time.

Flyway applies versioned migrations from
`backend/src/main/resources/db/migration` at startup.
Hibernate validates the schema rather than creating or updating it.
