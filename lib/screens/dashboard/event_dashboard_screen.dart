import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/event.dart';
import '../../models/profile.dart';
import '../../models/registration.dart';
import '../../models/ticket_type.dart';
import '../../providers/data_refresh_provider.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../services/ticket_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mawid_logo.dart';
import '../checkin/checkin_scanner_screen.dart';

class _Registrant {
  final Registration registration;
  final Profile profile;
  final TicketType ticketType;
  _Registrant(this.registration, this.profile, this.ticketType);
}

class EventDashboardScreen extends StatefulWidget {
  final String eventId;
  const EventDashboardScreen({super.key, required this.eventId});

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen> {
  EventModel? _event;
  List<TicketType> _ticketTypes = [];
  List<_Registrant> _registrants = [];
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final event = await EventService.instance.fetchEventById(widget.eventId);
      final ticketTypes =
      await TicketService.instance.fetchTicketTypesForEvent(widget.eventId);
      final rows = await RegistrationService.instance
          .fetchRegistrantsForEvent(widget.eventId);

      final registrants = rows.map((row) {
        final registration = Registration.fromJson(row);
        final profile = Profile.fromJson(row['profiles'] as Map<String, dynamic>);
        final ticketType =
        TicketType.fromJson(row['ticket_types'] as Map<String, dynamic>);
        return _Registrant(registration, profile, ticketType);
      }).toList();

      if (!mounted) return;
      setState(() {
        _event = event;
        _ticketTypes = ticketTypes;
        _registrants = registrants;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this event\'s dashboard.';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIn(_Registrant r) async {
    if (r.registration.isCheckedIn) return;
    await RegistrationService.instance.markCheckedIn(r.registration.id);
    if (mounted) context.read<DataRefreshProvider>().bump();
    _load();
  }

  List<_Registrant> get _filteredRegistrants {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _registrants;
    return _registrants
        .where((r) => r.profile.fullName.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(_error ?? 'Event not found',
              style: const TextStyle(color: AppColors.statusDanger)),
        ),
      );
    }

    final event = _event!;
    final registered = _ticketTypes.fold<int>(0, (s, t) => s + t.quantitySold);
    final capacity = _ticketTypes.fold<int>(0, (s, t) => s + t.quantityAvailable);
    final revenue = _ticketTypes.fold<double>(
        0, (s, t) => s + (t.price * t.quantitySold));
    final checkedIn = _registrants.where((r) => r.registration.isCheckedIn).length;
    final checkInRate = registered == 0 ? 0.0 : checkedIn / registered;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            MawidLogo(size: 22),
            SizedBox(width: 8),
            Text('MAWID'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: event.coverImageUrl != null
                    ? Image.network(event.coverImageUrl!, fit: BoxFit.cover)
                    : Container(color: AppColors.surfaceElevated),
              ),
            ),
            const SizedBox(height: 12),
            Text(event.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Check In Attendee'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CheckinScannerScreen(eventId: event.id),
                  ),
                );
                _load();
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _statBox('$registered / $capacity', 'Registered')),
                const SizedBox(width: 12),
                Expanded(
                    child: _statBox(
                        '\$${revenue.toStringAsFixed(0)}', 'Revenue')),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('CHECKED-IN',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Text('$checkedIn',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: checkInRate,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceElevated,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${(checkInRate * 100).round()}%',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Registrants',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search attendees...',
                prefixIcon: Icon(Icons.search, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 12),
            if (_filteredRegistrants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text('No registrants yet',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ..._filteredRegistrants.map((r) => _RegistrantTile(
                registrant: r,
                onCheckIn: () => _checkIn(r),
              )),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RegistrantTile extends StatelessWidget {
  final _Registrant registrant;
  final VoidCallback onCheckIn;

  const _RegistrantTile({required this.registrant, required this.onCheckIn});

  @override
  Widget build(BuildContext context) {
    final isCheckedIn = registrant.registration.isCheckedIn;
    final isCancelled = registrant.registration.isCancelled;

    final statusColor = isCheckedIn
        ? AppColors.accent
        : (isCancelled ? AppColors.statusDanger : AppColors.statusWarning);
    final statusLabel =
    isCheckedIn ? 'Checked-in' : (isCancelled ? 'Cancelled' : 'Booked');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surfaceElevated,
            child: Text(registrant.profile.initials,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(registrant.profile.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(registrant.ticketType.name,
                    style: const TextStyle(
                        color: AppColors.accent, fontSize: 12)),
              ],
            ),
          ),
          if (!isCheckedIn && !isCancelled)
            TextButton(
              onPressed: onCheckIn,
              child: const Text('Check in'),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }
}