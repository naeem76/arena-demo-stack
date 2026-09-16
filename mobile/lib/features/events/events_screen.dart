import 'package:flutter/material.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Icon(
            Icons.event_outlined,
            size: 32,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text('Events unavailable', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text('Event loading is not connected yet.'),
        const SizedBox(height: 8),
        const Text('Next step: configure sign-in and connect the event list.'),
      ],
    );
  }
}
