//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:arena_api/src/model/event_response.dart';
import 'package:arena_api/src/model/participant.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'booking_response.g.dart';

/// BookingResponse
///
/// Properties:
/// * [id]
/// * [event]
/// * [status]
/// * [createdAt]
/// * [updatedAt]
/// * [participant]
@BuiltValue()
abstract class BookingResponse implements Built<BookingResponse, BookingResponseBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'event')
  EventResponse get event;

  @BuiltValueField(wireName: r'status')
  BookingResponseStatusEnum get status;
  // enum statusEnum {  CONFIRMED,  CANCELLED,  };

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'updatedAt')
  DateTime get updatedAt;

  @BuiltValueField(wireName: r'participant')
  Participant get participant;

  BookingResponse._();

  factory BookingResponse([void updates(BookingResponseBuilder b)]) = _$BookingResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(BookingResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<BookingResponse> get serializer => _$BookingResponseSerializer();
}

class _$BookingResponseSerializer implements PrimitiveSerializer<BookingResponse> {
  @override
  final Iterable<Type> types = const [BookingResponse, _$BookingResponse];

  @override
  final String wireName = r'BookingResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    BookingResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'event';
    yield serializers.serialize(
      object.event,
      specifiedType: const FullType(EventResponse),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(BookingResponseStatusEnum),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'updatedAt';
    yield serializers.serialize(
      object.updatedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'participant';
    yield serializers.serialize(
      object.participant,
      specifiedType: const FullType(Participant),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    BookingResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required BookingResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'event':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(EventResponse),
          ) as EventResponse;
          result.event.replace(valueDes);
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BookingResponseStatusEnum),
          ) as BookingResponseStatusEnum;
          result.status = valueDes;
          break;
        case r'createdAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.createdAt = valueDes;
          break;
        case r'updatedAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.updatedAt = valueDes;
          break;
        case r'participant':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Participant),
          ) as Participant;
          result.participant.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  BookingResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = BookingResponseBuilder();
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


class BookingResponseStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'CONFIRMED')
  static const BookingResponseStatusEnum CONFIRMED = _$bookingResponseStatusEnum_CONFIRMED;
  @BuiltValueEnumConst(wireName: r'CANCELLED')
  static const BookingResponseStatusEnum CANCELLED = _$bookingResponseStatusEnum_CANCELLED;

  static Serializer<BookingResponseStatusEnum> get serializer => _$bookingResponseStatusEnumSerializer;

  const BookingResponseStatusEnum._(String name): super(name);

  static BuiltSet<BookingResponseStatusEnum> get values => _$bookingResponseStatusEnumValues;
  static BookingResponseStatusEnum valueOf(String name) => _$bookingResponseStatusEnumValueOf(name);
}
