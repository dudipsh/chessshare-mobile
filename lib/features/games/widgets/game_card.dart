import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/colors.dart';
import '../models/chess_game.dart';

class GameCard extends StatelessWidget {
  final ChessGame game;
  final VoidCallback onTap;

  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final resultColor = _getResultColor(game.result);
    final resultText = _getResultText(game.result);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Color indicator (player's piece color)
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: game.playerColor == 'white' ? Colors.white : Colors.black,
                    border: Border.all(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),

                // Game info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Opponent name and result badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'vs ${game.opponentUsername}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Result badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: resultColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              resultText.toUpperCase(),
                              style: TextStyle(
                                color: resultColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Opening name
                      Text(
                        game.openingName ?? 'Unknown opening',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Platform, moves, date row
                      Row(
                        children: [
                          // Platform icon
                          Icon(
                            Icons.language,
                            size: 14,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              game.platform == GamePlatform.chesscom ? 'Chess.com' : 'Lichess',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            ' · ${_getMoveCount(game.pgn)} · ${_formatDate(game.playedAt)}',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Analysis indicator
                if (game.isAnalyzed && game.playerAccuracy != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Analyzed badge
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ANALYZED',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Accuracy percentage
                      Text(
                        '${game.playerAccuracy!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: _getAccuracyColor(game.playerAccuracy!),
                        ),
                      ),

                      // Show puzzle count if there are puzzles
                      if (game.puzzleCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.extension,
                              size: 12,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${game.puzzleCount}',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  // Analyze button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Analyze',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Color _getResultColor(GameResult result) {
    switch (result) {
      case GameResult.win:
        return AppColors.win;
      case GameResult.loss:
        return AppColors.loss;
      case GameResult.draw:
        return const Color(0xFFF59E0B); // Amber/yellow color
    }
  }

  String _getResultText(GameResult result) {
    switch (result) {
      case GameResult.win:
        return 'Win';
      case GameResult.loss:
        return 'Loss';
      case GameResult.draw:
        return 'Draw';
    }
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return AppColors.brilliant;
    if (accuracy >= 80) return AppColors.great;
    if (accuracy >= 70) return AppColors.good;
    if (accuracy >= 60) return AppColors.inaccuracy;
    return AppColors.mistake;
  }

  int _getMoveCount(String pgn) {
    // Count the number of move pairs (e.g., "1." "2." etc.)
    final moveRegex = RegExp(r'\d+\.');
    final matches = moveRegex.allMatches(pgn);
    return matches.length;
  }
}
