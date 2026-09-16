import 'dart:async';

import 'package:arena_api/arena_api.dart';
import 'package:arena_mobile/app.dart';
import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/core/event_drafts.dart';
import 'package:arena_mobile/features/bookings/bookings_screen.dart';
import 'package:arena_mobile/features/events/events_screen.dart';
import 'package:arena_mobile/features/events/event_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_fakes.dart';
import 'auth_fakes.dart';

void main() {
  late ArenaApi api;
  late MemoryEventDraftStore drafts;
  late MemoryStorage storage;
  setUp(() {
    api = emptyAppApi();
    drafts = MemoryEventDraftStore();
    storage = MemoryStorage();
  });
  tearDown(() => api.dio.close(force: true));

  Future<ProviderContainer> pumpAuth(
    WidgetTester tester,
    FakeAuthPlatform platform,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configuredApiUrlProvider.overrideWithValue(testOrigin),
          arenaApiProvider.overrideWithValue(api),
          eventDraftStoreProvider.overrideWithValue(drafts),
          authPlatformProvider.overrideWithValue(platform),
          sessionStorageProvider.overrideWithValue(storage),
          authServerProvider.overrideWithValue(FakeAuthServer()),
        ],
        child: const ArenaApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(ArenaApp)),
      listen: false,
    );
  }

  testWidgets(
    'sign-in gate loads, signs in, and logout removes only the owner drafts',
    (tester) async {
      final platform = FakeAuthPlatform()..gate = Completer<void>();
      final scope = await pumpAuth(tester, platform);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      platform.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(EventsScreen), findsOneWidget);
      final owner = draftOwner(scope.read(authProvider).session!);
      await drafts.write(owner, 'new', {'title': 'Unsaved'});
      await drafts.write('another-owner', 'new', {'title': 'Private'});
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Arena Administrator'), findsOneWidget);
      expect(find.text(testOrigin), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(storage.value, isNull);
      expect(drafts.removedOwners, [owner]);
      expect(await drafts.read(owner, 'new'), isNull);
      expect(await drafts.read('another-owner', 'new'), isNotNull);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Sign in with a different account'), findsOneWidget);
    },
  );

  testWidgets(
    'expiry replaces protected navigation with the existing sign-in page',
    (tester) async {
      final platform = FakeAuthPlatform()
        ..expiry = DateTime.now().add(const Duration(seconds: 3));
      await pumpAuth(tester, platform);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Bookings'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(IndexedStack), findsNothing);
      expect(find.byType(BookingsScreen), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Sign in again'), findsOneWidget);
      expect(find.text('Session ended. Sign in again.'), findsOneWidget);
    },
  );

  testWidgets(
    'expiry removes pushed editors and flushes the draft before disposal',
    (tester) async {
      final scope = await pumpAuth(tester, FakeAuthPlatform());
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      final owner = draftOwner(scope.read(authProvider).session!);
      unawaited(
        Navigator.of(tester.element(find.byType(EventsScreen))).push<bool>(
          MaterialPageRoute(builder: (_) => const EventFormScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Retained form text',
      );
      final auth = scope.read(authProvider.notifier);
      await auth.invalidate(
        token: scope.read(authProvider).session!.accessToken,
      );
      await tester.pumpAndSettle();
      expect(find.byType(EventFormScreen), findsNothing);
      expect(find.text('Retained form text'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Sign in again'), findsOneWidget);
      expect((await drafts.read(owner, 'new'))?['title'], 'Retained form text');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(EventFormScreen), findsNothing);
      expect(find.text('Sign in again'), findsOneWidget);
    },
  );

  testWidgets('logout clears authority while draft cleanup is pending', (
    tester,
  ) async {
    final scope = await pumpAuth(tester, FakeAuthPlatform());
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    drafts.removeGate = Completer<void>();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(scope.read(authProvider).session, isNull);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    drafts.removeGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Sign in with a different account'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('USER remains outside the shell', (tester) async {
    await pumpAuth(tester, FakeAuthPlatform()..roles = ['USER']);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Sign in with a different account'), findsOneWidget);
  });
}
