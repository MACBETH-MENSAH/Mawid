import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/event.dart';
import '../../models/registration.dart';
import '../../models/ticket_selection.dart';
import '../../models/ticket_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_refresh_provider.dart';
import '../../services/event_service.dart';
import '../../services/registration_service.dart';
import '../../services/ticket_service.dart';
import '../../theme/app_colors.dart';
import '../booking/booking_confirmation_screen.dart';
import '../dashboard/event_dashboard_screen.dart';
import '../tickets/ticket_detail_screen.dart';
import 'create_edit_event_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final String eventId;
  const EventDetailsScreen({super.key, required this.eventId});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  EventModel? _event;
  List<TicketType> _ticketTypes = [];
  List<(Registration, TicketType)> _myTickets = [];

  /// ticketTypeId -> quantity the user currently has selected to buy.
  /// Lets someone pick different quantities across multiple ticket types
  /// in one checkout, instead of being locked to exactly one type at
  /// quantity 1.
  final Map<String, int> _quantities = {};

  bool _isLoading = true;
  String? _error;
  late int _loadedForVersion;

  @override
  void initState() {
    super.initState();
    // Baseline the version we've loaded at, so build()'s watch only
    // reacts to CHANGES after this point, not the very first build.
    _loadedForVersion = context.read<DataRefreshProvider>().version;
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = context.read<AuthProvider>().profile?.id;

      final event = await EventService.instance.fetchEventById(widget.eventId);
      final ticketTypes =
      await TicketService.instance.fetchTicketTypesForEvent(widget.eventId);
      final myTickets = userId != null
          ? await RegistrationService.instance
          .fetchUserRegistrationsForEvent(userId, widget.eventId)
          : <(Registration, TicketType)>[];

      if (!mounted) return;
      setState(() {
        _event = event;
        _ticketTypes = ticketTypes;
        _myTickets = myTickets;

        // Preserve existing selections across a reload (e.g. triggered by
        // someone else's registration bumping the global refresh signal)
        // instead of wiping out what the user was mid-way through picking
        // — just clamp each selection down if stock shrank below it.
        final validIds = ticketTypes.map((t) => t.id).toSet();
        _quantities.removeWhere((id, _) => !validIds.contains(id));
        for (final t in ticketTypes) {
          final current = _quantities[t.id] ?? 0;
          _quantities[t.id] = current.clamp(0, t.remaining);
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this event.';
        _isLoading = false;
      });
    }
  }

  void _setQuantity(TicketType ticketType, int quantity) {
    setState(() {
      _quantities[ticketType.id] = quantity.clamp(0, ticketType.remaining);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reload whenever something changes elsewhere in the app (a
    // registration — including someone else's — a ticket-type edit,
    // etc.) so ticket counts here don't go stale until a manual refresh.
    final refreshVersion = context.watch<DataRefreshProvider>().version;
    if (refreshVersion != _loadedForVersion) {
      _loadedForVersion = refreshVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

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
    final currentUserId = context.watch<AuthProvider>().profile?.id;
    final isOrganizer = currentUserId != null && event.isOrganizedBy(currentUserId);
    final isPast = event.startDate.isBefore(DateTime.now());
    final dateFormat = DateFormat('EEEE, MMM d, yyyy');

    final totalQuantity = _quantities.values.fold<int>(0, (a, b) => a + b);
    final totalPrice = _ticketTypes.fold<double>(
      0,
          (sum, t) => sum + t.price * (_quantities[t.id] ?? 0),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black45,
                child: Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: event.coverImageUrl != null
                  ? CachedNetworkImage(
                imageUrl: event.coverImageUrl!,
                fit: BoxFit.cover,
              )
                  : Container(color: AppColors.surfaceElevated),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (event.category != null)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.category!.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(event.title,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                if (isOrganizer) _OrganizerStatsRow(ticketTypes: _ticketTypes),

                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.calendar_today,
                  title: 'Date & time',
                  subtitle: dateFormat.format(event.startDate),
                ),
                if (event.venue != null)
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    title: 'Venue',
                    subtitle: event.venue!,
                  ),
                const SizedBox(height: 16),
                const Text('About this event',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  event.description ?? 'No description provided.',
                  style: const TextStyle(
                      color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 24),

                // "Your tickets" — this is what makes an already-purchased
                // ticket reachable again. Without this, a user who already
                // registered only ever saw an option to buy another one.
                if (!isOrganizer && _myTickets.isNotEmpty) ...[
                  Text('Your tickets (${_myTickets.length})',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._myTickets.map((pair) {
                    final (registration, ticketType) = pair;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.confirmation_number,
                              color: AppColors.accent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ticketType.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(
                                  registration.isCheckedIn
                                      ? 'Checked in'
                                      : 'Code: ${registration.ticketCode.toUpperCase()}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TicketDetailScreen(
                                  registration: registration,
                                  event: event,
                                  ticketType: ticketType,
                                ),
                              ),
                            ),
                            child: const Text('View ticket'),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                if (!isOrganizer && isPast) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.event_busy,
                            color: AppColors.textSecondary, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This event has already taken place. Registration is closed.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else if (!isOrganizer && _ticketTypes.isNotEmpty) ...[
                  const Text('Tickets',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose how many of each ticket type you\'d like.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ..._ticketTypes.map((t) => _TicketTypeStepperTile(
                    ticketType: t,
                    quantity: _quantities[t.id] ?? 0,
                    onChanged: (qty) => _setQuantity(t, qty),
                  )),
                ],
                const SizedBox(height: 100), // room for sticky bottom bar
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isOrganizer
              ? Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.people_outline),
                  label: const Text('View registrants'),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            EventDashboardScreen(eventId: event.id),
                      ),
                    );
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit event'),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CreateEditEventScreen(eventId: event.id),
                      ),
                    );
                    _load();
                  },
                ),
              ),
            ],
          )
              : ElevatedButton(
            onPressed: (isPast || totalQuantity == 0)
                ? null
                : () {
              final selections = _ticketTypes
                  .where((t) => (_quantities[t.id] ?? 0) > 0)
                  .map((t) => TicketSelection(
                ticketType: t,
                quantity: _quantities[t.id]!,
              ))
                  .toList();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BookingConfirmationScreen(
                    event: event,
                    selections: selections,
                  ),
                ),
              );
            },
            child: Text(
              isPast
                  ? 'Registration closed'
                  : (_ticketTypes.isEmpty
                  ? 'Registration not open yet'
                  : (totalQuantity == 0
                  ? 'Select tickets'
                  : (totalPrice == 0
                  ? 'Register $totalQuantity ticket${totalQuantity > 1 ? 's' : ''} — Free'
                  : 'Get $totalQuantity ticket${totalQuantity > 1 ? 's' : ''} — \$${totalPrice.toStringAsFixed(0)}'))),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoRow(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrganizerStatsRow extends StatelessWidget {
  final List<TicketType> ticketTypes;
  const _OrganizerStatsRow({required this.ticketTypes});

  @override
  Widget build(BuildContext context) {
    final registered = ticketTypes.fold<int>(0, (sum, t) => sum + t.quantitySold);
    final capacity =
    ticketTypes.fold<int>(0, (sum, t) => sum + t.quantityAvailable);
    final revenue = ticketTypes.fold<double>(
        0, (sum, t) => sum + (t.price * t.quantitySold));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('$registered / $capacity', 'Registered'),
          _stat('\$${revenue.toStringAsFixed(0)}', 'Sales'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
    children: [
      Text(value,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12)),
    ],
  );
}

/// Ticket type row with a quantity stepper (-, count, +), replacing the
/// old single-select radio tile. Lets a user pick more than one of a
/// type, and pick across multiple types at once.
class _TicketTypeStepperTile extends StatelessWidget {
  final TicketType ticketType;
  final int quantity;
  final ValueChanged<int> onChanged;

  const _TicketTypeStepperTile({
    required this.ticketType,
    required this.quantity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = ticketType.isSoldOut;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: quantity > 0 ? AppColors.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticketType.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  disabled ? 'Sold out' : '${ticketType.remaining} remaining',
                  style: TextStyle(
                    color: disabled
                        ? AppColors.statusDanger
                        : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ticketType.isFree
                      ? 'Free'
                      : '\$${ticketType.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.accent),
                ),
              ],
            ),
          ),
          if (!disabled)
            Row(
              children: [
                _stepButton(
                  icon: Icons.remove,
                  onTap: quantity > 0 ? () => onChanged(quantity - 1) : null,
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '$quantity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _stepButton(
                  icon: Icons.add,
                  onTap: quantity < ticketType.remaining
                      ? () => onChanged(quantity + 1)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _stepButton({required IconData icon, required VoidCallback? onTap}) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.textPrimary : AppColors.textMuted,
        ),
      ),
    );
  }
}