import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../games/providers/games_provider.dart';
import '../../models/profile_data.dart';
import '../../providers/profile_provider.dart';
import 'widgets/section_card.dart';
import 'widgets/stat_box.dart';

class StatsTab extends ConsumerWidget {
  final ProfileState state;
  final bool isDark;

  const StatsTab({
    super.key,
    required this.state,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avgAccuracy = state.averageAccuracy;
    final games = ref.watch(gamesProvider).games;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Game analysis stats
        SectionCard(
          title: 'Game Analysis',
          isDark: isDark,
          child: Row(
            children: [
              StatBox(label: 'Analyzed', value: '${state.gameReviews.length}', icon: Icons.analytics, isDark: isDark),
              const SizedBox(width: 12),
              StatBox(
                label: 'Avg Accuracy',
                value: avgAccuracy != null ? '${avgAccuracy.toStringAsFixed(1)}%' : '-',
                icon: Icons.track_changes,
                isDark: isDark,
              ),
            ],
          ),
        ),

        // Recent games
        if (state.gameReviews.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: 'Recent Analyzed Games',
            isDark: isDark,
            child: Column(
              children: state.gameReviews.take(5).map((r) {
                // Find the game to get opponent name
                final game = games.where((g) => g.externalId == r.externalGameId).firstOrNull;
                return _GameReviewRow(
                  review: r,
                  isDark: isDark,
                  opponentName: game?.opponentUsername,
                  onTap: game != null ? () {
                    context.pushNamed('game-review', extra: game);
                  } : null,
                );
              }).toList(),
            ),
          ),
        ],

        // Member since
        const SizedBox(height: 16),
        SectionCard(
          title: 'Account',
          isDark: isDark,
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: AppColors.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Member since', style: TextStyle(fontSize: 12)),
                  Text(
                    state.profile?.createdAt != null
                        ? '${state.profile!.createdAt.day}/${state.profile!.createdAt.month}/${state.profile!.createdAt.year}'
                        : '-',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameReviewRow extends StatelessWidget {
  final GameReviewSummary review;
  final bool isDark;
  final VoidCallback? onTap;
  final String? opponentName;

  const _GameReviewRow({
    required this.review,
    required this.isDark,
    this.onTap,
    this.opponentName,
  });

  Color _getAccuracyColor(double acc) {
    if (acc >= 90) return AppColors.best;
    if (acc >= 75) return AppColors.good;
    if (acc >= 60) return AppColors.inaccuracy;
    return AppColors.mistake;
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = review.accuracyWhite ?? review.accuracyBlack ?? 0;
    // Use opponent name if available, otherwise fall back to truncated game ID
    final displayName = opponentName ?? 'Game ${review.externalGameId.substring(0, 8)}...';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getAccuracyColor(accuracy).withValues(alpha: 0.2),
                ),
                child: Center(
                  child: Text(
                    '${accuracy.toInt()}%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getAccuracyColor(accuracy)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opponentName != null ? 'vs $displayName' : displayName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(_formatDate(review.reviewedAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              // Arrow indicator to show it's clickable
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
