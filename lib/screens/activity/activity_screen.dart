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
import '../dashboard/event_dashboard_screen.dart';
import '../events/create_edit_event_screen.dart';
import '../events/event_details_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _eventService = EventService.instance;

  List<AttendingEventSummary> _attending = [];
  List<EventModel> _organizing = [];
  bool _isLoading = true;
  String? _loadedForUserId;
  int _loadedForVersion = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // NOTE: deliberately not calling _load() here. This screen is built
    // immediately on login (HomeShell builds all 4 tabs at once via
    // IndexedStack, so tab-switching is instant), which is often before
    // AuthProvider has finished fetching the profile from Supabase in the
    // background. Calling _load() here would frequently find userId still
    // null, bail out, and leave the spinner stuck forever with no retry.
    // Instead, build() below watches for the profile to become available
    // and triggers the load then — see _maybeLoad().
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Called from build() once the profile is available. Reloads whenever
  /// the user changes OR the global DataRefreshProvider version bumps
  /// (meaning something elsewhere — a registration, a new event, a
  /// deletion — may have changed what this screen should show).
  void _maybeLoad(String userId, int refreshVersion) {
    if (_loadedForUserId == userId && _loadedForVersion == refreshVersion) {
      return;
    }
    _loadedForUserId = userId;
    _loadedForVersion = refreshVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId == null) {
      // Still not available — stop spinning rather than hang forever.
      // _maybeLoad will retry automatically once the profile does load,
      // since build() re-checks on every AuthProvider change.
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final attendingFuture = RegistrationService.instance
          .fetchAttendingSummaries(userId, upcomingOnly: true);
      final organizingFuture = _eventService.fetchOrganizedEvents(userId);

      final attending = await attendingFuture;
      final organizing = await organizingFuture;

      setState(() {
        _attending = attending;
        _organizing = organizing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final refreshVersion = context.watch<DataRefreshProvider>().version;
    if (profile != null) {
      _maybeLoad(profile.id, refreshVersion);
    }
    return Scaffold(
      appBar: const MawidTopBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Attending'),
                  Tab(text: 'Organizing'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
              controller: _tabController,
              children: [
                _AttendingTab(summaries: _attending, onRefresh: _load),
                _OrganizingTab(events: _organizing, onRefresh: _load),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendingTab extends StatelessWidget {
  final List<AttendingEventSummary> summaries;
  final Future<void> Function() onRefresh;

  const _AttendingTab({required this.summaries, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 100),
            Center(
              child: Text(
                "You haven't registered for any upcoming events yet.",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: summaries
            .map((s) => EventCard(
          event: s.event,
          trailingBadge:
          s.ticketCount > 1 ? '${s.ticketCount} TICKETS' : null,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EventDetailsScreen(eventId: s.event.id),
            ),
          ),
        ))
            .toList(),
      ),
    );
  }
}

class _OrganizingTab extends StatelessWidget {
  final List<EventModel> events;
  final Future<void> Function() onRefresh;

  const _OrganizingTab({required this.events, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final published = events.where((e) => e.status == 'published').length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard('${events.length}', 'Total events'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard('$published', 'Active events', filled: true),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Your Events',
                  style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New'),
                onPressed: () async {
                  final changed = await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const CreateEditEventScreen()),
                  );
                  if (changed == true) onRefresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  "You haven't created any events yet.",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...events.map((e) => _OrganizedEventTile(event: e, onRefresh: onRefresh)),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: filled ? AppColors.accent : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: filled ? Colors.white : AppColors.textPrimary,
              )),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: filled ? Colors.white70 : AppColors.textSecondary,
              )),
        ],
      ),
    );
  }
}

class _OrganizedEventTile extends StatelessWidget {
  final EventModel event;
  final Future<void> Function() onRefresh;
  const _OrganizedEventTile({required this.event, required this.onRefresh});

  Future<void> _handleDelete(BuildContext context) async {
    // Check for real registrations first so the warning is accurate —
    // deleting an event cascades to delete every registration tied to it.
    List<Map<String, dynamic>> registrants = [];
    try {
      registrants =
      await RegistrationService.instance.fetchRegistrantsForEvent(event.id);
    } catch (_) {
      // If this check fails, fall through to a generic (still honest)
      // warning rather than blocking deletion entirely.
    }
    final count = registrants.length;

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete this event?'),
        content: Text(
          count > 0
              ? 'This event has $count ${count == 1 ? "registration" : "registrations"}. Deleting it will permanently remove all attendee tickets too. This cannot be undone.'
              : 'This will permanently delete the event and its ticket types. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.statusDanger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await EventService.instance.deleteEvent(event.id);
      if (context.mounted) context.read<DataRefreshProvider>().bump();
      await onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (event.status) {
      'published' => AppColors.accent,
      'cancelled' => AppColors.statusDanger,
      _ => AppColors.textSecondary, // draft
    };

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventDashboardScreen(eventId: event.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                image: event.coverImageUrl != null
                    ? DecorationImage(
                    image: NetworkImage(event.coverImageUrl!),
                    fit: BoxFit.cover)
                    : null,
              ),
              child: event.coverImageUrl == null
                  ? const Icon(Icons.event, color: AppColors.textMuted)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      event.status[0].toUpperCase() + event.status.substring(1),
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
              color: AppColors.surfaceElevated,
              onSelected: (value) async {
                if (value == 'edit') {
                  final changed = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CreateEditEventScreen(eventId: event.id),
                    ),
                  );
                  if (changed == true) onRefresh();
                } else if (value == 'delete') {
                  _handleDelete(context);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: AppColors.statusDanger),
                      SizedBox(width: 10),
                      Text('Delete',
                          style: TextStyle(color: AppColors.statusDanger)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}