import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/event.dart';
import '../../models/registration.dart';
import '../../models/ticket_type.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';

class TicketDetailScreen extends StatelessWidget {
  final Registration registration;
  final EventModel event;
  final TicketType ticketType;

  const TicketDetailScreen({
    super.key,
    required this.registration,
    required this.event,
    required this.ticketType,
  });

  @override
  Widget build(BuildContext context) {
    final attendeeName =
        context.watch<AuthProvider>().profile?.fullName ?? 'Attendee';
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final isPast = event.startDate.isBefore(DateTime.now());
    final isCheckedIn = registration.isCheckedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('Your Ticket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCheckedIn
                              ? 'CHECKED IN'
                              : (isPast ? 'PAST' : 'UPCOMING'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: registration.ticketCode,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    event.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateFormat.format(event.startDate),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (event.venue != null) ...[
                    const SizedBox(height: 2),
                    Text(event.venue!,
                        style: const TextStyle(color: Colors.white70)),
                  ],
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white30),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ATTENDEE',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                          Text(attendeeName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('TICKET TYPE',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11)),
                          Text(ticketType.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'CODE: ${registration.ticketCode.toUpperCase()}',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: const Text('Add to Calendar'),
              onPressed: () {
                // Calendar integration (add_2_calendar package or similar)
                // is a good stretch goal if time allows post-submission.
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
