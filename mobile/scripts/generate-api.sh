#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PACKAGE="$ROOT/mobile/packages/arena_api"
SPEC="$ROOT/web/contracts/openapi.json"
GENERATOR='openapitools/openapi-generator-cli:v7.25.0@sha256:2ab0a9680222de65dc9d3baf861aa02b99e1b80c211d8221ebf3ae8f8a102524'
DART='dart@sha256:41a3389cce686a3a76e9c5fcd098b26fcc4b88eff601a9e767183cf7cdb8f392'
MODE="${1:-generate}"
case "$MODE" in generate|check) ;; *) printf 'Usage: %s [generate|check]\n' "$0" >&2; exit 2 ;; esac

# Cache is disposable, isolated from the app, and can reuse an existing Docker cache.
CACHE="${ARENA_PUB_CACHE:-$PACKAGE/.dart-tool/docker-pub-cache}"
mkdir -p "$CACHE"
sdk() {
  docker run --rm --user "$(id -u):$(id -g)" \
    -e HOME=/tmp -e PUB_CACHE=/pub-cache \
    -v "$PACKAGE:/package" -v "$CACHE:/pub-cache" \
    -v "$ROOT/mobile/scripts:/scripts:ro" \
    -v "$SPEC:/input/openapi.json:ro" -w /package "$DART" dart "$@"
}

if [[ "$MODE" == generate ]]; then
  # These directories are exclusively generator-owned. Tests, lockfile and
  # FOUNDATION.md survive; removed operations/models cannot leave stale sources.
  rm -rf "$PACKAGE/lib" "$PACKAGE/doc" "$PACKAGE/.openapi-generator"
  docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$PACKAGE:/package" -v "$SPEC:/input/openapi.json:ro" \
    "$GENERATOR" generate -i /input/openapi.json -g dart-dio -o /package \
    --additional-properties=pubName=arena_api,serializationLibrary=built_value,dateLibrary=core \
    --global-property 'apis=Events:Bookings,models,supportingFiles,apiTests=false,modelTests=false,apiDocs=true,modelDocs=true' \
    --ignore-file-override /package/.openapi-generator-ignore
fi

# Keep dependency versions and content hashes fixed after the first resolution.
PUB_ARGS=()
[[ ! -f "$PACKAGE/pubspec.lock" ]] || PUB_ARGS+=(--enforce-lockfile)
[[ "${ARENA_PUB_OFFLINE:-0}" != 1 ]] || PUB_ARGS+=(--offline)
sdk pub get "${PUB_ARGS[@]}"
sdk run build_runner build
sdk run /scripts/normalize_generated.dart
sdk analyze --no-fatal-warnings
# The generated analysis_options excludes tests; explicitly analyze authored code.
sdk analyze test/contract_test.dart
sdk test test/contract_test.dart --reporter expanded
