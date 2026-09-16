import 'dart:async';

import 'package:arena_api/arena_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/app_providers.dart';
import '../../core/event_drafts.dart';
import '../../shared/confirm_action.dart';
import '../../shared/page_title.dart';
import '../../shared/feedback_panel.dart';
import '../../shared/local_time.dart';
import 'event_data.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.event});
  final EventResponse? event;
  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen>
    with WidgetsBindingObserver {
  final _controllers = <String, TextEditingController>{};
  final _dates = <String, String>{};
  Map<String, String> _errors = {};
  String? _owner, _message;
  late EventDraftStore _store;
  Timer? _timer;
  bool _ready = false,
      _dirty = false,
      _busy = false,
      _closed = false,
      _allowPop = false;
  bool _discardRequested = false;
  bool _discarding = false;
  String get _eventKey => widget.event?.id ?? 'new';
  Map<String, dynamic> get _values => {
    for (final e in _controllers.entries) e.key: e.value.text,
    ..._dates,
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final e = widget.event;
    final initial = {
      'title': e?.title ?? '',
      'sport': e?.sport ?? '',
      'location': e?.location ?? '',
      'description': e?.description ?? '',
      'capacity': e?.capacity.toString() ?? '',
    };
    for (final entry in initial.entries) {
      _controllers[entry.key] = TextEditingController(text: entry.value)
        ..addListener(_changed);
    }
    _dates.addAll({
      'startsAt': e?.startsAt.toIso8601String() ?? '',
      'endsAt': e?.endsAt.toIso8601String() ?? '',
    });
    _store = ref.read(eventDraftStoreProvider);
    final session = ref.read(authProvider).session;
    _owner = session == null ? null : draftOwner(session);
    _restore();
  }

  Future<void> _restore() async {
    try {
      final draft = _owner == null
          ? null
          : await _store.read(_owner!, _eventKey);
      if (!mounted) return;
      if (draft != null) {
        for (final key in _controllers.keys) {
          if (draft[key] is String) {
            _controllers[key]!.text = draft[key] as String;
          }
        }
        for (final key in _dates.keys.toList()) {
          if (draft[key] is String) _dates[key] = draft[key] as String;
        }
        _dirty = true;
      }
    } catch (_) {
      _message = 'Could not restore the saved draft. Your input will stay on this screen.';
    }
    if (mounted) setState(() => _ready = true);
  }

  void _changed() {
    if (!_ready || _closed) return;
    setState(() {
      _dirty = true;
      _errors = {};
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), _flush);
  }

  Future<void> _flush() async {
    _timer?.cancel();
    if (!_dirty || _closed || _discarding || _owner == null) return;
    try {
      await _store.write(_owner!, _eventKey, _values);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Draft could not be stored. Keep this screen open and try again.',
        );
      }
    }
  }

  bool _authorized() {
    final session = ref.read(authProvider).session;
    final token = ref
        .read(authProvider.notifier)
        .tokenFor(ref.read(apiBaseUrlProvider));
    if (session != null && token != null && draftOwner(session) == _owner) {
      return true;
    }
    setState(
      () => _message = 'Sign in again with the same account to continue.',
    );
    return false;
  }

  Future<void> _save() async {
    if (_busy || _closed || !_authorized()) return;
    if (widget.event != null && !canEditEvent(widget.event!.status)) {
      setState(() => _message = 'Only scheduled events can be edited.');
      return;
    }
    final errors = validateEventValues(_values, creating: widget.event == null);
    setState(() {
      _errors = errors;
      _message = null;
    });
    if (errors.isNotEmpty) {
      showErrorFeedback(context, 'Check the highlighted fields.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _flush();
      if (!mounted || !_authorized()) return;
      final api = ref.read(arenaApiProvider).getEventsApi();
      final request = eventRequestFromValues(_values);
      if (widget.event == null) {
        await api.create(eventRequest: request);
      } else {
        await api.update(id: widget.event!.id, eventRequest: request);
      }
      _closed = true;
      _timer?.cancel();
      try {
        await _store.remove(_owner!, _eventKey);
      } catch (_) {
        if (mounted) {
          setState(
            () => _message = 'Event saved, but the stored draft could not be removed. Use Discard to retry cleanup.',
          );
        }
        return;
      }
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context, true);
      }
    } catch (error) {
      final safe = describeApiError(error);
      if (mounted) {
        setState(() {
          _message = safe.message;
          _errors = safe.fields;
        });
        showErrorFeedback(context, safe.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _discardRequested = true;
    });
    try {
      await _flush();
      if (!mounted) return;
      if (!await confirmAction(
        context,
        title: 'Discard event draft?',
        message: 'Your unsaved changes will be permanently removed.',
        confirmLabel: 'Discard',
        destructive: true,
      )) {
        return;
      }
      if (!mounted) return;
      _timer?.cancel();
      setState(() => _discarding = true);
      if (_owner != null) await _store.remove(_owner!, _eventKey);
      if (!mounted) return;
      final saved = _closed;
      _closed = true;
      setState(() => _allowPop = true);
      Navigator.pop(context, saved);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not remove the draft. Please try Discard again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _discardRequested = false;
          _discarding = false;
        });
      }
    }
  }

  Future<void> _pick(String key) async {
    final old = DateTime.tryParse(_dates[key]!)?.toLocal() ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: old,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(old),
    );
    if (time == null || !mounted) return;
    _dates[key] = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).toUtc().toIso8601String();
    _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) unawaited(_flush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_flush());
    _timer?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_busy),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_busy) _discard();
    },
    child: Scaffold(
      appBar: AppBar(
        title: PageTitle(
          title: widget.event == null ? 'Create event' : 'Edit event',
          icon: Icons.event_outlined,
        ),
      ),
      body: SafeArea(
        child: !_ready
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  Text(
                    'Event information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  for (final entry in _controllers.entries) ...[
                    if (entry.key == 'capacity') ...[
                      const SizedBox(height: 8),
                      Text(
                        'Schedule & capacity',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextField(
                        controller: entry.value,
                        enabled: !_busy && !_closed,
                        decoration: InputDecoration(
                          labelText: entry.key == 'capacity'
                              ? 'Total capacity'
                              : '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                          helperText: entry.key == 'description'
                              ? 'Optional'
                              : null,
                          alignLabelWithHint: entry.key == 'description',
                          errorText: _errors[entry.key],
                          errorMaxLines: 3,
                        ),
                        keyboardType: entry.key == 'capacity'
                            ? TextInputType.number
                            : entry.key == 'description'
                            ? TextInputType.multiline
                            : TextInputType.text,
                        maxLines: entry.key == 'description' ? 3 : 1,
                      ),
                    ),
                  ],
                  for (final key in _dates.keys)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Semantics(
                        button: true,
                        enabled: !_busy && !_closed,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _busy || _closed ? null : () => _pick(key),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: key == 'startsAt'
                                  ? 'Start (local time)'
                                  : 'End (local time)',
                              errorText: _errors[key],
                              errorMaxLines: 3,
                              enabled: !_busy && !_closed,
                              suffixIcon: const Icon(
                                Icons.calendar_today_outlined,
                              ),
                            ),
                            child: Text(
                              DateTime.tryParse(_dates[key]!) == null
                                  ? 'Choose date and time'
                                  : localTime(
                                      context,
                                      DateTime.parse(_dates[key]!),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy || _closed ? null : _save,
                    child: Text(
                      _busy && !_discardRequested ? 'Saving…' : 'Save',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _busy ? null : _discard,
                    child: Text(_discarding ? 'Discarding…' : 'Discard'),
                  ),
                ],
              ),
      ),
    ),
  );
}
