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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNavButton(
            icon: Icons.chevron_left,
            onPressed: onPrevious,
            enabled: true,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(selectedDate),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildNavButton(
            icon: Icons.chevron_right,
            onPressed: onNext,
            enabled: !isToday,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool enabled,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: enabled
            ? (isDark ? Colors.grey[850] : Colors.grey[100])
            : (isDark ? Colors.grey[900] : Colors.grey[50]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: 20,
          color: enabled
              ? (isDark ? Colors.white : Colors.black87)
              : (isDark ? Colors.grey[700] : Colors.grey[300]),
        ),
        tooltip: icon == Icons.chevron_left ? 'Previous day' : 'Next day',
      ),
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
