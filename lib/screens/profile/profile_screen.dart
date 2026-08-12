import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/mawid_top_bar.dart';
import '../settings/settings_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return Scaffold(
      appBar: const MawidTopBar(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.accent,
              backgroundImage:
              profile?.avatarUrl != null ? NetworkImage(profile!.avatarUrl!) : null,
              child: profile?.avatarUrl == null
                  ? Text(
                profile?.initials ?? '?',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              profile?.fullName ?? 'Loading...',
              style:
              const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(profile?.email ?? '',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Settings'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}