import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../models/registration.dart';
import '../../models/ticket_type.dart';
import '../../theme/app_colors.dart';
import '../tickets/ticket_detail_screen.dart';

class BookingSuccessScreen extends StatelessWidget {
  final EventModel event;
  final List<(Registration, TicketType)> tickets;
  final String? warning;

  const BookingSuccessScreen({
    super.key,
    required this.event,
    required this.tickets,
    this.warning,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MAWID')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Icon(Icons.check_circle, color: AppColors.accent, size: 64),
            const SizedBox(height: 16),
            Text(
              tickets.length == 1
                  ? "You're registered!"
                  : "You're registered! (${tickets.length} tickets)",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              event.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (warning != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusWarning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.statusWarning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(warning!,
                          style: const TextStyle(
                              color: AppColors.statusWarning, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text('Your tickets',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: tickets.length,
                itemBuilder: (context, i) {
                  final (registration, ticketType) = tickets[i];
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
                            color: AppColors.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ticketType.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(
                                registration.ticketCode.toUpperCase(),
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
                          child: const Text('View'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}