import 'package:arena_api/arena_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_providers.dart';
import '../../shared/paged_list.dart';
import '../../shared/feedback_panel.dart';
import '../../shared/status_badge.dart';
import 'event_detail_screen.dart';
import 'event_form.dart';

class EventsController extends PagedListController<EventResponse> {
  String? sport, status;
  @override
  String itemId(EventResponse item) => item.id;
  @override
  Future<PageResult<EventResponse>> fetchPage(
    int page,
    int size,
    CancelToken cancelToken,
  ) async {
    final data =
        (await ref
                .read(arenaApiProvider)
                .getEventsApi()
                .list(
                  sport: sport,
                  status: status,
                  page: page,
                  size: size,
                  cancelToken: cancelToken,
                ))
            .data!;
    return PageResult(
      items: data.items.toList(),
      page: data.page,
      size: data.size,
      totalElements: data.totalElements,
      totalPages: data.totalPages,
    );
  }

  Future<void> filter(String sportValue, String? statusValue) {
    sport = sportValue.trim().isEmpty ? null : sportValue.trim();
    status = statusValue;
    return refresh(reset: true);
  }
}

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key, this.onViewBookings, this.active = true});
  final ValueChanged<EventResponse>? onViewBookings;
  final bool active;
  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final _provider =
      NotifierProvider.autoDispose<
        EventsController,
        PagedListState<EventResponse>
      >(EventsController.new);
  final _sport = TextEditingController();
  String? _status;
  bool _opening = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) _reloadOnEntry();
    });
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _opening = true;
      Future.microtask(_reloadOnEntry);
    }
  }

  Future<void> _reloadOnEntry() async {
    if (!mounted || !widget.active) return;
    setState(() => _opening = true);
    await ref.read(_provider.notifier).filter(_sport.text, _status);
    if (mounted) setState(() => _opening = false);
  }

  @override
  void dispose() {
    _sport.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (mounted && widget.active) await _reloadOnEntry();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(_provider.notifier);
    final loaded = ref.watch(_provider);
    final stateToUse = _opening
        ? PagedListState<EventResponse>(loading: true)
        : loaded;
    ref.listen(_provider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        showErrorFeedback(context, next.error!);
      }
    });
    final signedIn = ref.watch(authProvider).session != null;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _sport,
                  decoration: const InputDecoration(
                    labelText: 'Filter by sport',
                  ),
                  onSubmitted: (_) => controller.filter(_sport.text, _status),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: _status ?? '',
                  items: [
                    for (final status in [
                      '',
                      'SCHEDULED',
                      'LIVE',
                      'COMPLETED',
                      'CANCELLED',
                    ])
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.isEmpty ? 'All statuses' : status),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _status = value == '' ? null : value);
                    controller.filter(_sport.text, _status);
                  },
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => controller.filter(_sport.text, _status),
                      child: const Text('Apply'),
                    ),
                    FilledButton.icon(
                      onPressed: !signedIn
                          ? null
                          : () {
                              if (ref.read(authProvider).session == null ||
                                  ref
                                          .read(authProvider.notifier)
                                          .tokenFor(
                                            ref.read(apiBaseUrlProvider),
                                          ) ==
                                      null) {
                                return;
                              }
                              _open(const EventFormScreen());
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (stateToUse.items.isEmpty &&
              !stateToUse.loading &&
              stateToUse.error == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No events found.'),
            ),
          for (final event in stateToUse.items)
            Card(
              child: ListTile(
                title: Text(event.title),
                subtitle: Text(
                  '${event.sport} · ${event.location}\n${event.startsAt.toLocal()}\nTotal capacity: ${event.capacity}',
                ),
                trailing: StatusBadge(status: event.status.name),
                onTap: () => _open(
                  EventDetailScreen(
                    event: event,
                    onViewBookings: widget.onViewBookings,
                  ),
                ),
              ),
            ),
          PagedListFooter(
            state: stateToUse,
            onLoadMore: controller.loadMore,
            onRetry: controller.retry,
          ),
        ],
      ),
    );
  }
}
