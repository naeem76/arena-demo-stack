import 'package:flutter/material.dart';

/// Compact, readable facts shared by event and booking details.
class DetailSection extends StatelessWidget {
  const DetailSection({super.key, required this.title, required this.facts});

  final String title;
  final Map<String, String> facts;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          for (final fact in facts.entries) ...[
            const SizedBox(height: 12),
            Text(
              fact.key,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            SelectableText(fact.value),
          ],
        ],
      ),
    ),
  );
}
