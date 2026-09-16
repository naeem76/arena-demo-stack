import 'package:arena_api/arena_api.dart';
import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/core/auth.dart';
import 'package:arena_mobile/core/event_drafts.dart';
import 'package:arena_mobile/features/events/event_form.dart';
import 'package:arena_mobile/features/events/events_screen.dart';
import 'package:arena_mobile/shared/paged_list.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TestAuth extends AuthController {
  TestAuth() : super.bound();
  @override
  AuthState build() => AuthState(
    session: AuthSession(
      accessToken: 'token',
      idToken: '',
      issuer: 'https://issuer',
      origin: 'https://api.test',
      sub: 'admin',
      name: 'Admin',
      expiry: DateTime(2100),
    ),
  );
  @override
  String? tokenFor(String origin) => state.session?.accessToken;
  void expire() => state = const AuthState(hasSignedIn: true);
}

class MemoryDrafts implements EventDraftStore {
  Map<String, dynamic>? values = {
    'title': 'Draft event',
    'sport': 'Tennis',
    'location': 'Court',
    'description': '',
    'capacity': '20',
    'startsAt': '2099-01-01T10:00:00Z',
    'endsAt': '2099-01-01T11:00:00Z',
  };
  @override
  Future<Map<String, dynamic>?> read(String owner, String eventKey) async =>
      values;
  @override
  Future<void> write(
    String owner,
    String eventKey,
    Map<String, dynamic> values,
  ) async {
    this.values = Map.of(values);
  }

  @override
  Future<void> remove(String owner, String eventKey) async {
    values = null;
  }

  @override
  Future<void> removeOwner(String owner) async {
    values = null;
  }
}

Map<String, dynamic> eventJson(String id) => {
  'id': id,
  'title': 'Event $id',
  'sport': 'Tennis',
  'location': 'Court',
  'capacity': 20,
  'status': 'SCHEDULED',
  'startsAt': '2099-01-01T10:00:00Z',
  'endsAt': '2099-01-01T11:00:00Z',
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
};

void main() {
  for (final action in ['Save', 'Discard']) {
    testWidgets('$action removes draft and returns route mutation result', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final drafts = MemoryDrafts();
      var calls = 0;
      bool? changed;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            calls++;
            expect(request.method, 'POST');
            expect(request.path, '/api/events');
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 201,
                data: eventJson('new-id'),
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(TestAuth.new),
            apiBaseUrlProvider.overrideWithValue('https://api.test'),
            arenaApiProvider.overrideWithValue(ArenaApi(dio: dio)),
            eventDraftStoreProvider.overrideWithValue(drafts),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EventFormScreen(),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      if (action == 'Discard') {
        await tester.tap(find.widgetWithText(FilledButton, 'Discard').last);
        await tester.pumpAndSettle();
      }
      expect(drafts.values, isNull);
      expect(changed, action == 'Save');
      expect(calls, action == 'Save' ? 1 : 0);
      expect(find.text('Open'), findsOneWidget);
    });
  }
  test('generated list uses 20 rows, appends and preserves previous rows on failure', () async {
    var fail = false;
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          if (fail) {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          final page = request.queryParameters['page'] as int;
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'items': [eventJson('$page')],
                'page': page,
                'size': 20,
                'totalElements': 2,
                'totalPages': 2,
              },
            ),
          );
        },
      ),
    );
    final provider =
        NotifierProvider.autoDispose<
          EventsController,
          PagedListState<EventResponse>
        >(EventsController.new);
    final container = ProviderContainer(
      overrides: [arenaApiProvider.overrideWithValue(ArenaApi(dio: dio))],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final controller = container.read(provider.notifier);
    await controller.refresh();
    await controller.loadMore();
    expect(requests.map((r) => r.queryParameters['size']), [20, 20]);
    expect(container.read(provider).items.map((e) => e.id), ['0', '1']);
    fail = true;
    await controller.refresh();
    expect(container.read(provider).items.length, 2);
    expect(container.read(provider).error, isNotNull);
    fail = false;
    await controller.filter(' TeNnIs ', 'LIVE');
    expect(requests.last.queryParameters['sport'], 'TeNnIs');
    expect(requests.last.queryParameters['status'], 'LIVE');
    expect(container.read(provider).items.length, 1);
  });

  for (final status in [400, 409, 401, 0]) {
    testWidgets('save failure $status retains draft and input', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final drafts = MemoryDrafts();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            calls++;
            handler.reject(
              DioException(
                requestOptions: request,
                type: status == 0
                    ? DioExceptionType.connectionError
                    : DioExceptionType.badResponse,
                response: status == 0
                    ? null
                    : Response(
                        requestOptions: request,
                        statusCode: status,
                        data: {
                          'detail': 'Cannot save event',
                          'errors': [
                            {
                              'field': 'title',
                              'message': 'Server title violation',
                            },
                          ],
                        },
                      ),
              ),
            );
          },
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(TestAuth.new),
            apiBaseUrlProvider.overrideWithValue('https://api.test'),
            arenaApiProvider.overrideWithValue(ArenaApi(dio: dio)),
            eventDraftStoreProvider.overrideWithValue(drafts),
          ],
          child: const MaterialApp(home: EventFormScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(drafts.values!['title'], 'Draft event');
      final title = tester.widgetList<TextField>(find.byType(TextField)).first;
      expect(title.controller!.text, 'Draft event');
      if (status == 400 || status == 409) {
        expect(title.decoration!.errorText, 'Server title violation');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('expired session blocks save at click time', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(TestAuth.new),
        apiBaseUrlProvider.overrideWithValue('https://api.test'),
        eventDraftStoreProvider.overrideWithValue(MemoryDrafts()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EventFormScreen()),
      ),
    );
    await tester.pumpAndSettle();
    (container.read(authProvider.notifier) as TestAuth).expire();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Sign in again with the same account to continue.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
