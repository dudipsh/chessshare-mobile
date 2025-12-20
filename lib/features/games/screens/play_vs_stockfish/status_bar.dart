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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.smart_toy,
            color: isThinking ? AppColors.primary : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isThinking
                  ? 'Stockfish is thinking...'
                  : gameResult ?? 'Level $engineLevel',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isThinking ? AppColors.primary : null,
              ),
            ),
          ),
          if (isThinking)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
