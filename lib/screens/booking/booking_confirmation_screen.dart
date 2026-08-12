import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/event.dart';
import '../../models/registration.dart';
import '../../models/ticket_selection.dart';
import '../../models/ticket_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_refresh_provider.dart';
import '../../services/registration_service.dart';
import '../../theme/app_colors.dart';
import 'booking_success_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final EventModel event;
  final List<TicketSelection> selections;

  const BookingConfirmationScreen({
    super.key,
    required this.event,
    required this.selections,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState
    extends State<BookingConfirmationScreen> {
  bool _isConfirming = false;
  String? _error;

  int get _totalQuantity =>
      widget.selections.fold(0, (sum, s) => sum + s.quantity);

  double get _totalPrice =>
      widget.selections.fold(0, (sum, s) => sum + s.subtotal);

  Future<void> _confirm() async {
    final userId = context.read<AuthProvider>().profile?.id;
    if (userId == null) return;

    setState(() {
      _isConfirming = true;
      _error = null;
    });

    // Each ticket is its own registration row (its own QR code / ticket
    // code), so buying "2 VIP + 1 Regular" means 3 separate inserts.
    // These aren't wrapped in a single database transaction — if one
    // fails partway (e.g. a type sells out mid-purchase), whatever
    // already succeeded stays booked rather than being rolled back. For
    // a student project this is an acceptable trade-off (documented as a
    // known limitation), but a production system would want this as a
    // single atomic Postgres RPC call instead.
    final created = <(Registration, TicketType)>[];
    try {
      for (final selection in widget.selections) {
        for (var i = 0; i < selection.quantity; i++) {
          final registration =
          await RegistrationService.instance.createRegistration(
            userId: userId,
            eventId: widget.event.id,
            ticketTypeId: selection.ticketType.id,
          );
          created.add((registration, selection.ticketType));
        }
      }

      if (!mounted) return;
      context.read<DataRefreshProvider>().bump();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            event: widget.event,
            tickets: created,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      if (created.isNotEmpty) {
        // Partial success — some tickets went through before the
        // failure. Don't lose that: bump the refresh signal and take the
        // user to see what they did get, but be upfront about the
        // shortfall.
        context.read<DataRefreshProvider>().bump();
        final shortBy = _totalQuantity - created.length;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(
              event: widget.event,
              tickets: created,
              warning:
              '$shortBy of your ${_totalQuantity} tickets could not be booked (likely sold out partway through). The rest are confirmed below.',
            ),
          ),
        );
        return;
      }

      setState(() {
        _isConfirming = false;
        _error = e.toString().contains('sold out')
            ? 'Sorry, one of these ticket types just sold out.'
            : 'Could not complete registration. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('MAWID')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Review & Confirm',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Please review your ticket details before confirming.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.event.title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(dateFormat.format(widget.event.startDate),
                      style:
                      const TextStyle(color: AppColors.textSecondary)),
                  const Divider(height: 32),
                  ...widget.selections.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${s.ticketType.name}  ×${s.quantity}',
                            style:
                            const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        Text(
                          s.subtotal == 0
                              ? 'Free'
                              : '\$${s.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _row(
                      '$_totalQuantity ticket${_totalQuantity > 1 ? 's' : ''} — Total',
                      _totalPrice == 0
                          ? 'Free'
                          : '\$${_totalPrice.toStringAsFixed(2)}',
                      bold: true,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(color: AppColors.statusDanger)),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _isConfirming ? null : _confirm,
              child: _isConfirming
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Text('CONFIRM REGISTRATION'),
            ),
            const SizedBox(height: 12),
            const Text(
              'By confirming, you agree to the Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: bold ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: bold ? 16 : 14)),
        Text(value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: bold ? 18 : 14,
              color: bold ? AppColors.accent : AppColors.textPrimary,
            )),
      ],
    );
  }
}