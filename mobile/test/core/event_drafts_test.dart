import 'package:arena_mobile/core/auth.dart';
import 'package:arena_mobile/core/event_drafts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('owner identity includes origin issuer and subject, with safe keys', () {
    AuthSession session(String origin, String issuer, String sub) =>
        AuthSession(
          accessToken: '',
          idToken: '',
          issuer: issuer,
          origin: origin,
          sub: sub,
          name: '',
          expiry: DateTime(2100),
        );
    final owner = draftOwner(session('https://a', 'https://issuer', 'user/1'));
    expect(owner, matches(RegExp(r'^[A-Za-z0-9_=-]+$')));
    expect(
      owner,
      isNot(draftOwner(session('https://b', 'https://issuer', 'user/1'))),
    );
    expect(
      owner,
      isNot(draftOwner(session('https://a', 'https://other', 'user/1'))),
    );
    expect(
      owner,
      isNot(draftOwner(session('https://a', 'https://issuer', 'user/2'))),
    );
  });
  test(
    'drafts persist across store instances and isolate owner and event',
    () async {
      final store = NativeEventDraftStore();
      await store.write('a', 'new', {'title': 'unfinished', 'capacity': 'abc'});
      await store.write('b', 'new', {'title': 'other'});
      await store.write('a', 'event', {'title': 'existing'});
      final restarted = NativeEventDraftStore();
      expect((await restarted.read('a', 'new'))!['capacity'], 'abc');
      await restarted.remove('a', 'new');
      expect(await store.read('a', 'new'), isNull);
      expect((await store.read('a', 'event'))!['title'], 'existing');
      expect((await store.read('b', 'new'))!['title'], 'other');
    },
  );
  test(
    'save/discard deletes after queued writes and logout rejects stale writes',
    () async {
      final store = NativeEventDraftStore();
      final pending = store.write('a', 'new', {'title': 'pending'});
      final deletion = store.remove('a', 'new');
      await Future.wait([pending, deletion]);
      expect(await store.read('a', 'new'), isNull);
      await store.write('b', 'new', {'title': 'keep'});
      final beforeLogout = store.write('a', 'event', {'title': 'pending'});
      final logout = store.removeOwner('a');
      await store.write('a', 'new', {'title': 'stale editor'});
      await Future.wait([beforeLogout, logout]);
      expect(await store.read('a', 'new'), isNull);
      expect(await store.read('a', 'event'), isNull);
      expect((await store.read('b', 'new'))!['title'], 'keep');
    },
  );
  test('invalid version shape keys and oversized values are rejected', () {
    expect(
      NativeEventDraftStore.validate({'version': 2, 'values': {}}),
      isNull,
    );
    expect(
      NativeEventDraftStore.validate({
        'version': 1,
        'values': {'token': 'secret'},
      }),
      isNull,
    );
    expect(
      NativeEventDraftStore.validate({
        'version': 1,
        'values': {'title': 1},
      }),
      isNull,
    );
    expect(
      NativeEventDraftStore.validate({
        'version': 1,
        'values': {'description': 'x' * 10001},
      }),
      isNull,
    );
  });
}
