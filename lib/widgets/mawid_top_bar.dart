import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../screens/notifications/notifications_screen.dart';
import 'mawid_logo.dart';

/// Top bar used on Home, Events, Activity, Profile — logo + wordmark on
/// the left, notification bell on the right. One widget instead of every
/// screen redrawing its own version of the header.
class MawidTopBar extends StatelessWidget implements PreferredSizeWidget {
  const MawidTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 20,
      title: Row(
        children: const [
          MawidLogo(size: 24),
          SizedBox(width: 8),
          Text(
            'MAWID',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CircleAvatar(
            backgroundColor: AppColors.surface,
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined, size: 20),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}