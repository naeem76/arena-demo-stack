# Arena Assessment

This repository contains the Arena full-stack developer assessment. The project
will include a Spring Boot backend, an Angular web application, and a Flutter
mobile application.

The backend Event CRUD API, Event/User persistence, and database-backed login are
implemented. This README will be updated as the implementation progresses.

## Run locally

Prerequisites: Docker with Docker Compose v2 or later.

From the repository root:

```sh
docker compose up --build --wait
```

- Backend health: <http://localhost:8080/actuator/health>
- Interactive API reference (Scalar): <http://localhost:8080/scalar>
- OpenAPI document: <http://localhost:8080/v3/api-docs>
- Local demo sign-in for Scalar: `demo` / `arena-demo`
- PostgreSQL: `localhost:5432`, database `arena`
- Local development database credentials: `arena` / `arena_local`

The health endpoint returns `{"status":"UP"}` when the application and its
database connection are healthy. Database data persists in a Docker volume.
The bundled credentials are for local development only.

Stop the services with `docker compose down`. To also delete local database
data, use `docker compose down --volumes`.

If the default ports are occupied, set `BACKEND_PORT` and/or `POSTGRES_PORT`:

```sh
BACKEND_PORT=8081 POSTGRES_PORT=5433 docker compose up --build --wait
```

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
and PKCE exchanges, JWT validation, scope enforcement, password storage, account
login, Event business rules and CRUD contracts, persistence and schema constraints,
and application startup
against a disposable PostgreSQL instance managed by Testcontainers. They do not
use the Compose database. Docker image builds skip test execution; run the
verification command above separately.

See [backend API foundation](backend/README.md) for Scalar sign-in instructions,
error conventions, CORS configuration, and the opt-in diagnostic controller.

The authenticated Event API is available at `/api/events` and documented in Scalar.
Flyway applies
versioned migrations from `backend/src/main/resources/db/migration` at startup.
Hibernate validates the schema rather than creating or updating it.
