import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';

class EngineStatusBar extends StatelessWidget {
  final bool isThinking;
  final String? gameResult;
  final int engineLevel;

  const EngineStatusBar({
    super.key,
    required this.isThinking,
    required this.gameResult,
    required this.engineLevel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (isThinking ? AppColors.primary : Colors.grey).withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.smart_toy,
              size: 18,
              color: isThinking ? AppColors.primary : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isThinking
                      ? 'Thinking...'
                      : gameResult ?? 'Stockfish',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isThinking
                        ? AppColors.primary
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                Text(
                  'Level $engineLevel',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (isThinking)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}
