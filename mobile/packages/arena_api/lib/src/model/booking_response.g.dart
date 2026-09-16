// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const BookingResponseStatusEnum _$bookingResponseStatusEnum_CONFIRMED =
    const BookingResponseStatusEnum._('CONFIRMED');
const BookingResponseStatusEnum _$bookingResponseStatusEnum_CANCELLED =
    const BookingResponseStatusEnum._('CANCELLED');

BookingResponseStatusEnum _$bookingResponseStatusEnumValueOf(String name) {
  switch (name) {
    case 'CONFIRMED':
      return _$bookingResponseStatusEnum_CONFIRMED;
    case 'CANCELLED':
      return _$bookingResponseStatusEnum_CANCELLED;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<BookingResponseStatusEnum> _$bookingResponseStatusEnumValues =
    BuiltSet<BookingResponseStatusEnum>(const <BookingResponseStatusEnum>[
  _$bookingResponseStatusEnum_CONFIRMED,
  _$bookingResponseStatusEnum_CANCELLED,
]);

Serializer<BookingResponseStatusEnum> _$bookingResponseStatusEnumSerializer =
    _$BookingResponseStatusEnumSerializer();

class _$BookingResponseStatusEnumSerializer
    implements PrimitiveSerializer<BookingResponseStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'CONFIRMED': 'CONFIRMED',
    'CANCELLED': 'CANCELLED',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'CONFIRMED': 'CONFIRMED',
    'CANCELLED': 'CANCELLED',
  };

  @override
  final Iterable<Type> types = const <Type>[BookingResponseStatusEnum];
  @override
  final String wireName = 'BookingResponseStatusEnum';

  @override
  Object serialize(Serializers serializers, BookingResponseStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  BookingResponseStatusEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      BookingResponseStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$BookingResponse extends BookingResponse {
  @override
  final String id;
  @override
  final EventResponse event;
  @override
  final BookingResponseStatusEnum status;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final Participant participant;

  factory _$BookingResponse([void Function(BookingResponseBuilder)? updates]) =>
      (BookingResponseBuilder()..update(updates))._build();

  _$BookingResponse._(
      {required this.id,
      required this.event,
      required this.status,
      required this.createdAt,
      required this.updatedAt,
      required this.participant})
      : super._();
  @override
  BookingResponse rebuild(void Function(BookingResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  BookingResponseBuilder toBuilder() => BookingResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is BookingResponse &&
        id == other.id &&
        event == other.event &&
        status == other.status &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        participant == other.participant;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, event.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, participant.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'BookingResponse')
          ..add('id', id)
          ..add('event', event)
          ..add('status', status)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt)
          ..add('participant', participant))
        .toString();
  }
}

class BookingResponseBuilder
    implements Builder<BookingResponse, BookingResponseBuilder> {
  _$BookingResponse? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  EventResponseBuilder? _event;
  EventResponseBuilder get event => _$this._event ??= EventResponseBuilder();
  set event(EventResponseBuilder? event) => _$this._event = event;

  BookingResponseStatusEnum? _status;
  BookingResponseStatusEnum? get status => _$this._status;
  set status(BookingResponseStatusEnum? status) => _$this._status = status;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  ParticipantBuilder? _participant;
  ParticipantBuilder get participant =>
      _$this._participant ??= ParticipantBuilder();
  set participant(ParticipantBuilder? participant) =>
      _$this._participant = participant;

  BookingResponseBuilder() {
    BookingResponse._defaults(this);
  }

  BookingResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _event = $v.event.toBuilder();
      _status = $v.status;
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _participant = $v.participant.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(BookingResponse other) {
    _$v = other as _$BookingResponse;
  }

  @override
  void update(void Function(BookingResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  BookingResponse build() => _build();

  _$BookingResponse _build() {
    _$BookingResponse _$result;
    try {
      _$result = _$v ??
          _$BookingResponse._(
            id: BuiltValueNullFieldError.checkNotNull(
                id, r'BookingResponse', 'id'),
            event: event.build(),
            status: BuiltValueNullFieldError.checkNotNull(
                status, r'BookingResponse', 'status'),
            createdAt: BuiltValueNullFieldError.checkNotNull(
                createdAt, r'BookingResponse', 'createdAt'),
            updatedAt: BuiltValueNullFieldError.checkNotNull(
                updatedAt, r'BookingResponse', 'updatedAt'),
            participant: participant.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'event';
        event.build();

        _$failedField = 'participant';
        participant.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'BookingResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
