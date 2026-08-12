import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../theme/app_colors.dart';

/// The event card used on Home, Browse Events, and Activity lists.
/// One widget, reused everywhere — matches the Stitch design's repeated
/// card pattern instead of every screen rebuilding its own version.
class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap;
  final String? trailingBadge; // e.g. "FREE", "$150", "Sold Out", "2 TICKETS"

  /// Compact mode hides the description and tightens padding — needed in
  /// fixed-height horizontal scrollers (e.g. Home's "My upcoming events")
  /// where the full card, description included, is taller than a
  /// reasonable fixed height and causes a render overflow.
  final bool compact;

  /// Defaults to bottom-margin 16 for normal vertical-list use. Pass
  /// EdgeInsets.zero in horizontal lists that already space cards via a
  /// ListView separator, so the margin doesn't add unaccounted-for height
  /// inside a fixed-height container.
  final EdgeInsetsGeometry margin;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.trailingBadge,
    this.compact = false,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: event.coverImageUrl != null
                      ? CachedNetworkImage(
                    imageUrl: event.coverImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.surfaceElevated,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.surfaceElevated,
                      child: const Icon(Icons.image_not_supported,
                          color: AppColors.textMuted),
                    ),
                  )
                      : Container(
                    color: AppColors.surfaceElevated,
                    child: const Icon(Icons.event,
                        color: AppColors.textMuted, size: 40),
                  ),
                ),
                if (trailingBadge != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        trailingBadge!,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!compact && event.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        dateFormat.format(event.startDate),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (event.venue != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.venue!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}