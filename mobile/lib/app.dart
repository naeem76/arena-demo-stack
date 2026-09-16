import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_providers.dart';
import 'features/bookings/bookings_screen.dart';
import 'features/events/events_screen.dart';

class ArenaApp extends ConsumerWidget {
  const ArenaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endpoint = ref.watch(apiEndpointProvider);

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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: colors),
      home: endpoint.isLoading
          ? const Scaffold(body: Center(child: Text('Looking for local API…')))
          : const _AdminShell(),
    );
  }
}

class _AdminShell extends ConsumerStatefulWidget {
  const _AdminShell();

  @override
  ConsumerState<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<_AdminShell> {
  int _selectedIndex = 0;

  void _showAccount() {
    final endpoint = ref.read(apiEndpointProvider).asData?.value;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Sign-in is not configured yet.'),
            const SizedBox(height: 12),
            Text(ref.read(apiBaseUrlProvider)),
            if (endpoint != null)
              Text('${endpoint.source.name}: ${endpoint.detail}'),
          ],
        ),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Events' : 'Bookings'),
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
          children: const [EventsScreen(), BookingsScreen()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
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
}
