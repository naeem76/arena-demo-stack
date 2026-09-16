import 'package:arena_api/arena_api.dart';
import 'package:flutter/material.dart';

import '../../shared/status_badge.dart';

String bookingTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final labels = MaterialLocalizations.of(context);
  return '${labels.formatMediumDate(local)} · ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

class BookingSummary extends StatelessWidget {
  const BookingSummary({
    super.key,
    required this.booking,
    this.details = false,
  });
  final BookingResponse booking;
  final bool details;

  @override
  Widget build(BuildContext context) {
    final event = booking.event;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(event.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        StatusBadge(status: booking.status.name),
        const SizedBox(height: 8),
        Text('Participant: ${booking.participant.displayName}'),
        Text('Participant ID: ${booking.participant.id}'),
        Text('${event.sport} · ${event.location}'),
        Text('Starts: ${bookingTime(context, event.startsAt)}'),
        Text('Ends: ${bookingTime(context, event.endsAt)}'),
        if (details) ...[
          const Divider(height: 32),
          Text('Booking ID: ${booking.id}'),
          Text('Event ID: ${event.id}'),
          Text('Event status: ${event.status.name}'),
          if (event.description?.isNotEmpty == true) Text(event.description!),
          Text('Capacity: ${event.capacity}'),
          const SizedBox(height: 16),
          Text(
            'Booking history',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('Created: ${bookingTime(context, booking.createdAt)}'),
          Text('Last updated: ${bookingTime(context, booking.updatedAt)}'),
          Text('Current status: ${booking.status.name}'),
          if (booking.status.name == 'CANCELLED')
            const Text('This booking was cancelled. Its history is retained.'),
        ],
      ],
    );
  }
}
