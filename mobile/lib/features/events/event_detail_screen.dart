import 'package:arena_api/arena_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/app_providers.dart';
import '../../shared/confirm_action.dart';
import '../../shared/feedback_panel.dart';
import '../../shared/page_title.dart';
import '../../shared/status_badge.dart';
import 'event_form.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    this.onViewBookings,
  });
  final EventResponse event;
  final ValueChanged<EventResponse>? onViewBookings;
  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  late EventResponse _event = widget.event;
  bool _busy = false, _changed = false, _allowPop = false;
  bool _loaded = false;
  String? _loadError, _actionError;
  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted || _busy) return;
    setState(() {
      _busy = true;
      _loaded = false;
      _loadError = null;
    });
    try {
      final event =
          (await ref
                  .read(arenaApiProvider)
                  .getEventsApi()
                  .callGet(id: _event.id))
              .data!;
      if (mounted) {
        setState(() {
          _event = event;
          _loaded = true;
          _loadError = null;
          _actionError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = describeApiError(error).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _authorized() {
    if (ref.read(authProvider).session != null &&
        ref
                .read(authProvider.notifier)
                .tokenFor(ref.read(apiBaseUrlProvider)) !=
            null) {
      return true;
    }
    setState(() => _actionError = 'Sign in again to continue.');
    showErrorFeedback(context, _actionError!);
    return false;
  }

  Future<void> _mutate(String? status) async {
    if (_busy || !_authorized()) return;
    final confirmed = await confirmAction(
      context,
      title: status == null ? 'Delete event?' : 'Change status to $status?',
      message: status == null
          ? 'This permanently deletes the event. Events with booking history cannot be deleted.'
          : 'This lifecycle change cannot be undone.',
      confirmLabel: status == null ? 'Delete' : 'Change status',
    );
    if (!mounted || !confirmed || !_authorized() || _busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final api = ref.read(arenaApiProvider).getEventsApi();
      if (status == null) {
        await api.delete(id: _event.id);
        if (mounted) {
          setState(() => _allowPop = true);
          Navigator.pop(context, true);
        }
      } else {
        final event = (await api.changeStatus(
          id: _event.id,
          eventStatusRequest: EventStatusRequest(
            (b) => b..status = EventStatusRequestStatusEnum.valueOf(status),
          ),
        )).data!;
        if (mounted) {
          setState(() {
            _event = event;
            _changed = true;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = describeApiError(error).message);
        showErrorFeedback(context, _actionError!);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    if (!_authorized() ||
        _busy ||
        _event.status != EventResponseStatusEnum.SCHEDULED) {
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EventFormScreen(event: _event)),
    );
    if (changed == true && mounted) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAct =
        !_busy && _loadError == null && ref.watch(authProvider).session != null;
    final transitions = switch (_event.status.name) {
      'SCHEDULED' => ['LIVE', 'CANCELLED'],
      'LIVE' => ['COMPLETED', 'CANCELLED'],
      _ => <String>[],
    };
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && (!_busy || !_loaded)) {
          setState(() => _allowPop = true);
          Navigator.pop(context, _changed);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const PageTitle(
            title: 'Event details',
            icon: Icons.event_outlined,
          ),
        ),
        body: !_loaded
            ? Center(
                child: _loadError != null
                    ? FeedbackPanel(
                        title: 'Unable to load event',
                        message: _loadError,
                        onRetry: _busy ? null : _load,
                      )
                    : const CircularProgressIndicator(
                        semanticsLabel: 'Loading event',
                      ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _event.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(status: _event.status.name),
                  ),
                  for (final entry in {
                    'ID': _event.id,
                    'Sport': _event.sport,
                    'Location': _event.location,
                    'Description': _event.description ?? '—',
                    'Start (local)': _event.startsAt.toLocal().toString(),
                    'End (local)': _event.endsAt.toLocal().toString(),
                    'Total capacity': '${_event.capacity}',
                    'Created': _event.createdAt.toLocal().toString(),
                    'Updated': _event.updatedAt.toLocal().toString(),
                  }.entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.key),
                      subtitle: SelectableText(entry.value),
                    ),
                  if (widget.onViewBookings != null)
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              Navigator.pop(context, _changed);
                              widget.onViewBookings!(_event);
                            },
                      child: const Text('View bookings'),
                    ),
                  if (_event.status == EventResponseStatusEnum.SCHEDULED)
                    FilledButton(
                      onPressed: canAct ? _edit : null,
                      child: const Text('Edit'),
                    ),
                  for (final status in transitions)
                    OutlinedButton(
                      onPressed: canAct ? () => _mutate(status) : null,
                      child: Text('Change to $status'),
                    ),
                  TextButton(
                    onPressed: canAct ? () => _mutate(null) : null,
                    child: const Text('Delete event'),
                  ),
                  if (_actionError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_actionError!),
                      ),
                    ),
                  if (_busy) const Center(child: CircularProgressIndicator()),
                ],
              ),
      ),
    );
  }
}
