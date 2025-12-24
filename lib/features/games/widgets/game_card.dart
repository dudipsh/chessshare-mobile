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
    final subtleColor = isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black54;
    final fadedColor = isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black45;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Result indicator
              Container(
                width: 4,
                height: 60,
                decoration: BoxDecoration(
                  color: resultColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),

              // Game info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Color indicator
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: game.playerColor == 'white'
                                ? Colors.white
                                : Colors.black,
                            border: Border.all(
                              color: Colors.grey.shade600,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'vs ${game.opponentUsername}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: resultColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            resultText,
                            style: TextStyle(
                              color: resultColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Speed icon
                        Icon(
                          _getSpeedIcon(game.speed),
                          size: 14,
                          color: subtleColor,
                        ),
                        const SizedBox(width: 4),
                        // Opening name
                        Expanded(
                          child: Text(
                            game.openingName ?? 'Unknown opening',
                            style: TextStyle(
                              color: subtleColor,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Platform icon
                        _buildPlatformChip(isDark),
                        const SizedBox(width: 8),
                        // Ratings
                        if (game.playerRating != null || game.opponentRating != null)
                          Flexible(
                            child: Text(
                              '${game.playerRating ?? '?'} vs ${game.opponentRating ?? '?'}',
                              style: TextStyle(
                                color: subtleColor,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const Spacer(),
                        // Date
                        Text(
                          DateFormat('MMM d, yyyy').format(game.playedAt),
                          style: TextStyle(
                            color: fadedColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Analysis indicator or accuracy
              if (game.isAnalyzed && game.playerAccuracy != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${game.playerAccuracy!.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: _getAccuracyColor(game.playerAccuracy!),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // "Analyzed" badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 12,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Analyzed',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Analyze',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: fadedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformChip(bool isDark) {
    final isChessCom = game.platform == GamePlatform.chesscom;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isChessCom ? Colors.green : (isDark ? Colors.white : Colors.grey)).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isChessCom ? 'Chess.com' : 'Lichess',
        style: TextStyle(
          color: isChessCom ? Colors.green.shade300 : (isDark ? Colors.white70 : Colors.grey.shade700),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getResultColor(GameResult result) {
    switch (result) {
      case GameResult.win:
        return AppColors.win;
      case GameResult.loss:
        return AppColors.loss;
      case GameResult.draw:
        return AppColors.draw;
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

  IconData _getSpeedIcon(GameSpeed speed) {
    switch (speed) {
      case GameSpeed.bullet:
        return Icons.bolt;
      case GameSpeed.blitz:
        return Icons.flash_on;
      case GameSpeed.rapid:
        return Icons.timer;
      case GameSpeed.classical:
        return Icons.hourglass_bottom;
      case GameSpeed.correspondence:
        return Icons.mail_outline;
    }
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return AppColors.brilliant;
    if (accuracy >= 80) return AppColors.great;
    if (accuracy >= 70) return AppColors.good;
    if (accuracy >= 60) return AppColors.inaccuracy;
    return AppColors.mistake;
  }
}
