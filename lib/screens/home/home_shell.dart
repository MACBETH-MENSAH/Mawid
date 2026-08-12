import 'package:flutter/material.dart';
import '../activity/activity_screen.dart';
import '../events/create_edit_event_screen.dart';
import '../events/events_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

/// The single bottom nav shared by every user — Home, Events, Activity,
/// Profile. No separate attendee/organizer nav, per the account model
/// decision (one account, both capabilities).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  // Bumping these forces the respective tab to rebuild from scratch,
  // which re-triggers its data fetch. Needed because IndexedStack keeps
  // tabs alive in memory — a tab you already visited won't know new data
  // exists (e.g. a newly created event) unless something forces it to
  // reload.
  Key _homeKey = UniqueKey();
  Key _activityKey = UniqueKey();

  void _goToTab(int index) => setState(() => _currentIndex = index);

  Future<void> _openCreateEvent() async {
    final changed = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateEditEventScreen()),
    );
    if (changed == true) {
      setState(() {
        _homeKey = UniqueKey();
        _activityKey = UniqueKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        key: _homeKey,
        onBrowseEvents: () => _goToTab(1),
        onCreateEvent: _openCreateEvent,
      ),
      const EventsScreen(),
      ActivityScreen(key: _activityKey),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _goToTab,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined), label: 'Events'),
          BottomNavigationBarItem(
              icon: Icon(Icons.confirmation_number_outlined),
              label: 'Activity'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}