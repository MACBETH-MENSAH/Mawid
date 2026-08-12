import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_refresh_provider.dart';
import '../../services/event_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/event_card.dart';
import '../../widgets/mawid_top_bar.dart';
import '../events/create_edit_event_screen.dart';
import '../events/event_details_screen.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_refresh_provider.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/event_card.dart';
import '../../widgets/mawid_top_bar.dart';
import '../events/create_edit_event_screen.dart';
import '../events/event_details_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onBrowseEvents;
  final VoidCallback onCreateEvent;

  const HomeScreen({
    super.key,
    required this.onBrowseEvents,
    required this.onCreateEvent,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _eventService = EventService.instance;

  List<AttendingEventSummary> _upcoming = [];
  List<EventModel> _discover = [];
  bool _isLoading = true;
  String? _error;
  String? _loadedForUserId;
  int _loadedForVersion = -1;

  @override
  void initState() {
    super.initState();
    // Deliberately not loading here — see the matching comment in
    // activity_screen.dart. This screen can build before the profile has
    // finished loading, and it needs to reload whenever DataRefreshProvider
    // signals a change (new registration, new/edited/deleted event)
    // elsewhere in the app. build() below handles both via _maybeLoad.
  }

  void _maybeLoad(String? userId, int refreshVersion) {
    final key = userId ?? 'guest';
    if (_loadedForUserId == key && _loadedForVersion == refreshVersion) {
      return;
    }
    _loadedForUserId = key;
    _loadedForVersion = refreshVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final userId = context.read<AuthProvider>().profile?.id;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Kick off both requests before awaiting either, so they run
      // concurrently rather than one after another.
      final summariesFuture = userId != null
          ? RegistrationService.instance
          .fetchAttendingSummaries(userId, upcomingOnly: true)
          : Future.value(<AttendingEventSummary>[]);
      final discoverFuture = _eventService.fetchPublishedEvents();

      final summaries = await summariesFuture;
      final discover = await discoverFuture;

      setState(() {
        _upcoming = summaries;
        _discover = discover;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load events. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final refreshVersion = context.watch<DataRefreshProvider>().version;
    final firstName = (profile?.fullName ?? '').split(' ').first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'GOOD MORNING'
        : (hour < 17 ? 'GOOD AFTERNOON' : 'GOOD EVENING');
    _maybeLoad(profile?.id, refreshVersion);

    return Scaffold(
      appBar: const MawidTopBar(),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              greeting,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              firstName.isEmpty ? 'Welcome back' : 'Welcome back, $firstName',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              readOnly: true,
              onTap: widget.onBrowseEvents,
              decoration: InputDecoration(
                hintText: 'Search events...',
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.explore_outlined,
                    label: 'Browse events',
                    filled: true,
                    onTap: widget.onBrowseEvents,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.add,
                    label: 'Create event',
                    filled: false,
                    onTap: widget.onCreateEvent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.statusDanger)),
                ),
              if (_upcoming.isNotEmpty) ...[
                const Text(
                  'My upcoming events',
                  style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  // Compact cards (no description) fit comfortably in
                  // this height; the old non-compact card plus its own
                  // bottom margin didn't fit in 230 and overflowed.
                  height: 250,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _upcoming.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final summary = _upcoming[i];
                      return SizedBox(
                        width: 220,
                        child: EventCard(
                          event: summary.event,
                          compact: true,
                          margin: EdgeInsets.zero,
                          trailingBadge: summary.ticketCount > 1
                              ? '${summary.ticketCount} TICKETS'
                              : null,
                          onTap: () => _openEvent(summary.event),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
              ],
              const Text(
                'Discover events',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_discover.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No events yet. Be the first to create one!',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ..._discover.map(
                      (e) => EventCard(event: e, onTap: () => _openEvent(e)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _openEvent(EventModel event) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventDetailsScreen(eventId: event.id)),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: filled ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: filled ? Colors.white : AppColors.textPrimary,
                size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}