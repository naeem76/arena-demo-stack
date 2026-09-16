import 'package:flutter/material.dart';

import 'features/bookings/bookings_screen.dart';
import 'features/events/events_screen.dart';

class ArenaApp extends StatelessWidget {
  const ArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const _AdminShell(),
    );
  }
}

class _AdminShell extends StatefulWidget {
  const _AdminShell();

  @override
  State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  int _selectedIndex = 0;

  void _showAccount() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account'),
        content: const Text('Sign-in is not configured yet.'),
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
