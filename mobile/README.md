# Arena mobile

Flutter foundation for the Android/iOS administration app.

Implemented: Events/Bookings tabs, retained tab widgets, account placeholder,
Riverpod dependency wiring, generated API client, scoped bearer-token attachment,
page-response validation, and shared API errors. The shell makes no network
requests and contains no sample records.

Mobile OIDC, secure token storage, CRUD screens, Load more, filters and persistent
drafts are subsequent milestones. The Account action currently explains that
sign-in is not configured.

## Toolchain and setup

- **Flutter 3.47.4**, pinned in `.flutter-version`, with bundled **Dart 3.13.3**.
- **Riverpod 3.4.3**, **Dio 5.11.1**, and a local `arena_api` package using
  **built_value 8.13.0**. Dependency lockfiles are committed.
- Android: Android SDK and a compatible JDK; verified here with SDK platform 36,
  build-tools 36.0.0 and JDK 21.
- iOS: macOS and Xcode. iOS platform files are included, but builds cannot be
  verified on Linux.

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

The generated serializers are committed, so normal application builds do not
require Docker, a generator run, or a running backend.

## Configuration

The API origin comes from `API_BASE_URL`, defaulting to `http://localhost:8080`:

```sh
flutter run --dart-define=API_BASE_URL=http://localhost:18080
```

This example addresses a backend on the same host. On a physical phone,
`localhost` refers to the phone. Device-reachable HTTPS and native OIDC callback
configuration will be added with authentication; the foundation does not enable
cleartext exceptions or embed credentials. The shell can be tested without API
connectivity.

## Structure and state

```text
lib/
  main.dart                ProviderScope and application entry point
  app.dart                 Material theme and two-tab shell
  core/
    app_providers.dart     API configuration, token seam and client ownership
    api/                   HTTP boundary and presentation-safe errors
  features/
    events/                Events screen
    bookings/              Bookings screen
packages/arena_api/        Generated models/client and authored contract tests
test/                      Widget and API-boundary tests
scripts/generate-api.sh    Pinned generation and package verification
```

Tab selection belongs to the shell; an `IndexedStack` retains each tab's widget
state. Riverpod supplies shared dependencies and closes the API client's Dio when
its provider is disposed. `accessTokenProvider` currently returns null and is the
integration point for the future authentication session. Authentication will be
the only shared application state; Event/Booking data and forms remain local to
their features.

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

The canonical snapshot is currently `../web/contracts/openapi.json`, shared with
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
generated sources. See [API package handoff](packages/arena_api/FOUNDATION.md).

Generated-package analysis allows visible warnings while retaining fatal errors;
the generator currently emits two unused-import warnings. The application's
strict analyzer excludes that package, which has its own verification gate.
The four malformed-page cases found during the trial are rejected by the
handwritten API boundary rather than by patched generated code.

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
Riverpod overrides. The package's separate contract tests cover serialization,
pagination, write requests and 204/error responses. These tests do not claim to
verify live mobile OIDC or physical-device networking.
