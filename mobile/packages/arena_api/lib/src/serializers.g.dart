// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'serializers.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializers _$serializers = (Serializers().toBuilder()
      ..add(BookingPageResponse.serializer)
      ..add(BookingRequest.serializer)
      ..add(BookingResponse.serializer)
      ..add(BookingResponseStatusEnum.serializer)
      ..add(EventPageResponse.serializer)
      ..add(EventRequest.serializer)
      ..add(EventResponse.serializer)
      ..add(EventResponseStatusEnum.serializer)
      ..add(EventStatusRequest.serializer)
      ..add(EventStatusRequestStatusEnum.serializer)
      ..add(Participant.serializer)
      ..add(ProblemDetail.serializer)
      ..add(ValidationRequest.serializer)
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(BookingResponse)]),
          () => ListBuilder<BookingResponse>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(EventResponse)]),
          () => ListBuilder<EventResponse>())
      ..addBuilderFactory(
          const FullType(BuiltMap, const [
            const FullType(String),
            const FullType.nullable(JsonObject)
          ]),
          () => MapBuilder<String, JsonObject?>()))
    .build();

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
