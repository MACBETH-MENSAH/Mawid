import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _isSaving = false;

  Future<void> _toggle({bool? registration, bool? checkin, bool? reminders}) async {
    final auth = context.read<AuthProvider>();
    final current = auth.profile;
    if (current == null) return;

    setState(() => _isSaving = true);
    try {
      await auth.updateProfileFields(
        fullName: current.fullName,
        notifyRegistration: registration,
        notifyCheckin: checkin,
        notifyReminders: reminders,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification preferences')),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Registration confirmations'),
                  subtitle: const Text(
                    'Notify me when a ticket registration is confirmed',
                    style: TextStyle(fontSize: 12),
                  ),
                  activeThumbColor: AppColors.accent,
                  value: profile.notifyRegistration,
                  onChanged: _isSaving
                      ? null
                      : (v) => _toggle(registration: v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Check-in notifications'),
                  subtitle: const Text(
                    'Notify me when I\'m checked in at an event',
                    style: TextStyle(fontSize: 12),
                  ),
                  activeThumbColor: AppColors.accent,
                  value: profile.notifyCheckin,
                  onChanged:
                  _isSaving ? null : (v) => _toggle(checkin: v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Event reminders'),
                  subtitle: const Text(
                    'Remind me before events I\'m registered for start',
                    style: TextStyle(fontSize: 12),
                  ),
                  activeThumbColor: AppColors.accent,
                  value: profile.notifyReminders,
                  onChanged:
                  _isSaving ? null : (v) => _toggle(reminders: v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'These control whether MAWID creates a notification for '
                'these events. Existing notifications aren\'t affected.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}