// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const EventResponseStatusEnum _$eventResponseStatusEnum_SCHEDULED =
    const EventResponseStatusEnum._('SCHEDULED');
const EventResponseStatusEnum _$eventResponseStatusEnum_LIVE =
    const EventResponseStatusEnum._('LIVE');
const EventResponseStatusEnum _$eventResponseStatusEnum_COMPLETED =
    const EventResponseStatusEnum._('COMPLETED');
const EventResponseStatusEnum _$eventResponseStatusEnum_CANCELLED =
    const EventResponseStatusEnum._('CANCELLED');

EventResponseStatusEnum _$eventResponseStatusEnumValueOf(String name) {
  switch (name) {
    case 'SCHEDULED':
      return _$eventResponseStatusEnum_SCHEDULED;
    case 'LIVE':
      return _$eventResponseStatusEnum_LIVE;
    case 'COMPLETED':
      return _$eventResponseStatusEnum_COMPLETED;
    case 'CANCELLED':
      return _$eventResponseStatusEnum_CANCELLED;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<EventResponseStatusEnum> _$eventResponseStatusEnumValues =
    BuiltSet<EventResponseStatusEnum>(const <EventResponseStatusEnum>[
  _$eventResponseStatusEnum_SCHEDULED,
  _$eventResponseStatusEnum_LIVE,
  _$eventResponseStatusEnum_COMPLETED,
  _$eventResponseStatusEnum_CANCELLED,
]);

Serializer<EventResponseStatusEnum> _$eventResponseStatusEnumSerializer =
    _$EventResponseStatusEnumSerializer();

class _$EventResponseStatusEnumSerializer
    implements PrimitiveSerializer<EventResponseStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'SCHEDULED': 'SCHEDULED',
    'LIVE': 'LIVE',
    'COMPLETED': 'COMPLETED',
    'CANCELLED': 'CANCELLED',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'SCHEDULED': 'SCHEDULED',
    'LIVE': 'LIVE',
    'COMPLETED': 'COMPLETED',
    'CANCELLED': 'CANCELLED',
  };

  @override
  final Iterable<Type> types = const <Type>[EventResponseStatusEnum];
  @override
  final String wireName = 'EventResponseStatusEnum';

  @override
  Object serialize(Serializers serializers, EventResponseStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  EventResponseStatusEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      EventResponseStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$EventResponse extends EventResponse {
  @override
  final String id;
  @override
  final String title;
  @override
  final String? description;
  @override
  final String sport;
  @override
  final String location;
  @override
  final DateTime startsAt;
  @override
  final DateTime endsAt;
  @override
  final int capacity;
  @override
  final EventResponseStatusEnum status;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  factory _$EventResponse([void Function(EventResponseBuilder)? updates]) =>
      (EventResponseBuilder()..update(updates))._build();

  _$EventResponse._(
      {required this.id,
      required this.title,
      this.description,
      required this.sport,
      required this.location,
      required this.startsAt,
      required this.endsAt,
      required this.capacity,
      required this.status,
      required this.createdAt,
      required this.updatedAt})
      : super._();
  @override
  EventResponse rebuild(void Function(EventResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EventResponseBuilder toBuilder() => EventResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EventResponse &&
        id == other.id &&
        title == other.title &&
        description == other.description &&
        sport == other.sport &&
        location == other.location &&
        startsAt == other.startsAt &&
        endsAt == other.endsAt &&
        capacity == other.capacity &&
        status == other.status &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, sport.hashCode);
    _$hash = $jc(_$hash, location.hashCode);
    _$hash = $jc(_$hash, startsAt.hashCode);
    _$hash = $jc(_$hash, endsAt.hashCode);
    _$hash = $jc(_$hash, capacity.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'EventResponse')
          ..add('id', id)
          ..add('title', title)
          ..add('description', description)
          ..add('sport', sport)
          ..add('location', location)
          ..add('startsAt', startsAt)
          ..add('endsAt', endsAt)
          ..add('capacity', capacity)
          ..add('status', status)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class EventResponseBuilder
    implements Builder<EventResponse, EventResponseBuilder> {
  _$EventResponse? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  String? _sport;
  String? get sport => _$this._sport;
  set sport(String? sport) => _$this._sport = sport;

  String? _location;
  String? get location => _$this._location;
  set location(String? location) => _$this._location = location;

  DateTime? _startsAt;
  DateTime? get startsAt => _$this._startsAt;
  set startsAt(DateTime? startsAt) => _$this._startsAt = startsAt;

  DateTime? _endsAt;
  DateTime? get endsAt => _$this._endsAt;
  set endsAt(DateTime? endsAt) => _$this._endsAt = endsAt;

  int? _capacity;
  int? get capacity => _$this._capacity;
  set capacity(int? capacity) => _$this._capacity = capacity;

  EventResponseStatusEnum? _status;
  EventResponseStatusEnum? get status => _$this._status;
  set status(EventResponseStatusEnum? status) => _$this._status = status;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  EventResponseBuilder() {
    EventResponse._defaults(this);
  }

  EventResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _title = $v.title;
      _description = $v.description;
      _sport = $v.sport;
      _location = $v.location;
      _startsAt = $v.startsAt;
      _endsAt = $v.endsAt;
      _capacity = $v.capacity;
      _status = $v.status;
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(EventResponse other) {
    _$v = other as _$EventResponse;
  }

  @override
  void update(void Function(EventResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  EventResponse build() => _build();

  _$EventResponse _build() {
    final _$result = _$v ??
        _$EventResponse._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'EventResponse', 'id'),
          title: BuiltValueNullFieldError.checkNotNull(
              title, r'EventResponse', 'title'),
          description: description,
          sport: BuiltValueNullFieldError.checkNotNull(
              sport, r'EventResponse', 'sport'),
          location: BuiltValueNullFieldError.checkNotNull(
              location, r'EventResponse', 'location'),
          startsAt: BuiltValueNullFieldError.checkNotNull(
              startsAt, r'EventResponse', 'startsAt'),
          endsAt: BuiltValueNullFieldError.checkNotNull(
              endsAt, r'EventResponse', 'endsAt'),
          capacity: BuiltValueNullFieldError.checkNotNull(
              capacity, r'EventResponse', 'capacity'),
          status: BuiltValueNullFieldError.checkNotNull(
              status, r'EventResponse', 'status'),
          createdAt: BuiltValueNullFieldError.checkNotNull(
              createdAt, r'EventResponse', 'createdAt'),
          updatedAt: BuiltValueNullFieldError.checkNotNull(
              updatedAt, r'EventResponse', 'updatedAt'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
