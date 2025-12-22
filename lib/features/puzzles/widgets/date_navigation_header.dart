import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';

class DateNavigationHeader extends StatelessWidget {
  final DateTime selectedDate;
  final bool isToday;
  final bool isDark;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  const DateNavigationHeader({
    super.key,
    required this.selectedDate,
    required this.isToday,
    required this.isDark,
    required this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left, size: 28),
          tooltip: 'Previous day',
        ),
        Text(
          _formatDate(selectedDate),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (isToday)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Today',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        IconButton(
          onPressed: isToday ? null : onNext,
          icon: Icon(
            Icons.chevron_right,
            size: 28,
            color: isToday
                ? (isDark ? Colors.white24 : Colors.grey.shade300)
                : null,
          ),
          tooltip: 'Next day',
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
