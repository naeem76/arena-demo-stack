import 'package:arena_api/arena_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_providers.dart';
import 'core/event_drafts.dart';
import 'features/bookings/bookings_screen.dart';
import 'features/events/events_screen.dart';
import 'shared/page_title.dart';

class ArenaApp extends ConsumerStatefulWidget {
  const ArenaApp({super.key});

  @override
  ConsumerState<ArenaApp> createState() => _ArenaAppState();
}

class _ArenaAppState extends ConsumerState<ArenaApp> {
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  String? _owner;
  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    final owner = _owner;
    final drafts = ref.read(eventDraftStoreProvider);
    final auth = ref.read(authProvider.notifier);
    var draftRemovalFailed = false;
    try {
      await Future.wait([
        auth.logout(),
        if (owner != null)
          drafts.removeOwner(owner).catchError((Object _) {
            draftRemovalFailed = true;
          }),
      ]);
      if (mounted && draftRemovalFailed) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Signed out, but local drafts could not be removed.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final endpoint = ref.watch(apiEndpointProvider);
    final auth = ref.watch(authProvider);
    final owner = auth.session == null ? null : draftOwner(auth.session!);
    if (owner != _owner) {
      _owner = owner;
      // Session loss removes every protected route, including pushed editors.
      _navigatorKey = GlobalKey<NavigatorState>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _messengerKey.currentState?.clearSnackBars();
        _messengerKey.currentState?.removeCurrentSnackBar();
      });
    }
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF006E54),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF006E54),
          onPrimary: Colors.white,
          surface: const Color(0xFFF3F5F1),
          onSurface: const Color(0xFF20332B),
          secondaryContainer: const Color(0xFFD8EFDF),
          onSecondaryContainer: const Color(0xFF164A36),
        );

    return MaterialApp(
      title: 'Arena Admin',
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0x1F20332B)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.all(16),
          errorMaxLines: 3,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0x3320332B)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0x3320332B)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
      ),
      home: endpoint.isLoading
          ? const Scaffold(body: Center(child: Text('Looking for local API…')))
          : auth.session != null
          ? _AdminShell(onLogout: _logout)
          : _SignInScreen(enabled: !_loggingOut),
    );
  }
}

class _SignInScreen extends ConsumerWidget {
  const _SignInScreen({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 32).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            child: Icon(
                              Icons.event_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Arena Admin',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        _SignInControls(enabled: enabled),
                        const SizedBox(height: 16),
                        Text(
                          ref.watch(apiBaseUrlProvider),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AdminShell extends ConsumerStatefulWidget {
  const _AdminShell({required this.onLogout});
  final Future<void> Function() onLogout;

  @override
  ConsumerState<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<_AdminShell> {
  int _selectedIndex = 0;
  String? _bookingEventId;
  String? _bookingEventTitle;
  int _filterRevision = 0;

  void _viewBookings(EventResponse event) {
    setState(() {
      _selectedIndex = 1;
      _bookingEventId = event.id;
      _bookingEventTitle = event.title;
      _filterRevision++;
    });
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showAccount() {
    final endpoint = ref.read(apiEndpointProvider).asData?.value;
    showDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) => AlertDialog(
          title: const Text('Account'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SIGNED IN AS',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              Text(
                ref.watch(authProvider).session?.name ?? 'Session ended',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'API ENDPOINT',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              SelectableText(ref.watch(apiBaseUrlProvider)),
              if (endpoint != null) ...[
                const SizedBox(height: 16),
                Text(
                  'CONNECTION SOURCE',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Text('${endpoint.source.name}: ${endpoint.detail}'),
              ],
            ],
          ),
          scrollable: true,
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
              child: const Text('Sign out'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: PageTitle(
        title: _selectedIndex == 0 ? 'Events' : 'Bookings',
        icon: _selectedIndex == 0
            ? Icons.event_outlined
            : Icons.confirmation_number_outlined,
      ),
      actions: [
        IconButton(
          tooltip: 'Account',
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: _showAccount,
        ),
      ],
    ),
    body: SafeArea(
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          TickerMode(
            enabled: _selectedIndex == 0,
            child: EventsScreen(
              active: _selectedIndex == 0,
              onViewBookings: _viewBookings,
            ),
          ),
          TickerMode(
            enabled: _selectedIndex == 1,
            child: BookingsScreen(
              active: _selectedIndex == 1,
              eventId: _bookingEventId,
              eventTitle: _bookingEventTitle,
              filterRevision: _filterRevision,
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.event_outlined),
          selectedIcon: Icon(Icons.event),
          label: 'Events',
        ),
        NavigationDestination(
          icon: Icon(Icons.confirmation_number_outlined),
          selectedIcon: Icon(Icons.confirmation_number),
          label: 'Bookings',
        ),
      ],
    ),
  );
}

class _SignInControls extends ConsumerWidget {
  const _SignInControls({this.enabled = true});
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final busy = auth.busy || !enabled;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (auth.message != null)
          Semantics(liveRegion: true, child: Text(auth.message!)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: busy
              ? null
              : () => ref.read(authProvider.notifier).signIn(),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  auth.differentAccount
                      ? 'Sign in with a different account'
                      : auth.hasSignedIn
                      ? 'Sign in again'
                      : 'Sign in',
                ),
        ),
      ],
    );
  }
}
