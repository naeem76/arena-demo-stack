import 'package:flutter/material.dart';

void showErrorFeedback(BuildContext context, String message) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted || !TickerMode.valuesOf(context).enabled) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  });
}

class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.loading = false,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center),
          ],
          if (loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(semanticsLabel: 'Loading'),
            )
          else if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
