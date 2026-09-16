# Arena API package

## Source and ownership

Generated from `../../../web/contracts/openapi.json`, the same canonical OpenAPI
3.1 snapshot used by Angular. There is no separate mobile specification or
conversion step. The backend explicitly documents its Location headers as URI
strings so the generator can process them.

`lib/`, `doc/`, `README.md`, `pubspec.yaml`, `analysis_options.yaml`, and
`.openapi-generator/` are generator-owned. Do not edit them manually.
`test/contract_test.dart`, this document, `.gitignore`, and
`.openapi-generator-ignore` are authored and preserved across regeneration.
The lockfile pins package dependencies, and generated `.g.dart` serializers are
included for app consumption.

## Reproduce and verify

From the repository root:

```sh
bash mobile/scripts/generate-api.sh
bash mobile/scripts/generate-api.sh check
```

Only Docker and Bash are required for this workflow. `generate-api.sh` pins the
official OpenAPI Generator **7.25.0** and Dart **3.13.4** images by digest. Settings
are `dart-dio`, `pubName=arena_api`, `serializationLibrary=built_value`, and
`dateLibrary=core`. Only Events/Bookings API classes are generated; all models
remain available, including `ProblemDetail`. Empty generated test stubs are
disabled and excluded.

Generation removes only the old generator-owned `lib`, `doc` and metadata
directories. It preserves authored tests and the dependency lockfile, resolves
with `--enforce-lockfile`, builds serializers, normalizes generated whitespace,
then runs analysis and contract tests. The normalization step changes no model
behavior or validation.

The disposable pub cache defaults to `.dart-tool/docker-pub-cache`;
`ARENA_PUB_CACHE` can select another absolute path. With images and dependencies
cached, `ARENA_PUB_OFFLINE=1` enables offline package resolution. To intentionally
update dependencies, remove the package lockfile, regenerate, and review the diff.

## Application integration

The mobile app consumes this package through a path dependency. Its own lockfile
governs app dependency resolution; this package's lock governs isolated generator
checks.

Use the mobile application's `arenaApiProvider`. It configures the API origin,
shared response guard and callback-based bearer handling, and owns Dio disposal.
The bearer callback reads `authProvider.notifier.tokenFor(origin)`; matching-token
401 responses invalidate the session through the same controller.
Generated client methods are used directly, without one-to-one repository wrappers.

- Events: `list`, `callGet`, `create`, `update`, `changeStatus`, `delete`.
- Bookings: `list1`, `get1`, `create1`, `cancel`.
- Models use built_value builders, e.g.
  `BookingRequest((b) => b.eventId = eventId)`.
- Dates are `DateTime`; page items are `BuiltList<T>`.
- Model statuses are generated enums; status query arguments are strings.
- Response descriptions accept absent/null/string. Null optional request
  descriptions are omitted during serialization.

The default `standardSerializers` handles JSON conversion. Dio preserves failed
HTTP responses in `DioException.response.data`; it does not decode these through
the endpoint's success model. Preserve success-status validation rather than
broadly accepting errors using `validateStatus`.

Generated `ProblemDetail` decoding is available, but drops the top-level custom
`errors` extension. The app's `describeApiError` reads the raw extension and maps
it to immutable field errors with safe fallback messages.

Missing/null required page `items` becomes an empty list in generated code. The
application rejects malformed collection envelopes before generated decoding;
this package is not a complete JSON Schema validator.

## Verification policy

Contract tests use actual generated APIs and Dio with an HTTP adapter
stub. They cover nullable descriptions, nested pages, enums/dates, pagination,
write requests, Location headers, bodyless 204 and HTTP 400/401/409 responses.

`dart analyze --no-fatal-warnings` allows generated warnings while keeping
analyzer errors fatal. Authored tests are explicitly analyzed strictly because
generated analysis settings exclude them. The mobile
application also has strict analysis and tests for its handwritten boundaries.
The generator labels its general OpenAPI 3.1 support beta; generation uses the
shared contract without a compatibility conversion.
