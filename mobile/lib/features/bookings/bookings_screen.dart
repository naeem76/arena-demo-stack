import 'package:arena_api/arena_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../shared/paged_list.dart';
import '../../shared/feedback_panel.dart';
import 'booking_data.dart';
import 'booking_detail_screen.dart';
import 'booking_event_picker.dart';
import 'booking_summary.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({
    super.key,
    this.eventId,
    this.eventTitle,
    this.filterRevision = 0,
    this.active = true,
  });
  final String? eventId;
  final String? eventTitle;
  final int filterRevision;
  final bool active;

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  late final provider =
      NotifierProvider.autoDispose<
        BookingsController,
        PagedListState<BookingResponse>
      >(() => BookingsController(eventId: widget.eventId));
  String? eventId;
  String? eventTitle;
  String? status;
  int labelGeneration = 0;
  bool _opening = true;

  @override
  void initState() {
    super.initState();
    eventId = widget.eventId;
    eventTitle = widget.eventTitle;
    Future.microtask(() {
      if (mounted && widget.active) _reloadOnEntry();
    });
  }

  Future<void> _reloadOnEntry() async {
    if (!mounted || !widget.active) return;
    setState(() => _opening = true);
    final controller = ref.read(provider.notifier);
    await controller.filter(eventId: eventId, status: status);
    if (!mounted) return;
    setState(() => _opening = false);
    resolveTitle(refresh: true);
  }

  Future<void> resolveTitle({bool refresh = false}) async {
    final generation = ++labelGeneration;
    final id = eventId;
    if (id == null || (!refresh && eventTitle != null)) return;
    try {
      final event =
          (await ref.read(arenaApiProvider).getEventsApi().callGet(id: id))
              .data;
      if (mounted && generation == labelGeneration && eventId == id) {
        setState(() => eventTitle = event?.title);
      }
    } catch (_) {
      // Keep the selected ID visible when its title cannot be loaded.
    }
  }

  @override
  void didUpdateWidget(covariant BookingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filterRevision != oldWidget.filterRevision) {
      eventId = widget.eventId;
      eventTitle = widget.eventTitle;
      status = null;
      _opening = true;
      Future.microtask(_reloadOnEntry);
    } else if (widget.active && !oldWidget.active) {
      _opening = true;
      Future.microtask(_reloadOnEntry);
    }
  }

  void applyFilters() =>
      ref.read(provider.notifier).filter(eventId: eventId, status: status);

  Future<void> chooseEvent() async {
    final selection = await showModalBottomSheet<BookingEventSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .85,
        child: BookingEventPicker(
          selectedId: eventId,
          selectedTitle: eventTitle,
        ),
      ),
    );
    if (!mounted || selection == null) return;
    labelGeneration++;
    setState(() {
      eventId = selection.id;
      eventTitle = selection.title;
    });
    applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(provider);
    final state = _opening
        ? PagedListState<BookingResponse>(loading: true)
        : loaded;
    final controller = ref.read(provider.notifier);
    ref.listen(provider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        showErrorFeedback(context, next.error!);
      }
    });
    ref.listen(apiBaseUrlProvider, (previous, next) {
      if (previous != next) controller.refresh(reset: true);
    });
    ref.listen(authProvider, (previous, next) {
      if (next.session != null && previous?.session != next.session) {
        controller.refresh(reset: true);
      }
    });
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('Filters', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: chooseEvent,
            icon: const Icon(Icons.filter_list),
            label: Text(
              eventId == null
                  ? 'All events'
                  : 'Event: ${eventTitle ?? eventId}',
            ),
          ),
          if (eventId != null)
            TextButton(
              onPressed: () {
                labelGeneration++;
                setState(() {
                  eventId = null;
                  eventTitle = null;
                });
                applyFilters();
              },
              child: const Text('Clear event filter'),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(status),
            initialValue: status ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Booking status'),
            items: [
              for (final value in ['', 'CONFIRMED', 'CANCELLED'])
                DropdownMenuItem(
                  value: value,
                  child: Text(value.isEmpty ? 'All statuses' : value),
                ),
            ],
            onChanged: (value) {
              setState(() => status = value == '' ? null : value);
              applyFilters();
            },
          ),
          const SizedBox(height: 20),
          if (state.items.isEmpty && !state.loading && state.error == null)
            const Card(
              child: FeedbackPanel(
                title: 'No bookings match these filters.',
                message: 'Try another event or booking status.',
              ),
            ),
          for (final booking in state.items)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) =>
                          BookingDetailScreen(bookingId: booking.id),
                    ),
                  );
                  if (mounted && widget.active) await _reloadOnEntry();
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: BookingSummary(booking: booking),
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
    );
  }
}
