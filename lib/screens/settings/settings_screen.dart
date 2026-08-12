import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../profile/edit_profile_screen.dart';
import 'notification_preferences_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeletingAccount = false;

  void _showInfoDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and login, your profile, '
              'any events you organize (and their ticket types and '
              'registrants), and signs you out. This cannot be undone.',
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

    if (confirmed != true) return;

    setState(() => _isDeletingAccount = true);
    try {
      await context.read<AuthProvider>().deleteAccount();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete account. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isDeletingAccount
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionHeader('ACCOUNT'),
          _settingsGroup([
            _settingsRow(
              icon: Icons.person_outline,
              label: 'Manage account',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
            ),
            _settingsRow(
              icon: Icons.notifications_outlined,
              label: 'Notification preferences',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const NotificationPreferencesScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('LEGAL'),
          _settingsGroup([
            _settingsRow(
              icon: Icons.shield_outlined,
              label: 'Privacy policy',
              onTap: () => _showInfoDialog(
                'Privacy policy',
                'MAWID is a student course project. Data entered (name, email, '
                    'event and ticket information) is stored in a Supabase '
                    'project used solely for this assignment and is not shared '
                    'with third parties.',
              ),
            ),
            _settingsRow(
              icon: Icons.description_outlined,
              label: 'Terms & conditions',
              onTap: () => _showInfoDialog(
                'Terms & conditions',
                'MAWID is provided as an academic prototype for demonstration '
                    'purposes and is not a production ticketing service. '
                    'Payments shown in the app are simulated, not real '
                    'transactions.',
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('SUPPORT'),
          _settingsGroup([
            _settingsRow(
              icon: Icons.help_outline,
              label: 'Help/Support',
              onTap: () => _showInfoDialog(
                'Help & Support',
                'This is a course project prototype without a live support '
                    'team. For issues, contact the project team directly.',
              ),
            ),
            _settingsRow(
              icon: Icons.info_outline,
              label: 'About',
              onTap: () => _showInfoDialog(
                'About MAWID',
                'MAWID — "your next occasion." An event management app built '
                    'for a Software Engineering course project, using Flutter '
                    'and Supabase.',
              ),
            ),
          ]),
          const SizedBox(height: 32),
          Center(
            child: TextButton(
              onPressed: () => context.read<AuthProvider>().signOut(),
              child: const Text('Log out',
                  style: TextStyle(color: AppColors.statusDanger)),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: _confirmDeleteAccount,
              child: const Text('Delete account',
                  style: TextStyle(color: AppColors.statusDanger)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(
      text,
      style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1),
    ),
  );

  Widget _settingsGroup(List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: rows),
  );

  Widget _settingsRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent, size: 20),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}