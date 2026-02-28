import 'package:flutter/material.dart';

class VoiceGuide extends StatelessWidget {
  final String headline;
  final DateTime? timestamp;

  const VoiceGuide({
    super.key,
    required this.headline,
    this.timestamp,
  });

  static const _weekdays = [
    '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOfDt = DateTime(dt.year, dt.month, dt.day);

    String prefix;
    if (dateOfDt == today) {
      prefix = 'Tonight';
    } else if (dateOfDt == tomorrow) {
      prefix = 'Tomorrow';
    } else {
      prefix = _weekdays[dt.weekday];
    }

    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'am' : 'pm';
    return '$prefix, $hour:$minute$ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headline,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        if (timestamp != null) ...[
          const SizedBox(height: 12),
          Text(
            _formatTimestamp(timestamp!),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}
