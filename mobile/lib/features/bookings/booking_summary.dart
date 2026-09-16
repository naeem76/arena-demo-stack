import 'package:arena_api/arena_api.dart';
import 'package:flutter/material.dart';

import '../../shared/status_badge.dart';
import '../../shared/detail_section.dart';
import '../../shared/local_time.dart';

class BookingSummary extends StatelessWidget {
  const BookingSummary({
    super.key,
    required this.booking,
    this.details = false,
    this.action,
  });
  final BookingResponse booking;
  final bool details;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final event = booking.event;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          event.title,
          style: details
              ? theme.textTheme.headlineSmall
              : theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusBadge(status: booking.status.name),
        ),
        const SizedBox(height: 12),
        Text('Participant: ${booking.participant.displayName}'),
        if (action != null) ...[const SizedBox(height: 16), action!],
        const SizedBox(height: 12),
        if (!details) ...[
          Text('${event.sport} · ${event.location}'),
          const SizedBox(height: 4),
          Text('Starts: ${localTime(context, event.startsAt)}'),
        ] else ...[
          DetailSection(
            title: 'Event information',
            facts: {
              'Sport': event.sport,
              'Location': event.location,
              'Starts (local)': localTime(context, event.startsAt),
              'Ends (local)': localTime(context, event.endsAt),
              'Description': event.description?.trim().isNotEmpty == true
                  ? event.description!
                  : 'No description provided.',
              'Capacity': '${event.capacity}',
              'Event status': event.status.name,
            },
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booking history', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text('Created: ${localTime(context, booking.createdAt)}'),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: ${localTime(context, booking.updatedAt)}',
                  ),
                  const SizedBox(height: 8),
                  Text('Current status: ${booking.status.name}'),
                  if (booking.status.name == 'CANCELLED') ...[
                    const SizedBox(height: 8),
                    const Text(
                      'This booking was cancelled. Its history is retained.',
                    ),
                  ],
                ],
              ),
            ),
          ),
          DetailSection(
            title: 'Record details',
            facts: {
              'Booking ID': booking.id,
              'Event ID': event.id,
              'Participant ID': booking.participant.id,
            },
          ),
        ],
      ],
    );
  }
}
