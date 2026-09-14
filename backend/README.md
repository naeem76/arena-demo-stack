# Backend API foundation

See the [root README](../README.md) for build and startup instructions.

## Structure

- `api/`: HTTP controllers and centralized exception handling.
- `configuration/`: OpenAPI, CORS, authorization-server, and security configuration.
- `security/`: API scopes and security-filter Problem Details responses.
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
external URL. `DEMO_USERNAME` and `DEMO_PASSWORD` override the demo credentials.

This assessment setup stores the demo user, client registration, and authorization
state in memory. A new RSA signing key is generated at startup. Restarting the
backend invalidates previously issued tokens; authorize again in Scalar. Private
keys and tokens are not stored in the repository. This is a local demonstration
setup, not a persistent identity-management system.

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
