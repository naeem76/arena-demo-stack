# Arena mobile

Flutter Android/iOS administration app.

The app provides native browser OIDC authorization-code/PKCE sign-in, ADMIN-only
navigation, secure session storage, Event CRUD, booking inspection/cancellation,
account identity and logout. Riverpod manages dependencies for the generated API
client, scoped bearer-token attachment, page-response validation, shared API
errors and bounded native mDNS startup discovery. Screens use the real API.

## Events, bookings and drafts

Events support create, read, scheduled-event editing, lifecycle transitions and
confirmed deletion. Bookings match Angular: an all-participant list, event/status
filters, details and cancellation with retained history. The app does not offer
booking creation or hard deletion.

Every tab opening and return from a detail/editor view fetches fresh data. Previous
rows are hidden while opening; a loading indicator is shown without record counts
or an empty-state message. Empty results are shown only after a successful fetch.
Filters stay local to each tab. Load more appends the next 20-item page; explicit
pull-to-refresh replaces rows after success and preserves them on failure.
The booking event selector also loads bounded pages.

Create/edit share a form with client/server validation and local date/time pickers.
Incomplete drafts are saved separately from tokens in device secure storage,
scoped by API origin, issuer, administrator and event. Drafts survive navigation,
reauthentication and app restarts. Successful Save, explicit Discard and explicit
sign-out remove the appropriate drafts. Writes are ordered so queued saves cannot
recreate drafts after logout. No Event/Booking list cache is persisted.

Load errors expose a loading retry. Mutation errors retain the current data and
show their explanation near the actions and in a Snackbar; rejected deletion
does not display a misleading loading-retry button.

## Toolchain and setup

- **Flutter 3.47.4**, pinned in `.flutter-version`, with bundled **Dart 3.13.3**.
- **Riverpod 3.4.3**, **Dio 5.11.1**, **flutter_appauth 12.1.0** and
  **flutter_secure_storage 11.1.1** (exact pins), and a local `arena_api` package
  using **built_value 8.13.0**.
- Android builds require the Android SDK and a compatible JDK. Android minSdk is **24**.
- iOS builds require macOS and Xcode.

