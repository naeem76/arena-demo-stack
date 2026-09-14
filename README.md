# Arena Assessment

This repository contains the Arena full-stack developer assessment. The project
will include a Spring Boot backend, an Angular web application, and a Flutter
mobile application.

The backend foundation and PostgreSQL development environment are currently set
up. This README will be updated as the implementation progresses.

## Run locally

Prerequisites: Docker with Docker Compose v2 or later.

From the repository root:

```sh
docker compose up --build --wait
```

- Backend health: <http://localhost:8080/actuator/health>
- Interactive API reference (Scalar): <http://localhost:8080/scalar>
- OpenAPI document: <http://localhost:8080/v3/api-docs>
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

Tests cover API errors, validation, CORS, documentation, and application startup
against a disposable PostgreSQL instance managed by Testcontainers. They do not
use the Compose database. Docker image builds skip test execution; run the
verification command above separately.

See [backend API foundation](backend/README.md) for error conventions, CORS
configuration, and the opt-in diagnostic controller used for manual testing.

This initial scaffold has no domain endpoints yet. Flyway is
configured through Spring Boot auto-configuration; versioned migrations will be
added alongside the domain schema. Hibernate validates the schema rather than
creating or updating it.
