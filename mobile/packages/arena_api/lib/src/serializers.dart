//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_import

import 'package:one_of_serializer/any_of_serializer.dart';
import 'package:one_of_serializer/one_of_serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:arena_api/src/date_serializer.dart';
import 'package:arena_api/src/model/date.dart';

import 'package:arena_api/src/model/booking_page_response.dart';
import 'package:arena_api/src/model/booking_request.dart';
import 'package:arena_api/src/model/booking_response.dart';
import 'package:arena_api/src/model/event_page_response.dart';
import 'package:arena_api/src/model/event_request.dart';
import 'package:arena_api/src/model/event_response.dart';
import 'package:arena_api/src/model/event_status_request.dart';
import 'package:arena_api/src/model/participant.dart';
import 'package:arena_api/src/model/problem_detail.dart';
import 'package:arena_api/src/model/validation_request.dart';

part 'serializers.g.dart';

@SerializersFor([
  BookingPageResponse,
  BookingRequest,
  BookingResponse,
  EventPageResponse,
  EventRequest,
  EventResponse,
  EventStatusRequest,
  Participant,
  ProblemDetail,
  ValidationRequest,
])
Serializers serializers = (_$serializers.toBuilder()
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(EventResponse)]),
        () => ListBuilder<EventResponse>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltMap, [FullType(String), FullType.nullable(JsonObject)]),
        () => MapBuilder<String, JsonObject?>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(BookingResponse)]),
        () => ListBuilder<BookingResponse>(),
      )
      ..add(const OneOfSerializer())
      ..add(const AnyOfSerializer())
      ..add(const DateSerializer())
      ..add(Iso8601DateTimeSerializer())
    ).build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();
