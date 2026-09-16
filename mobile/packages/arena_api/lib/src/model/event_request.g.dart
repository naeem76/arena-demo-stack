// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$EventRequest extends EventRequest {
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

  factory _$EventRequest([void Function(EventRequestBuilder)? updates]) =>
      (EventRequestBuilder()..update(updates))._build();

  _$EventRequest._(
      {required this.title,
      this.description,
      required this.sport,
      required this.location,
      required this.startsAt,
      required this.endsAt,
      required this.capacity})
      : super._();
  @override
  EventRequest rebuild(void Function(EventRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EventRequestBuilder toBuilder() => EventRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EventRequest &&
        title == other.title &&
        description == other.description &&
        sport == other.sport &&
        location == other.location &&
        startsAt == other.startsAt &&
        endsAt == other.endsAt &&
        capacity == other.capacity;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, sport.hashCode);
    _$hash = $jc(_$hash, location.hashCode);
    _$hash = $jc(_$hash, startsAt.hashCode);
    _$hash = $jc(_$hash, endsAt.hashCode);
    _$hash = $jc(_$hash, capacity.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'EventRequest')
          ..add('title', title)
          ..add('description', description)
          ..add('sport', sport)
          ..add('location', location)
          ..add('startsAt', startsAt)
          ..add('endsAt', endsAt)
          ..add('capacity', capacity))
        .toString();
  }
}

class EventRequestBuilder
    implements Builder<EventRequest, EventRequestBuilder> {
  _$EventRequest? _$v;

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

  EventRequestBuilder() {
    EventRequest._defaults(this);
  }

  EventRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _title = $v.title;
      _description = $v.description;
      _sport = $v.sport;
      _location = $v.location;
      _startsAt = $v.startsAt;
      _endsAt = $v.endsAt;
      _capacity = $v.capacity;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(EventRequest other) {
    _$v = other as _$EventRequest;
  }

  @override
  void update(void Function(EventRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  EventRequest build() => _build();

  _$EventRequest _build() {
    final _$result = _$v ??
        _$EventRequest._(
          title: BuiltValueNullFieldError.checkNotNull(
              title, r'EventRequest', 'title'),
          description: description,
          sport: BuiltValueNullFieldError.checkNotNull(
              sport, r'EventRequest', 'sport'),
          location: BuiltValueNullFieldError.checkNotNull(
              location, r'EventRequest', 'location'),
          startsAt: BuiltValueNullFieldError.checkNotNull(
              startsAt, r'EventRequest', 'startsAt'),
          endsAt: BuiltValueNullFieldError.checkNotNull(
              endsAt, r'EventRequest', 'endsAt'),
          capacity: BuiltValueNullFieldError.checkNotNull(
              capacity, r'EventRequest', 'capacity'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
