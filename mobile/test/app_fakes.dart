import 'dart:async';

import 'package:arena_api/arena_api.dart';
import 'package:arena_mobile/core/event_drafts.dart';

import 'features/bookings/booking_fakes.dart';

ArenaApi emptyAppApi() {
  final api = ArenaApi();
  api.dio.httpClientAdapter = BookingAdapter(
    (_) => BookingAdapter.json(pageJson([], totalPages: 0)),
  );
  return api;
}

class MemoryEventDraftStore implements EventDraftStore {
  final values = <String, Map<String, Map<String, dynamic>>>{};
  final removedOwners = <String>[];
  Completer<void>? removeGate;

  @override
  Future<Map<String, dynamic>?> read(String owner, String eventKey) async =>
      values[owner]?[eventKey];

  @override
  Future<void> write(
    String owner,
    String eventKey,
    Map<String, dynamic> draft,
  ) async {
    (values[owner] ??= {})[eventKey] = Map.of(draft);
  }

  @override
  Future<void> remove(String owner, String eventKey) async {
    values[owner]?.remove(eventKey);
  }

  @override
  Future<void> removeOwner(String owner) async {
    removedOwners.add(owner);
    await removeGate?.future;
    values.remove(owner);
  }
}
