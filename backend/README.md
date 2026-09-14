# Backend API foundation

See the [root README](../README.md) for build and startup instructions.

## Structure

- `api/`: HTTP controllers and centralized exception handling.
- `configuration/`: OpenAPI metadata and browser CORS configuration.
- `api/diagnostics/`: diagnostic endpoints enabled only by the `diagnostics` profile.

The backend is a single Maven project. Domain, application-service, and persistence
packages will be introduced with the corresponding functionality.

## API documentation

- `/scalar`: interactive Scalar reference.
- `/v3/api-docs`: generated OpenAPI JSON.

The document is generated from the running application's `/api/**` endpoints.
Scalar's own page and JavaScript routes are excluded. Diagnostic endpoints appear
only when their profile is enabled. The Scalar integration serves its JavaScript
bundle from `/scalar/scalar.js`.

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

Examples, using the default backend port:

```sh
curl -i http://localhost:8080/api/diagnostics/errors/404
curl -i http://localhost:8080/api/diagnostics/errors/409
curl -i http://localhost:8080/api/diagnostics/errors/503
curl -i http://localhost:8080/api/diagnostics/errors/unexpected

curl -i http://localhost:8080/api/diagnostics/validation \
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
