import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

class GameInfo extends StatelessWidget {
  final int moveCount;
  final Side turn;
  final bool isCheck;

  const GameInfo({
    super.key,
    required this.moveCount,
    required this.turn,
    required this.isCheck,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          _GameInfoItem(
            icon: Icons.swap_horiz,
            label: 'Moves',
            value: '$moveCount',
            color: AppColors.primary,
            isDark: isDark,
          ),
          _Divider(isDark: isDark),
          _GameInfoItem(
            icon: Icons.circle,
            label: 'Turn',
            value: turn == Side.white ? 'White' : 'Black',
            color: turn == Side.white ? Colors.grey.shade400 : Colors.grey.shade800,
            isDark: isDark,
          ),
          _Divider(isDark: isDark),
          _GameInfoItem(
            icon: Icons.warning_amber,
            label: 'Check',
            value: isCheck ? 'Yes' : 'No',
            color: isCheck ? AppColors.error : Colors.grey,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _GameInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _GameInfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
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
