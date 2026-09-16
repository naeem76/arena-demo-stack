import 'dart:async';

import 'package:arena_mobile/core/api/api_error.dart';
import 'package:arena_mobile/shared/paged_list.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Request {
  _Request(this.page, this.size, this.token);
  final int page;
  final int size;
  final CancelToken token;
  final result = Completer<PageResult<String>>();

  void complete(List<String> items, {int? serverPage, int totalPages = 3}) {
    result.complete(
      PageResult(
        items: items,
        page: serverPage ?? page,
        size: size,
        totalElements: 6,
        totalPages: totalPages,
      ),
    );
  }
}

class _Controller extends PagedListController<String> {
  final requests = <_Request>[];

  @override
  String itemId(String item) => item;

  @override
  Future<PageResult<String>> fetchPage(int page, int size, CancelToken token) {
    final request = _Request(page, size, token);
    requests.add(request);
    return request.result.future;
  }
}

void main() {
  late ProviderContainer container;
  late NotifierProvider<_Controller, PagedListState<String>> provider;
  late _Controller controller;

  setUp(() {
    container = ProviderContainer();
    provider = NotifierProvider(_Controller.new);
    controller = container.read(provider.notifier);
  });
  tearDown(() => container.dispose());

  Future<void> seed() async {
    final pending = controller.refresh();
    controller.requests.last.complete(['a', 'b']);
    await pending;
  }

  test(
    'starts loading without an empty-result claim; snapshots cannot be mutated',
    () {
      final state = container.read(provider);
      expect(controller.requests, isEmpty);
      expect(state.items, isEmpty);
      expect(state.size, 20);
      expect(state.loading, isTrue);
      expect(state.hasMore, isFalse);
      final source = ['a'];
      final snapshot = PagedListState(items: source);
      source.add('b');
      expect(snapshot.items, ['a']);
      expect(() => snapshot.items.add('c'), throwsUnsupportedError);
    },
  );

  test(
    'appends unique rows in stable order and stops at server last page',
    () async {
      await seed();
      final pending = controller.loadMore();
      expect(container.read(provider).loadingMore, isTrue);
      expect(controller.requests.last.page, 1);
      expect(controller.requests.last.size, 20);
      controller.requests.last.complete(['b', 'c', 'c'], serverPage: 2);
      await pending;
      final state = container.read(provider);
      expect(state.items, ['a', 'b', 'c']);
      expect(state.page, 2);
      expect(state.totalElements, 6);
      expect(state.totalPages, 3);
      expect(state.hasMore, isFalse);
      await controller.loadMore();
      expect(controller.requests, hasLength(2));
    },
  );

  test(
    'refresh failure retains rows and metadata; retry replaces from page zero',
    () async {
      await seed();
      final append = controller.loadMore();
      controller.requests.last.complete(['c']);
      await append;
      final pending = controller.refresh();
      expect(container.read(provider).refreshing, isTrue);
      expect(container.read(provider).items, ['a', 'b', 'c']);
      controller.requests.last.result.completeError(ApiError('Try again'));
      await pending;
      final failed = container.read(provider);
      expect(failed.items, ['a', 'b', 'c']);
      expect(failed.page, 1);
      expect(failed.error, 'Try again');
      expect(failed.refreshing, isFalse);
      final retry = controller.retry();
      expect(controller.requests.last.page, 0);
      controller.requests.last.complete(['new']);
      await retry;
      expect(container.read(provider).items, ['new']);
      expect(container.read(provider).error, isNull);
    },
  );

  test(
    'append failure never advances page or rows and retry requests same page',
    () async {
      await seed();
      final pending = controller.loadMore();
      controller.requests.last.result.completeError(
        StateError('secret request'),
      );
      await pending;
      final failed = container.read(provider);
      expect(failed.items, ['a', 'b']);
      expect(failed.page, 0);
      expect(failed.error, 'Something went wrong. Please try again.');
      expect(failed.loadingMore, isFalse);
      final retry = controller.retry();
      expect(controller.requests.last.page, 1);
      controller.requests.last.complete(['c']);
      await retry;
      expect(container.read(provider).items, ['a', 'b', 'c']);
    },
  );

  test(
    'filter reset cancels append and ignores stale success after new result',
    () async {
      await seed();
      final oldPending = controller.loadMore();
      final old = controller.requests.last;
      final newPending = controller.refresh(reset: true);
      expect(old.token.isCancelled, isTrue);
      expect(container.read(provider).items, isEmpty);
      expect(container.read(provider).loading, isTrue);
      expect(container.read(provider).totalPages, 0);
      controller.requests.last.complete(['filtered'], totalPages: 1);
      await newPending;
      old.complete(['stale']);
      await oldPending;
      expect(container.read(provider).items, ['filtered']);
      expect(container.read(provider).hasMore, isFalse);
    },
  );

  test('stale cancellation cannot clear new request loading flags', () async {
    final oldPending = controller.refresh();
    final old = controller.requests.last;
    final newPending = controller.refresh(reset: true);
    old.result.completeError(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.cancel,
      ),
    );
    await oldPending;
    expect(container.read(provider).loading, isTrue);
    expect(container.read(provider).error, isNull);
    controller.requests.last.complete([]);
    await newPending;
    expect(container.read(provider).loading, isFalse);
  });

  test('busy duplicate calls do not start additional requests', () async {
    await seed();
    final pending = controller.loadMore();
    await controller.loadMore();
    await controller.refresh();
    await controller.retry();
    expect(controller.requests, hasLength(2));
    controller.requests.last.complete(['c']);
    await pending;
    final refresh = controller.refresh();
    await controller.refresh();
    await controller.loadMore();
    expect(controller.requests, hasLength(3));
    controller.requests.last.complete(['d']);
    await refresh;
  });

  test('empty pages never automatically fetch another page', () async {
    final pending = controller.refresh();
    controller.requests.last.complete([]);
    await pending;
    expect(controller.requests, hasLength(1));
    expect(container.read(provider).items, isEmpty);
    expect(container.read(provider).hasMore, isTrue);
  });

  test(
    'current cancellation retains rows without presenting an error',
    () async {
      await seed();
      final pending = controller.loadMore();
      final request = controller.requests.last;
      request.token.cancel();
      request.result.completeError(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.cancel,
        ),
      );
      await pending;
      expect(container.read(provider).items, ['a', 'b']);
      expect(container.read(provider).loadingMore, isFalse);
      expect(container.read(provider).error, isNull);
    },
  );

  test(
    'disposal cancels pending request and late completion is harmless',
    () async {
      final pending = controller.refresh();
      final request = controller.requests.last;
      container.dispose();
      expect(request.token.isCancelled, isTrue);
      request.complete(['late']);
      await pending;
      await controller.refresh();
      expect(controller.requests, hasLength(1));
    },
  );
}
