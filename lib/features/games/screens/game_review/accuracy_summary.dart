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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PlayerAccuracy(
              username: 'You',
              accuracy: playerSummary?.accuracy ?? 0,
              isPlayer: true,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'vs',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: _PlayerAccuracy(
              username: opponentUsername,
              accuracy: opponentSummary?.accuracy ?? 0,
              isPlayer: false,
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

  const _PlayerAccuracy({
    required this.username,
    required this.accuracy,
    required this.isPlayer,
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
    return Column(
      crossAxisAlignment: isPlayer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          username,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isPlayer ? AppColors.primary : null,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${accuracy.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _getAccuracyColor(accuracy),
          ),
        ),
      ],
    );
  }
}
