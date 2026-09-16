import 'package:arena_api/arena_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../shared/paged_list.dart';
import 'booking_data.dart';
import '../../shared/local_time.dart';

class BookingEventSelection {
  const BookingEventSelection(this.id, this.title);
  final String? id;
  final String? title;
}

class BookingEventPicker extends ConsumerStatefulWidget {
  const BookingEventPicker({super.key, this.selectedId, this.selectedTitle});
  final String? selectedId;
  final String? selectedTitle;

  @override
  ConsumerState<BookingEventPicker> createState() => _BookingEventPickerState();
}

class _BookingEventPickerState extends ConsumerState<BookingEventPicker> {
  final provider =
      NotifierProvider.autoDispose<
        BookingEventsController,
        PagedListState<EventResponse>
      >(BookingEventsController.new);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(provider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(apiBaseUrlProvider, (previous, next) {
      if (previous != next) controller.refresh(reset: true);
    });
    ref.listen(authProvider, (previous, next) {
      if (next.session != null && previous?.session != next.session) {
        controller.refresh(reset: true);
      }
    });
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Choose event',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (widget.selectedId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Selected: ${widget.selectedTitle ?? widget.selectedId}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Card(
                  child: ListTile(
                    title: const Text('All events'),
                    leading: const Icon(Icons.event_note_outlined),
                    trailing: widget.selectedId == null
                        ? const Icon(Icons.check)
                        : null,
                    selected: widget.selectedId == null,
                    onTap: () => Navigator.pop(
                      context,
                      const BookingEventSelection(null, null),
                    ),
                  ),
                ),
                for (final event in state.items)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(event.title),
                      subtitle: Text(
                        '${event.sport} · ${event.location}\n${localTime(context, event.startsAt)}',
                      ),
                      trailing: event.id == widget.selectedId
                          ? const Icon(Icons.check)
                          : null,
                      selected: event.id == widget.selectedId,
                      onTap: () => Navigator.pop(
                        context,
                        BookingEventSelection(event.id, event.title),
                      ),
                    ),
                  ),
                PagedListFooter(
                  state: state,
                  onLoadMore: controller.loadMore,
                  onRetry: controller.retry,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
