import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth.dart';

String draftOwner(AuthSession session) => base64Url.encode(
  utf8.encode(jsonEncode([session.origin, session.issuer, session.sub])),
);

abstract interface class EventDraftStore {
  Future<Map<String, dynamic>?> read(String owner, String eventKey);
  Future<void> write(
    String owner,
    String eventKey,
    Map<String, dynamic> values,
  );
  Future<void> remove(String owner, String eventKey);
  Future<void> removeOwner(String owner);
}

final eventDraftStoreProvider = Provider<EventDraftStore>(
  (ref) => NativeEventDraftStore(),
);

class NativeEventDraftStore implements EventDraftStore {
  NativeEventDraftStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'arena.mobile.drafts'),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );
  final FlutterSecureStorage _storage;
  Future<void> _tail = Future.value();
  final Map<String, int> _epochs = {};
  final Set<String> _revoked = {};
  static const _fields = {
    'title',
    'sport',
    'location',
    'description',
    'capacity',
    'startsAt',
    'endsAt',
  };
  String _prefix(String owner) => 'arena.mobile.drafts.v1.$owner.';
  String _key(String owner, String eventKey) =>
      '${_prefix(owner)}${base64Url.encode(utf8.encode(eventKey))}';
  Future<T> _ordered<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static Map<String, dynamic>? validate(Object? value) {
    if (value is! Map || value['version'] != 1 || value['values'] is! Map) {
      return null;
    }
    final values = value['values'] as Map;
    if (values.length > _fields.length) return null;
    for (final entry in values.entries) {
      if (!_fields.contains(entry.key) ||
          entry.value is! String ||
          (entry.value as String).length > 10000) {
        return null;
      }
    }
    return Map<String, dynamic>.from(values);
  }

  @override
  Future<Map<String, dynamic>?> read(String owner, String eventKey) {
    _revoked.remove(owner);
    return _ordered(() async {
      final raw = await _storage.read(key: _key(owner, eventKey));
      if (raw == null || raw.length > 80000) return null;
      try {
        return validate(jsonDecode(raw));
      } on FormatException {
        return null;
      }
    });
  }

  @override
  Future<void> write(
    String owner,
    String eventKey,
    Map<String, dynamic> values,
  ) {
    final epoch = _epochs[owner] ?? 0;
    final snapshot = validate({'version': 1, 'values': values});
    if (snapshot == null) {
      return Future.error(ArgumentError('Invalid event draft'));
    }
    if (_revoked.contains(owner)) return Future.value();
    return _ordered(() async {
      if (_revoked.contains(owner) || epoch != (_epochs[owner] ?? 0)) return;
      await _storage.write(
        key: _key(owner, eventKey),
        value: jsonEncode({'version': 1, 'values': snapshot}),
      );
    });
  }

  @override
  Future<void> remove(String owner, String eventKey) =>
      _ordered(() => _storage.delete(key: _key(owner, eventKey)));
  @override
  Future<void> removeOwner(String owner) {
    _epochs[owner] = (_epochs[owner] ?? 0) + 1;
    _revoked.add(owner);
    return _ordered(() async {
      final all = await _storage.readAll();
      for (final key in all.keys.where(
        (key) => key.startsWith(_prefix(owner)),
      )) {
        await _storage.delete(key: key);
      }
    });
  }
}