Install the pinned Flutter release from the
[Flutter SDK archive](https://docs.flutter.dev/install/archive) and put its `bin`
directory on PATH. Use Flutter's bundled Dart rather than installing a separate
Dart SDK for the application.

From `mobile/`:

```sh
flutter --version
flutter doctor -v
flutter pub get --enforce-lockfile
flutter run
```

The generated serializers are included, so normal application builds do not
require Docker, a generator run, or a running backend.

## Configuration

An explicit `API_BASE_URL` skips discovery entirely:

```sh
flutter run --dart-define=API_BASE_URL=http://localhost:18080
```

Without that define, startup shows “Looking for local API…” while `nsd` **5.0.1**
browses `_arena-api._tcp` for up to three seconds, including native startup and
resolution (`autoResolve: true`, `IpLookupType.any`). The advertisement contract is
`_arena-api._tcp.local.`, a per-host SRV name such as
`arena-api-192-168-20-199.local.`, the backend's port, a real LAN
IPv4 address, and TXT `scheme=http`, `path=/api`, `apiVersion=1`.

Only matching services with valid ports and private/link-local IPv4 addresses
are eligible. Selection is hostname-agnostic and uses the resolved addresses.
The client uses `http://<IPv4>:<port>`;
the generated client already supplies `/api`. This avoids a second `.local`
hostname lookup when making API requests.

Exactly one distinct candidate URL at the deadline is selected. No results,
malformed/foreign advertisements, multiple candidates, permission denial, plugin
failure, or startup timeout fall back to `http://localhost:8080`. Multiple
candidates are reported rather than arbitrarily selected. Account shows the URL,
source (`configured`, `mdns`, or `fallback`) and selection reason. Discovery
listeners detach on completion/disposal and native stop is attempted without
blocking startup; a native start completing late is also stopped.

A discovered URL is a **connection candidate, not an authenticated identity**.
Authentication uses the currently selected endpoint from discovery or configuration.
A restored session must match that exact selected URL before any bearer is sent;
a changed address or port clears auth and requires fresh sign-in.

On a physical phone, `localhost` refers to the phone. iOS declares
`NSLocalNetworkUsageDescription` and `NSBonjourServices`; Android declares Internet
and Wi-Fi multicast permissions. Discovery requires local-network access and
multicast reachability.

## Native authentication

The backend registers public client `arena-mobile`, code + PKCE, callbacks
`com.arena.mobile:/oauth/callback` and `com.arena.mobile:/signed-out`, and scopes
`openid profile api.access`. Access tokens last 15 minutes; the app neither requests
nor persists refresh tokens, passwords or client secrets.

Public metadata is fetched at the selected origin's
`/.well-known/openid-configuration` through a separate Dio without session headers.
The canonical metadata issuer is preserved. The backend defaults to
`http://localhost:8080`; Compose derives the port from `BACKEND_PORT` unless
`AUTH_ISSUER_URI` overrides it.
For **debug local HTTP only**, AppAuth receives explicit service endpoints on the
selected origin: `/oauth2/authorize`, `/oauth2/token`, `/connect/logout`, with
`allowInsecureConnections` enabled. No metadata or JWT claims are rewritten and
backend issuer validation stays enabled. This permits trusted-LAN development;
HTTP does not authenticate the network peer and is unsuitable for untrusted Wi-Fi.

Release/profile reject HTTP before auth or API network use. HTTPS uses normal
AppAuth discovery, without manual overrides or insecure-connection flags. Its
metadata must advertise HTTPS endpoints and a HTTPS issuer.

The returned ID token issuer is compared with the canonical metadata issuer, and
its audience is checked against `arena-mobile`; AppAuth retains its nonce/audience/
expiry validation. ID claims do not supply identity or roles. The exact access token
is sent to `/userinfo`, where the backend must cryptographically validate it and
reject tampered tokens with 401. Only after success does the app decode that token,
require `userinfo.sub == accessToken.sub` and matching issuer, and check its `roles`
list for `ADMIN`. Display name comes from userinfo. USER tokens are cleared and the
UI offers a different-account sign-in using `prompt=login`. Backend authorization
remains authoritative for every API call.

A single encrypted session record stores access token, ID token, expiry, canonical
issuer, selected API origin, subject and display name. Restore revalidates unexpired
sessions through userinfo, never trusts persisted identity alone, and fails closed
on invalid JSON, storage errors, expiry or origin/issuer changes. Per-request token
reads check the bound origin and expiry. Expiry and matching-token API 401 clear
memory and storage, remove all protected routes, and display the sign-in
page. Details and navigation are not visible or reachable with Back. A pending
editor draft is flushed before disposal; reopening the form restores it after
sign-in, but the previous route is not automatically resumed. A late 401 cannot clear
a newer session. Mutations are never automatically retried.

Sign-out saves the ID-token hint, clears local state/storage, then attempts browser
end-session with the registered logout callback. Browser failure or cancellation
does not undo local logout. Owner-scoped draft cleanup runs alongside logout,
with new sign-in disabled until cleanup finishes. If token deletion fails, a
signed-out marker is written; failure of both operations is surfaced explicitly.

Android registers `appAuthRedirectScheme=com.arena.mobile`, disables backups, and
excludes SharedPreferences from cloud backup/device transfer. Main/profile/release
cleartext is disabled; only the debug manifest enables local HTTP development
(the Dart boundary restricts it to local addresses). iOS registers the callback
scheme and Keychain entitlements for all Runner configurations, with this-device-only
unlocked Keychain accessibility. No global ATS bypass is enabled; the iOS project
does not configure LAN HTTP exceptions. Use HTTPS for iOS authentication.

Android uses the default task affinity for AppAuth browser callbacks.

### Android device setup

Install `build/app/outputs/flutter-apk/app-debug.apk` with ADB and launch on the
same trusted LAN as the backend advertisement. With no `API_BASE_URL`, confirm
the displayed discovered endpoint before sign-in. A configured URL may also be
provided with `--dart-define=API_BASE_URL=<current-origin>`; localhost fallback is
not a reachable backend on a physical phone without explicit forwarding.

Check ADMIN browser sign-in/callback, Account name and endpoint, USER rejection
and different-account sign-in, cancellation, restart restore, 15-minute expiry,
endpoint-address changes, and sign-out callback. For Event and Booking workflows,
check create/edit/lifecycle/delete, cross-user booking cancellation, retained
history, draft restoration after app restart, and the API-401 transition to the
sign-in page.

## Structure and state

```text
lib/
  main.dart                ProviderScope and application entry point
  app.dart                 Material theme and two-tab shell
  core/
    app_providers.dart     Endpoint-bound auth and API dependency ownership
    auth.dart              AppAuth/storage interfaces, session and verification
    event_drafts.dart      Owner-scoped persistent drafts and ordered cleanup
    api_discovery.dart     Bounded native NSD adapter and endpoint selection
    api/                   HTTP boundary and presentation-safe errors
  features/
    events/                Event list, details, shared editor and validation
    bookings/              Booking list, details and bounded event picker
  shared/                  Paging, feedback, confirmation and title widgets
packages/arena_api/        Generated models/client and authored contract tests
test/                      Widget and API-boundary tests
scripts/generate-api.sh    Pinned generation and package verification
```

Tab selection belongs to the shell; an `IndexedStack` retains tab/filter widgets,
but activation always fetches fresh rows. Riverpod owns global authentication and
closes the API client's Dio when its provider is disposed. Platform auth, storage and userinfo/metadata adapters
are injectable for tests. Event/Booking data and forms remain local to features.

`ApiBoundaryInterceptor` attaches a callback-provided token only to the configured
API origin/path and disables redirects for those requests. It checks that
successful Event/Booking list responses contain an `items` list before generated
deserialization. Detail/write responses and bodyless 204 responses are unaffected.

`describeApiError` maps network and HTTP failures to safe messages, retaining
Problem Details field errors without retaining raw requests, tokens or server
exceptions. The generated `ProblemDetail` model drops the custom `errors`
extension, so the application reads that extension from the raw response.
There are no automatic mutation retries or request-logging interceptors.

## Generated API workflow

The canonical snapshot is `../web/contracts/openapi.json`, shared with
Angular. To refresh it from a running backend, use the web project's documented
`update:api` command first.

From the repository root, with Docker available:

```sh
bash mobile/scripts/generate-api.sh
bash mobile/scripts/generate-api.sh check
```

Generation uses digest-pinned OpenAPI Generator **7.25.0**, `dart-dio` and
`built_value`. Its verification uses a pinned Dart container. It generates only
the Events/Bookings API classes, builds serializers, checks analysis and runs
contract tests. Tests and lockfiles survive regeneration. Do not hand-edit
generated sources. See [API package development](packages/arena_api/FOUNDATION.md).

Generated-package analysis allows visible warnings while retaining fatal errors.
The application's strict analyzer excludes that package, which has its own
analysis and contract-test commands.
The handwritten API boundary rejects malformed collection envelopes before
generated deserialization.

## Verify

From `mobile/`:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.
Widget tests cover tab navigation, Account dismissal, and 375px layouts at normal
and doubled text scale. API tests use HTTP adapter stubs with the actual generated
client to verify malformed pages, bearer scoping, error masking, field errors and
Riverpod overrides. Startup tests cover explicit override bypass, discovery,
malformed/foreign results, ambiguity, timeout, plugin failures, listener cleanup,
late native startup, disposal, and origin-bound sessions for discovered endpoints.
Auth tests cover sign-in, USER rejection, issuer/audience/subject mismatch, native
errors/cancellation, secure-storage failures, restoration, expiry, stale 401s,
logout failure, HTTPS discovery and HTTP release/profile rejection. Widget tests
cover sign-in loading, account/logout and removal of protected routes on expiry.
Platform calls are replaced by injected fakes in tests. The package's separate
contract tests cover serialization, pagination, write requests and 204/error
responses. Live mobile OIDC and physical-device networking require device testing.
