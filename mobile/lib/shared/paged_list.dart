import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_error.dart';
import 'feedback_panel.dart';

@immutable
class PageResult<T> {
  PageResult({
    required List<T> items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  }) : items = List.unmodifiable(items);

  final List<T> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
}

@immutable
class PagedListState<T> {
  PagedListState({
    List<T> items = const [],
    this.page = 0,
    this.size = 20,
    this.totalElements = 0,
    this.totalPages = 0,
    this.loading = false,
    this.refreshing = false,
    this.loadingMore = false,
    this.error,
  }) : items = List.unmodifiable(items);

  final List<T> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool loading;
  final bool refreshing;
  final bool loadingMore;
  final String? error;

  bool get hasMore => page + 1 < totalPages;
}

abstract class PagedListController<T> extends Notifier<PagedListState<T>> {
  CancelToken? _cancelToken;
  int _generation = 0;
  bool _disposed = false;
  bool _failedAppend = false;

  Future<PageResult<T>> fetchPage(int page, int size, CancelToken cancelToken);
  String itemId(T item);

  @override
  PagedListState<T> build() {
    _disposed = false;
    _failedAppend = false;
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _cancelToken?.cancel();
      _cancelToken = null;
    });
    return PagedListState<T>(loading: true);
  }

  /// Reset supersedes in-flight work, for example when filters change.
  Future<void> refresh({bool reset = false}) {
    if (_disposed || (_cancelToken != null && !reset)) {
      return Future.value();
    }
    if (reset) {
      _generation++;
      _cancelToken?.cancel();
      _cancelToken = null;
      state = PagedListState<T>(size: state.size, loading: true);
    }
    return _request(append: false);
  }

  Future<void> loadMore() {
    if (_disposed || _cancelToken != null || !state.hasMore) {
      return Future.value();
    }
    return _request(append: true);
  }

  Future<void> retry() {
    if (_disposed || state.error == null) return Future.value();
    return _failedAppend ? loadMore() : refresh();
  }

  PagedListState<T> _retained({
    bool loading = false,
    bool refreshing = false,
    bool loadingMore = false,
    String? error,
  }) => PagedListState<T>(
    items: state.items,
    page: state.page,
    size: state.size,
    totalElements: state.totalElements,
    totalPages: state.totalPages,
    loading: loading,
    refreshing: refreshing,
    loadingMore: loadingMore,
    error: error,
  );

  Future<void> _request({required bool append}) async {
    final generation = ++_generation;
    final token = CancelToken();
    _cancelToken = token;
    final page = append ? state.page + 1 : 0;
    state = _retained(
      loading: !append && state.items.isEmpty,
      refreshing: !append && state.items.isNotEmpty,
      loadingMore: append,
    );
    bool current() => !_disposed && generation == _generation;
    try {
      final result = await fetchPage(page, state.size, token);
      if (!current()) return;
      if (token.isCancelled) {
        state = _retained();
        return;
      }
      final seen = <String>{};
      final items = [
        if (append) ...state.items,
        ...result.items,
      ].where((item) => seen.add(itemId(item))).toList();
      state = PagedListState<T>(
        items: items,
        page: result.page,
        size: result.size,
        totalElements: result.totalElements,
        totalPages: result.totalPages,
      );
      _failedAppend = false;
    } catch (error) {
      if (!current()) return;
      if (token.isCancelled ||
          (error is DioException && CancelToken.isCancel(error))) {
        state = _retained();
        return;
      }
      _failedAppend = append;
      state = _retained(error: describeApiError(error).message);
    } finally {
      if (current()) _cancelToken = null;
    }
  }
}

class PagedListFooter<T> extends StatelessWidget {
  const PagedListFooter({
    super.key,
    required this.state,
    required this.onLoadMore,
    required this.onRetry,
  });

  final PagedListState<T> state;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final busy = state.loading || state.refreshing || state.loadingMore;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!busy && state.error == null)
            Text('${state.items.length} of ${state.totalElements} items'),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(semanticsLabel: 'Loading items'),
            )
          else if (state.error != null)
            FeedbackPanel(
              title: 'Unable to load items',
              message: state.error,
              onRetry: onRetry,
            )
          else if (state.hasMore)
            TextButton(onPressed: onLoadMore, child: const Text('Load more')),
        ],
      ),
    );
  }
}
