import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../theme/app_colors.dart';
import '../screens/notifications/notifications_screen.dart';
import 'mawid_logo.dart';

/// Top bar used on Home, Events, Activity, Profile — logo + wordmark on
/// the left, notification bell (with a live unread badge) on the right.
class MawidTopBar extends StatelessWidget implements PreferredSizeWidget {
  const MawidTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().profile?.id;
    final notifications = context.watch<NotificationsProvider>();
    if (userId != null) {
      notifications.attach(userId); // no-op if already attached
    }
    final hasUnread = notifications.unreadCount > 0;

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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surface,
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined, size: 20),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
              ),
              if (hasUnread)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}