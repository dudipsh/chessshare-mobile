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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: mistake.classification.color.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: mistake.classification.color.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: mistake.classification.color,
              borderRadius: BorderRadius.circular(12),
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
          Text(
            'You played: ${mistake.san}',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 14),
          ),
          const Spacer(),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: mistake.color == 'white' ? Colors.white : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
