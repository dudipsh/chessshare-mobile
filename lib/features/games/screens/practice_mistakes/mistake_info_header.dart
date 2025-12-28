import 'package:flutter/material.dart';

import '../../models/analyzed_move.dart';

class MistakeInfoHeader extends StatelessWidget {
  final AnalyzedMove mistake;
  final bool isDark;

  const MistakeInfoHeader({
    super.key,
    required this.mistake,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        children: [
          // Classification badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: mistake.classification.color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(mistake.classification.icon, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  mistake.classification.displayName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Move info
          Expanded(
            child: Text(
              'You played: ${mistake.san}',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Color indicator
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: mistake.color == 'white' ? Colors.white : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                width: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
