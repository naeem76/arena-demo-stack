// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_page_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$EventPageResponse extends EventPageResponse {
  @override
  final BuiltList<EventResponse> items;
  @override
  final int page;
  @override
  final int size;
  @override
  final int totalElements;
  @override
  final int totalPages;

  factory _$EventPageResponse(
          [void Function(EventPageResponseBuilder)? updates]) =>
      (EventPageResponseBuilder()..update(updates))._build();

  _$EventPageResponse._(
      {required this.items,
      required this.page,
      required this.size,
      required this.totalElements,
      required this.totalPages})
      : super._();
  @override
  EventPageResponse rebuild(void Function(EventPageResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EventPageResponseBuilder toBuilder() =>
      EventPageResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EventPageResponse &&
        items == other.items &&
        page == other.page &&
        size == other.size &&
        totalElements == other.totalElements &&
        totalPages == other.totalPages;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jc(_$hash, page.hashCode);
    _$hash = $jc(_$hash, size.hashCode);
    _$hash = $jc(_$hash, totalElements.hashCode);
    _$hash = $jc(_$hash, totalPages.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'EventPageResponse')
          ..add('items', items)
          ..add('page', page)
          ..add('size', size)
          ..add('totalElements', totalElements)
          ..add('totalPages', totalPages))
        .toString();
  }
}

class EventPageResponseBuilder
    implements Builder<EventPageResponse, EventPageResponseBuilder> {
  _$EventPageResponse? _$v;

  ListBuilder<EventResponse>? _items;
  ListBuilder<EventResponse> get items =>
      _$this._items ??= ListBuilder<EventResponse>();
  set items(ListBuilder<EventResponse>? items) => _$this._items = items;

  int? _page;
  int? get page => _$this._page;
  set page(int? page) => _$this._page = page;

  int? _size;
  int? get size => _$this._size;
  set size(int? size) => _$this._size = size;

  int? _totalElements;
  int? get totalElements => _$this._totalElements;
  set totalElements(int? totalElements) =>
      _$this._totalElements = totalElements;

  int? _totalPages;
  int? get totalPages => _$this._totalPages;
  set totalPages(int? totalPages) => _$this._totalPages = totalPages;

  EventPageResponseBuilder() {
    EventPageResponse._defaults(this);
  }

  EventPageResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _items = $v.items.toBuilder();
      _page = $v.page;
      _size = $v.size;
      _totalElements = $v.totalElements;
      _totalPages = $v.totalPages;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(EventPageResponse other) {
    _$v = other as _$EventPageResponse;
  }

  @override
  void update(void Function(EventPageResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  EventPageResponse build() => _build();

  _$EventPageResponse _build() {
    _$EventPageResponse _$result;
    try {
      _$result = _$v ??
          _$EventPageResponse._(
            items: items.build(),
            page: BuiltValueNullFieldError.checkNotNull(
                page, r'EventPageResponse', 'page'),
            size: BuiltValueNullFieldError.checkNotNull(
                size, r'EventPageResponse', 'size'),
            totalElements: BuiltValueNullFieldError.checkNotNull(
                totalElements, r'EventPageResponse', 'totalElements'),
            totalPages: BuiltValueNullFieldError.checkNotNull(
                totalPages, r'EventPageResponse', 'totalPages'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'EventPageResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
