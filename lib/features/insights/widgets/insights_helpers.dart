import 'package:flutter/material.dart';

import '../../../app/theme/colors.dart';

Color getAccuracyColor(double accuracy) {
  if (accuracy >= 90) return AppColors.brilliant;
  if (accuracy >= 80) return AppColors.great;
  if (accuracy >= 70) return AppColors.good;
  if (accuracy >= 60) return AppColors.inaccuracy;
  return AppColors.mistake;
}

Color getWinRateColor(double winRate) {
  if (winRate >= 60) return AppColors.success;
  if (winRate >= 45) return AppColors.warning;
  return AppColors.error;
}

class StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const StatItem({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600], size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
