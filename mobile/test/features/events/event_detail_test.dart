import 'package:arena_api/arena_api.dart';
import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/features/events/event_detail_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_api_test.dart' show TestAuth, eventJson;

void main() {
  testWidgets('retry is offered for an actual detail-loading failure', (
    tester,
  ) async {
    var reads = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          expect(request.method, 'GET');
          if (++reads == 1) {
            handler.reject(
              DioException(
                requestOptions: request,
                response: Response(requestOptions: request, statusCode: 503),
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: eventJson('1'),
              ),
            );
          }
        },
      ),
    );
    final api = ArenaApi(dio: dio);
    addTearDown(() => dio.close(force: true));
    final event = api.serializers.deserializeWith(
      EventResponse.serializer,
      eventJson('1'),
    )!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(TestAuth.new),
          apiBaseUrlProvider.overrideWithValue('https://api.test'),
          arenaApiProvider.overrideWithValue(api),
        ],
        child: MaterialApp(home: EventDetailScreen(event: event)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load event'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Unable to load event'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
    'back is blocked during mutation and returns changed after completion',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      RequestInterceptorHandler? pending;
      RequestOptions? mutation;
      bool? changed;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.method == 'GET') {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: eventJson('1'),
                ),
              );
            } else {
              pending = handler;
              mutation = request;
            }
          },
        ),
      );
      final api = ArenaApi(dio: dio);
      final event = api.serializers.deserializeWith(
        EventResponse.serializer,
        eventJson('1'),
      )!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(TestAuth.new),
            apiBaseUrlProvider.overrideWithValue('https://api.test'),
            arenaApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventDetailScreen(event: event),
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
      await tester.tap(find.text('Change to LIVE'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Change status'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(pending, isNotNull);
      await tester.pageBack();
      await tester.pump();
      expect(find.text('Event 1'), findsOneWidget);
      expect(changed, isNull);
      pending!.resolve(
        Response(
          requestOptions: mutation!,
          statusCode: 200,
          data: eventJson('1')..['status'] = 'LIVE',
        ),
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(changed, isTrue);
      expect(find.text('Open'), findsOneWidget);
    },
  );
  for (final expire in [false, true]) {
    testWidgets(
      expire
          ? 'session expiry during confirmation blocks delete'
          : 'delete history conflict retains event and reports safe error',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var deletes = 0;
        final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              if (request.method == 'GET') {
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: 200,
                    data: eventJson('1'),
                  ),
                );
              } else {
                deletes++;
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: request,
                      statusCode: 409,
                      data: {'detail': 'Event has booking history'},
                    ),
                  ),
                );
              }
            },
          ),
        );
        final api = ArenaApi(dio: dio);
        final event = api.serializers.deserializeWith(
          EventResponse.serializer,
          eventJson('1'),
        )!;
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(TestAuth.new),
            apiBaseUrlProvider.overrideWithValue('https://api.test'),
            arenaApiProvider.overrideWithValue(api),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: EventDetailScreen(event: event)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete event'));
        await tester.pumpAndSettle();
        if (expire) {
          (container.read(authProvider.notifier) as TestAuth).expire();
        }
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();
        expect(deletes, expire ? 0 : 1);
        expect(find.text('Event 1'), findsOneWidget);
        expect(
          find.text(
            expire ? 'Sign in again to continue.' : 'Event has booking history',
          ),
          findsWidgets,
        );
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Retry loading'), findsNothing);
        expect(find.text('Unable to load event'), findsNothing);
      },
    );
  }
  testWidgets(
    'scheduled live completed transitions expose only allowed controls',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var status = 'SCHEDULED';
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.method != 'GET') {
              expect(request.path, '/api/events/1/status');
              status = (request.data as Map)['status'] as String;
            }
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: eventJson('1')..['status'] = status,
              ),
            );
          },
        ),
      );
      final api = ArenaApi(dio: dio);
      final event = api.serializers.deserializeWith(
        EventResponse.serializer,
        eventJson('1'),
      )!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(TestAuth.new),
            apiBaseUrlProvider.overrideWithValue('https://api.test'),
            arenaApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(home: EventDetailScreen(event: event)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      for (final next in ['LIVE', 'COMPLETED']) {
        await tester.tap(find.text('Change to $next'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Change status'));
        await tester.pumpAndSettle();
        expect(status, next);
        expect(find.text('Edit'), findsNothing);
      }
      expect(find.text('Change to CANCELLED'), findsNothing);
      expect(find.text('Change to LIVE'), findsNothing);
    },
  );
}
