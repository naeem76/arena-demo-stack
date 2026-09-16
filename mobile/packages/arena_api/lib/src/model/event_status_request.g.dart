// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_status_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const EventStatusRequestStatusEnum _$eventStatusRequestStatusEnum_SCHEDULED =
    const EventStatusRequestStatusEnum._('SCHEDULED');
const EventStatusRequestStatusEnum _$eventStatusRequestStatusEnum_LIVE =
    const EventStatusRequestStatusEnum._('LIVE');
const EventStatusRequestStatusEnum _$eventStatusRequestStatusEnum_COMPLETED =
    const EventStatusRequestStatusEnum._('COMPLETED');
const EventStatusRequestStatusEnum _$eventStatusRequestStatusEnum_CANCELLED =
    const EventStatusRequestStatusEnum._('CANCELLED');

EventStatusRequestStatusEnum _$eventStatusRequestStatusEnumValueOf(
    String name) {
  switch (name) {
    case 'SCHEDULED':
      return _$eventStatusRequestStatusEnum_SCHEDULED;
    case 'LIVE':
      return _$eventStatusRequestStatusEnum_LIVE;
    case 'COMPLETED':
      return _$eventStatusRequestStatusEnum_COMPLETED;
    case 'CANCELLED':
      return _$eventStatusRequestStatusEnum_CANCELLED;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<EventStatusRequestStatusEnum>
    _$eventStatusRequestStatusEnumValues =
    BuiltSet<EventStatusRequestStatusEnum>(const <EventStatusRequestStatusEnum>[
  _$eventStatusRequestStatusEnum_SCHEDULED,
  _$eventStatusRequestStatusEnum_LIVE,
  _$eventStatusRequestStatusEnum_COMPLETED,
  _$eventStatusRequestStatusEnum_CANCELLED,
]);

Serializer<EventStatusRequestStatusEnum>
    _$eventStatusRequestStatusEnumSerializer =
    _$EventStatusRequestStatusEnumSerializer();

class _$EventStatusRequestStatusEnumSerializer
    implements PrimitiveSerializer<EventStatusRequestStatusEnum> {
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
  final Iterable<Type> types = const <Type>[EventStatusRequestStatusEnum];
  @override
  final String wireName = 'EventStatusRequestStatusEnum';

  @override
  Object serialize(Serializers serializers, EventStatusRequestStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  EventStatusRequestStatusEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      EventStatusRequestStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$EventStatusRequest extends EventStatusRequest {
  @override
  final EventStatusRequestStatusEnum status;

  factory _$EventStatusRequest(
          [void Function(EventStatusRequestBuilder)? updates]) =>
      (EventStatusRequestBuilder()..update(updates))._build();

  _$EventStatusRequest._({required this.status}) : super._();
  @override
  EventStatusRequest rebuild(
          void Function(EventStatusRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EventStatusRequestBuilder toBuilder() =>
      EventStatusRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is EventStatusRequest && status == other.status;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'EventStatusRequest')
          ..add('status', status))
        .toString();
  }
}

class EventStatusRequestBuilder
    implements Builder<EventStatusRequest, EventStatusRequestBuilder> {
  _$EventStatusRequest? _$v;

  EventStatusRequestStatusEnum? _status;
  EventStatusRequestStatusEnum? get status => _$this._status;
  set status(EventStatusRequestStatusEnum? status) => _$this._status = status;

  EventStatusRequestBuilder() {
    EventStatusRequest._defaults(this);
  }

  EventStatusRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _status = $v.status;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(EventStatusRequest other) {
    _$v = other as _$EventStatusRequest;
  }

  @override
  void update(void Function(EventStatusRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  EventStatusRequest build() => _build();

  _$EventStatusRequest _build() {
    final _$result = _$v ??
        _$EventStatusRequest._(
          status: BuiltValueNullFieldError.checkNotNull(
              status, r'EventStatusRequest', 'status'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
