import 'package:arena_api/arena_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../shared/paged_list.dart';
import 'booking_data.dart';

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
          if (widget.selectedId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Selected: ${widget.selectedTitle ?? widget.selectedId}',
              ),
            ),
          ListTile(
            title: const Text('All events'),
            selected: widget.selectedId == null,
            onTap: () =>
                Navigator.pop(context, const BookingEventSelection(null, null)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: state.items.length + 1,
              itemBuilder: (context, index) {
                if (index == state.items.length) {
                  return PagedListFooter(
                    state: state,
                    onLoadMore: controller.loadMore,
                    onRetry: controller.retry,
                  );
                }
                final event = state.items[index];
                return ListTile(
                  title: Text(event.title),
                  subtitle: Text('${event.sport} · ${event.location}'),
                  selected: event.id == widget.selectedId,
                  onTap: () => Navigator.pop(
                    context,
                    BookingEventSelection(event.id, event.title),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
