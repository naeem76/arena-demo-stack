// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_page_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$BookingPageResponse extends BookingPageResponse {
  @override
  final BuiltList<BookingResponse> items;
  @override
  final int page;
  @override
  final int size;
  @override
  final int totalElements;
  @override
  final int totalPages;

  factory _$BookingPageResponse(
          [void Function(BookingPageResponseBuilder)? updates]) =>
      (BookingPageResponseBuilder()..update(updates))._build();

  _$BookingPageResponse._(
      {required this.items,
      required this.page,
      required this.size,
      required this.totalElements,
      required this.totalPages})
      : super._();
  @override
  BookingPageResponse rebuild(
          void Function(BookingPageResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  BookingPageResponseBuilder toBuilder() =>
      BookingPageResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is BookingPageResponse &&
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
    return (newBuiltValueToStringHelper(r'BookingPageResponse')
          ..add('items', items)
          ..add('page', page)
          ..add('size', size)
          ..add('totalElements', totalElements)
          ..add('totalPages', totalPages))
        .toString();
  }
}

class BookingPageResponseBuilder
    implements Builder<BookingPageResponse, BookingPageResponseBuilder> {
  _$BookingPageResponse? _$v;

  ListBuilder<BookingResponse>? _items;
  ListBuilder<BookingResponse> get items =>
      _$this._items ??= ListBuilder<BookingResponse>();
  set items(ListBuilder<BookingResponse>? items) => _$this._items = items;

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

  BookingPageResponseBuilder() {
    BookingPageResponse._defaults(this);
  }

  BookingPageResponseBuilder get _$this {
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
  void replace(BookingPageResponse other) {
    _$v = other as _$BookingPageResponse;
  }

  @override
  void update(void Function(BookingPageResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  BookingPageResponse build() => _build();

  _$BookingPageResponse _build() {
    _$BookingPageResponse _$result;
    try {
      _$result = _$v ??
          _$BookingPageResponse._(
            items: items.build(),
            page: BuiltValueNullFieldError.checkNotNull(
                page, r'BookingPageResponse', 'page'),
            size: BuiltValueNullFieldError.checkNotNull(
                size, r'BookingPageResponse', 'size'),
            totalElements: BuiltValueNullFieldError.checkNotNull(
                totalElements, r'BookingPageResponse', 'totalElements'),
            totalPages: BuiltValueNullFieldError.checkNotNull(
                totalPages, r'BookingPageResponse', 'totalPages'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'BookingPageResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
