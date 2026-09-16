import 'package:arena_api/arena_api.dart';

bool canEditEvent(EventResponseStatusEnum status) =>
    status == EventResponseStatusEnum.SCHEDULED;

List<EventStatusRequestStatusEnum> allowedEventTransitions(
  EventResponseStatusEnum status,
) => switch (status) {
  EventResponseStatusEnum.SCHEDULED => const [
    EventStatusRequestStatusEnum.LIVE,
    EventStatusRequestStatusEnum.CANCELLED,
  ],
  EventResponseStatusEnum.LIVE => const [
    EventStatusRequestStatusEnum.COMPLETED,
    EventStatusRequestStatusEnum.CANCELLED,
  ],
  _ => const [],
};

const eventTextLimits = {
  'title': 150,
  'sport': 50,
  'location': 200,
  'description': 2000,
};
Map<String, String> validateEventValues(
  Map<String, dynamic> values, {
  required bool creating,
  DateTime? now,
}) {
  final errors = <String, String>{};
  for (final entry in eventTextLimits.entries) {
    final text = (values[entry.key] as String? ?? '').trim();
    if (entry.key != 'description' && text.isEmpty) {
      errors[entry.key] = 'Required';
    }
    if (text.length > entry.value) {
      errors[entry.key] = 'Use at most ${entry.value} characters';
    }
  }
  final capacity = int.tryParse(values['capacity'] as String? ?? '');
  if (capacity == null || capacity < 1 || capacity > 2147483647) {
    errors['capacity'] = capacity != null && capacity > 2147483647
        ? 'Use 2,147,483,647 or fewer places'
        : 'Enter a whole number of at least 1';
  }
  final start = DateTime.tryParse(values['startsAt'] as String? ?? '');
  final end = DateTime.tryParse(values['endsAt'] as String? ?? '');
  if (start == null) {
    errors['startsAt'] = 'Choose a start date and time';
  } else if (creating && !start.isAfter(now ?? DateTime.now())) {
    errors['startsAt'] = 'Start must be in the future';
  }
  if (end == null) {
    errors['endsAt'] = 'Choose an end date and time';
  } else if (start != null && !end.isAfter(start)) {
    errors['endsAt'] = 'End must be after start';
  }
  return errors;
}

EventRequest eventRequestFromValues(Map<String, dynamic> values) =>
    EventRequest(
      (b) => b
        ..title = (values['title'] as String).trim()
        ..sport = (values['sport'] as String).trim()
        ..location = (values['location'] as String).trim()
        ..description = (values['description'] as String? ?? '').trim()
        ..capacity = int.parse(values['capacity'] as String)
        ..startsAt = DateTime.parse(values['startsAt'] as String).toUtc()
        ..endsAt = DateTime.parse(values['endsAt'] as String).toUtc(),
    );
