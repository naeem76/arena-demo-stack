import 'package:arena_mobile/features/events/event_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> values() => {
    'title': ' Title ',
    'sport': ' Tennis ',
    'location': ' Court ',
    'description': '',
    'capacity': '20',
    'startsAt': '2030-01-02T03:04:05.123456Z',
    'endsAt': '2030-01-02T04:04:05.123456Z',
  };
  test('required trimmed fields and int32 capacity validated', () {
    for (final field in ['title', 'sport', 'location']) {
      expect(
        validateEventValues(values()..[field] = '  ', creating: false),
        contains(field),
      );
    }
    for (final capacity in ['0', '-1', '1.5', '2147483648', 'abc']) {
      expect(
        validateEventValues(values()..['capacity'] = capacity, creating: false),
        contains('capacity'),
      );
    }
    expect(
      validateEventValues(
        values()..['capacity'] = '2147483647',
        creating: false,
      ),
      isEmpty,
    );
    for (final field in eventTextLimits.entries) {
      expect(
        validateEventValues(
          values()..[field.key] = 'x' * (field.value + 1),
          creating: false,
        ),
        contains(field.key),
      );
    }
  });
  test(
    'create requires future start; editing past scheduled event allowed',
    () {
      expect(
        validateEventValues(values(), creating: true, now: DateTime.utc(2031)),
        contains('startsAt'),
      );
      expect(
        validateEventValues(values(), creating: false, now: DateTime.utc(2031)),
        isEmpty,
      );
      expect(
        validateEventValues(
          values()..['endsAt'] = values()['startsAt'],
          creating: false,
        ),
        contains('endsAt'),
      );
    },
  );
  test('request trims text and preserves unchanged UTC microseconds', () {
    final request = eventRequestFromValues(values());
    expect(request.title, 'Title');
    expect(request.capacity, 20);
    expect(request.startsAt, DateTime.utc(2030, 1, 2, 3, 4, 5, 123, 456));
    expect(request.endsAt.isUtc, isTrue);
    final offset = values()..['startsAt'] = '2030-01-02T05:04:05.123456+02:00';
    expect(eventRequestFromValues(offset).startsAt, request.startsAt);
  });
}
