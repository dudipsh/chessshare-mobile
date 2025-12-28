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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            icon: Icons.check_circle,
            value: completedMoves,
            label: 'Correct',
            color: AppColors.success,
            isDark: isDark,
          ),
          _Divider(isDark: isDark),
          _StatItem(
            icon: Icons.lightbulb,
            value: hintsUsed,
            label: 'Hints',
            color: Colors.amber,
            isDark: isDark,
          ),
          _Divider(isDark: isDark),
          _StatItem(
            icon: Icons.close,
            value: mistakesMade,
            label: 'Mistakes',
            color: AppColors.error,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;

  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: isDark ? Colors.white12 : Colors.grey.shade200,
    );
  }
}
