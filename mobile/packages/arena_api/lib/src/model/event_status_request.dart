//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'event_status_request.g.dart';

/// EventStatusRequest
///
/// Properties:
/// * [status]
@BuiltValue()
abstract class EventStatusRequest implements Built<EventStatusRequest, EventStatusRequestBuilder> {
  @BuiltValueField(wireName: r'status')
  EventStatusRequestStatusEnum get status;
  // enum statusEnum {  SCHEDULED,  LIVE,  COMPLETED,  CANCELLED,  };

  EventStatusRequest._();

  factory EventStatusRequest([void updates(EventStatusRequestBuilder b)]) = _$EventStatusRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(EventStatusRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<EventStatusRequest> get serializer => _$EventStatusRequestSerializer();
}

class _$EventStatusRequestSerializer implements PrimitiveSerializer<EventStatusRequest> {
  @override
  final Iterable<Type> types = const [EventStatusRequest, _$EventStatusRequest];

  @override
  final String wireName = r'EventStatusRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    EventStatusRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(EventStatusRequestStatusEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    EventStatusRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required EventStatusRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(EventStatusRequestStatusEnum),
          ) as EventStatusRequestStatusEnum;
          result.status = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  EventStatusRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EventStatusRequestBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}


class EventStatusRequestStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'SCHEDULED')
  static const EventStatusRequestStatusEnum SCHEDULED = _$eventStatusRequestStatusEnum_SCHEDULED;
  @BuiltValueEnumConst(wireName: r'LIVE')
  static const EventStatusRequestStatusEnum LIVE = _$eventStatusRequestStatusEnum_LIVE;
  @BuiltValueEnumConst(wireName: r'COMPLETED')
  static const EventStatusRequestStatusEnum COMPLETED = _$eventStatusRequestStatusEnum_COMPLETED;
  @BuiltValueEnumConst(wireName: r'CANCELLED')
  static const EventStatusRequestStatusEnum CANCELLED = _$eventStatusRequestStatusEnum_CANCELLED;

  static Serializer<EventStatusRequestStatusEnum> get serializer => _$eventStatusRequestStatusEnumSerializer;

  const EventStatusRequestStatusEnum._(String name): super(name);

  static BuiltSet<EventStatusRequestStatusEnum> get values => _$eventStatusRequestStatusEnumValues;
  static EventStatusRequestStatusEnum valueOf(String name) => _$eventStatusRequestStatusEnumValueOf(name);
}
