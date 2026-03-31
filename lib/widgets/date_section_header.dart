import 'package:flutter/material.dart';
import 'package:nikki/core/constants/camera_colors.dart';

class DateSectionHeader extends StatelessWidget {
  final int timestamp;

  const DateSectionHeader({super.key, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDateLabel(timestamp),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CameraColors.brown,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 1,
            color: CameraColors.caramel,
          ),
        ],
      ),
    );
  }

  static String _formatDateLabel(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(date.year, date.month, date.day);

    if (entryDay == today) return 'Today';
    if (entryDay == today.subtract(const Duration(days: 1))) return 'Yesterday';

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Check if two timestamps fall on the same day.
  static bool sameDay(int a, int b) {
    final da = DateTime.fromMillisecondsSinceEpoch(a);
    final db = DateTime.fromMillisecondsSinceEpoch(b);
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }
}
