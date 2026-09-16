// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$BookingRequest extends BookingRequest {
  @override
  final String eventId;

  factory _$BookingRequest([void Function(BookingRequestBuilder)? updates]) =>
      (BookingRequestBuilder()..update(updates))._build();

  _$BookingRequest._({required this.eventId}) : super._();
  @override
  BookingRequest rebuild(void Function(BookingRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  BookingRequestBuilder toBuilder() => BookingRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is BookingRequest && eventId == other.eventId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, eventId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'BookingRequest')
          ..add('eventId', eventId))
        .toString();
  }
}

class BookingRequestBuilder
    implements Builder<BookingRequest, BookingRequestBuilder> {
  _$BookingRequest? _$v;

  String? _eventId;
  String? get eventId => _$this._eventId;
  set eventId(String? eventId) => _$this._eventId = eventId;

  BookingRequestBuilder() {
    BookingRequest._defaults(this);
  }

  BookingRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _eventId = $v.eventId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(BookingRequest other) {
    _$v = other as _$BookingRequest;
  }

  @override
  void update(void Function(BookingRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  BookingRequest build() => _build();

  _$BookingRequest _build() {
    final _$result = _$v ??
        _$BookingRequest._(
          eventId: BuiltValueNullFieldError.checkNotNull(
              eventId, r'BookingRequest', 'eventId'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
