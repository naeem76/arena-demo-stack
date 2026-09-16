import 'package:arena_api/arena_api.dart';
import 'package:arena_mobile/core/app_providers.dart';
import 'package:arena_mobile/features/events/events_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_api_test.dart' show TestAuth;

void main() {
  testWidgets(
    '375px at 2x text remains scrollable with keyboard and disables expired Create',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'items': [],
                  'page': 0,
                  'size': 20,
                  'totalElements': 0,
                  'totalPages': 0,
                },
              ),
            );
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(TestAuth.new),
          apiBaseUrlProvider.overrideWithValue('https://api.test'),
          arenaApiProvider.overrideWithValue(ArenaApi(dio: dio)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('Events')),
              body: const EventsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
            .onPressed,
        isNotNull,
      );
      final statusBounds = tester.getRect(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(statusBounds.left, greaterThanOrEqualTo(16));
      expect(
        statusBounds.right,
        lessThanOrEqualTo(
          tester.view.physicalSize.width / tester.view.devicePixelRatio - 16,
        ),
      );
      await tester.enterText(find.byType(TextField), 'Tennis');
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Apply'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['sport'], 'Tennis');
      await tester.scrollUntilVisible(
        find.text('No events found.'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No events found.').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      (container.read(authProvider.notifier) as TestAuth).expire();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Create'),
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
