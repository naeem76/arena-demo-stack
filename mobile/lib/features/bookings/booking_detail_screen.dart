import 'dart:async';

import 'package:arena_api/arena_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/app_providers.dart';
import '../../shared/confirm_action.dart';
import '../../shared/feedback_panel.dart';
import '../../shared/page_title.dart';
import 'booking_data.dart';
import 'booking_summary.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen>
    with WidgetsBindingObserver {
  BookingResponse? booking;
  String? loadError;
  String? cancelError;
  bool loading = false;
  bool busy = false;
  bool cancelling = false;
  bool changed = false;
  int generation = 0;
  CancelToken? request;
  Timer? startTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(load);
  }

  @override
  void dispose() {
    generation++;
    request?.cancel();
    startTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void updateBooking(BookingResponse value) {
    booking = value;
    startTimer?.cancel();
    final delay = value.event.startsAt.difference(
      ref.read(bookingClockProvider)(),
    );
    if (delay > Duration.zero) {
      startTimer = Timer(delay, () {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> load() async {
    if (!mounted) return;
    final current = ++generation;
    request?.cancel();
    final token = request = CancelToken();
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final result =
          (await ref
                  .read(arenaApiProvider)
                  .getBookingsApi()
                  .get1(id: widget.bookingId, cancelToken: token))
              .data!;
      if (mounted && current == generation) {
        setState(() => updateBooking(result));
      }
    } catch (error) {
      if (mounted && current == generation && !token.isCancelled) {
        setState(() => loadError = describeApiError(error).message);
      }
    } finally {
      if (mounted && current == generation) setState(() => loading = false);
    }
  }

  Future<void> cancelBooking() async {
    final record = booking;
    if (busy || loading || record == null) return;
    final origin = ref.read(apiBaseUrlProvider);
    final session = ref.read(authProvider).session;
    bool authorized() {
      final token = ref.read(authProvider.notifier).tokenFor(origin);
      final latest = ref.read(authProvider).session;
      return token != null &&
          session != null &&
          latest != null &&
          ref.read(apiBaseUrlProvider) == origin &&
          latest.origin == session.origin &&
          latest.issuer == session.issuer &&
          latest.sub == session.sub;
    }

    if (!authorized()) {
      setState(() => cancelError = 'Sign in again to cancel this booking.');
      return;
    }
    if (!canCancelBooking(record, ref.read(bookingClockProvider)())) {
      setState(() => cancelError = 'This booking can no longer be cancelled.');
      return;
    }
    final current = generation;
    setState(() {
      busy = true;
      cancelError = null;
    });
    try {
      final confirmed = await confirmAction(
        context,
        title: 'Cancel booking?',
        message:
            'Cancel ${record.participant.displayName}’s booking for ${record.event.title}? The booking history will be retained.',
        confirmLabel: 'Cancel booking',
        dismissLabel: 'Keep booking',
        destructive: true,
      );
      if (!mounted || current != generation || !confirmed) return;
      if (!authorized()) {
        setState(() => cancelError = 'Sign in again to cancel this booking.');
        return;
      }
      if (booking == null ||
          !canCancelBooking(booking!, ref.read(bookingClockProvider)())) {
        setState(
          () => cancelError = 'This booking can no longer be cancelled.',
        );
        return;
      }
      final token = request = CancelToken();
      setState(() => cancelling = true);
      try {
        final result =
            (await ref
                    .read(arenaApiProvider)
                    .getBookingsApi()
                    .cancel(id: widget.bookingId, cancelToken: token))
                .data!;
        if (mounted && current == generation) {
          setState(() {
            updateBooking(result);
            changed = true;
          });
        }
      } catch (error) {
        if (!mounted || current != generation || token.isCancelled) return;
        final safe = describeApiError(error);
        setState(
          () => cancelError = [safe.message, ...safe.fields.values].join('\n'),
        );
        showErrorFeedback(context, cancelError!);
        if (error is DioException && error.response?.statusCode == 409) {
          changed = true;
          await load();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          cancelling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(apiBaseUrlProvider, (previous, next) {
      if (previous != next) {
        setState(() {
          booking = null;
          cancelError = null;
        });
        load();
      }
    });
    ref.listen(authProvider, (previous, next) {
      if (next.session != null && previous?.session != next.session) {
        setState(() => booking = null);
        load();
      }
    });
    final record = booking;
    final eligible =
        record != null &&
        canCancelBooking(record, ref.watch(bookingClockProvider)());
    final signedIn = ref.watch(authProvider).session != null;
    return PopScope<bool>(
      canPop: !busy && !changed,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !busy && changed) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const PageTitle(
            title: 'Booking details',
            icon: Icons.confirmation_number_outlined,
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              if (!busy) await load();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (loading) const LinearProgressIndicator(),
                if (loadError != null)
                  FeedbackPanel(
                    title: 'Unable to load booking',
                    message: loadError,
                    onRetry: busy ? null : load,
                  ),
                if (record != null && !loading && loadError == null)
                  BookingSummary(
                    booking: record,
                    details: true,
                    action: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (cancelError != null)
                          FeedbackPanel(
                            title: 'Unable to cancel booking',
                            message: cancelError,
                            onRetry: eligible && signedIn && !busy && !loading
                                ? cancelBooking
                                : null,
                          ),
                        if (eligible)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .error,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            onPressed: signedIn && !busy && !loading
                                ? cancelBooking
                                : null,
                            icon: const Icon(Icons.cancel_outlined),
                            label: Text(
                              cancelling ? 'Cancelling…' : 'Cancel booking',
                            ),
                          ),
                        if (!eligible && record.status.name == 'CONFIRMED')
                          const Text(
                            'Cancellation is only available before the event starts and while it is not live or completed.',
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
