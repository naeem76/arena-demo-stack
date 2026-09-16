import 'package:arena_mobile/shared/confirm_action.dart';
import 'package:arena_mobile/shared/feedback_panel.dart';
import 'package:arena_mobile/shared/paged_list.dart';
import 'package:arena_mobile/shared/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('footer bounds load more, busy, retry and count states', (
    tester,
  ) async {
    var loads = 0;
    var retries = 0;
    Future<void> render(PagedListState<String> state) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedListFooter(
            state: state,
            onLoadMore: () => loads++,
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    await render(PagedListState());
    expect(find.text('0 of 0 items'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
    await render(PagedListState(items: ['a'], totalElements: 2, totalPages: 2));
    expect(find.text('1 of 2 items'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    expect(loads, 1);
    for (final state in [
      PagedListState<String>(loading: true),
      PagedListState<String>(refreshing: true),
      PagedListState<String>(loadingMore: true),
    ]) {
      await render(state);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    }
    await render(PagedListState(totalPages: 2, error: 'Please try again'));
    expect(find.text('Please try again'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
    await render(PagedListState(page: 1, totalPages: 2));
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('feedback announces errors and disables retry while loading', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackPanel(
          title: 'Unable to load',
          message: 'Try again',
          onRetry: () {},
        ),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackPanel(
          title: 'Loading items',
          loading: true,
          onRetry: () {},
        ),
      ),
    );
    expect(find.text('Retry'), findsNothing);
    expect(find.bySemanticsLabel('Loading items\nLoading'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('footer wraps long feedback at narrow width and large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: PagedListFooter<String>(
                state: PagedListState(
                  error: 'We could not reach the API. Check your connection and try again.',
                ),
                onLoadMore: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmation returns true only on confirm', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await confirmAction(
                context,
                title: 'Delete event?',
                message: 'This removes the event.',
                confirmLabel: 'Delete',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    for (final action in ['Cancel', 'Delete', 'dismiss']) {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('This removes the event.'), findsOneWidget);
      if (action == 'dismiss') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.tap(find.text(action));
      }
      await tester.pumpAndSettle();
      expect(result, action == 'Delete');
    }
  });

  testWidgets('badge displays unknown statuses and supplies a semantic label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: StatusBadge(status: 'WAITLISTED')),
    );
    expect(find.text('WAITLISTED'), findsOneWidget);
    expect(find.bySemanticsLabel('Status: WAITLISTED'), findsOneWidget);
    semantics.dispose();
  });
}
