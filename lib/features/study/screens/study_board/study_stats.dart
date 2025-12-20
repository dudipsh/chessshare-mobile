import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

class StudyStats extends StatelessWidget {
  final int completedMoves;
  final int hintsUsed;
  final int mistakesMade;
  final bool isDark;

  const StudyStats({
    super.key,
    required this.completedMoves,
    required this.hintsUsed,
    required this.mistakesMade,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatChip(icon: Icons.check_circle_outline, value: '$completedMoves', color: AppColors.success),
          const SizedBox(width: 16),
          _StatChip(icon: Icons.lightbulb_outline, value: '$hintsUsed', color: Colors.amber),
          const SizedBox(width: 16),
          _StatChip(icon: Icons.close, value: '$mistakesMade', color: AppColors.error),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
