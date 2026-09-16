import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cancelled = status == 'CANCELLED';
    return Semantics(
      label: 'Status: $status',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cancelled ? colors.errorContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            status,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cancelled
                  ? colors.onErrorContainer
                  : colors.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
