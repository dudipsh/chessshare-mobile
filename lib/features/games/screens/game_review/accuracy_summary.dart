import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../models/game_review.dart';
import '../../models/move_classification.dart';

class AccuracySummary extends StatelessWidget {
  final GameReview review;
  final String opponentUsername;
  final bool isDark;

  const AccuracySummary({
    super.key,
    required this.review,
    required this.opponentUsername,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final playerSummary = review.playerSummary;
    final opponentSummary = review.opponentSummary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Expanded(
            child: _PlayerAccuracy(
              username: 'You',
              accuracy: playerSummary?.accuracy ?? 0,
              isPlayer: true,
              isDark: isDark,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'vs',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: _PlayerAccuracy(
              username: opponentUsername,
              accuracy: opponentSummary?.accuracy ?? 0,
              isPlayer: false,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerAccuracy extends StatelessWidget {
  final String username;
  final double accuracy;
  final bool isPlayer;
  final bool isDark;

  const _PlayerAccuracy({
    required this.username,
    required this.accuracy,
    required this.isPlayer,
    required this.isDark,
  });

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 95) return MoveClassification.brilliant.color;
    if (accuracy >= 85) return MoveClassification.best.color;
    if (accuracy >= 75) return MoveClassification.good.color;
    if (accuracy >= 60) return MoveClassification.inaccuracy.color;
    if (accuracy >= 45) return MoveClassification.mistake.color;
    return MoveClassification.blunder.color;
  }

  @override
  Widget build(BuildContext context) {
    final accuracyColor = _getAccuracyColor(accuracy);

    return Row(
      mainAxisAlignment: isPlayer ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (!isPlayer) ...[
          _AccuracyBadge(accuracy: accuracy, color: accuracyColor, isDark: isDark),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: isPlayer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Text(
                username,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isPlayer ? AppColors.primary : (isDark ? Colors.white : Colors.black87),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                isPlayer ? 'Your accuracy' : 'Opponent',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        if (isPlayer) ...[
          const SizedBox(width: 10),
          _AccuracyBadge(accuracy: accuracy, color: accuracyColor, isDark: isDark),
        ],
      ],
    );
  }
}

class _AccuracyBadge extends StatelessWidget {
  final double accuracy;
  final Color color;
  final bool isDark;

  const _AccuracyBadge({
    required this.accuracy,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        '${accuracy.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
