import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../models/insights_data.dart';
import '../providers/insights_provider.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(insightsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, InsightsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _buildErrorState(context, ref, state.error!);
    }

    if (!state.data.hasEnoughData) {
      return _buildNotEnoughGamesState(context, state.data.summary.totalGames);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(insightsProvider.notifier).loadInsights(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryCard(summary: state.data.summary),
            const SizedBox(height: 16),
            _AccuracyByColorCard(colorPerformance: state.data.colorPerformance),
            const SizedBox(height: 16),
            _SpeedPerformanceCard(speedPerformance: state.data.speedPerformance),
            const SizedBox(height: 16),
            _OpeningsCard(openings: state.data.openings),
            const SizedBox(height: 16),
            _OpponentAnalysisCard(opponentPerformance: state.data.opponentPerformance),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load insights',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.read(insightsProvider.notifier).loadInsights(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotEnoughGamesState(BuildContext context, int currentGames) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.insights,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unlock Your Insights',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Analyze at least 5 games to unlock your personal insights and discover your strengths and weaknesses.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _ProgressIndicator(current: currentGames, total: 5),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.goNamed('games'),
              icon: const Icon(Icons.sports_esports),
              label: const Text('Go to My Games'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress indicator showing X/5 games analyzed
class _ProgressIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = current / total;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$current',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            Text(
              ' / $total',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'games analyzed',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Summary card showing overall stats
class _SummaryCard extends StatelessWidget {
  final InsightsSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Games Analyzed',
                    value: '${summary.totalGames}',
                    icon: Icons.sports_esports,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Overall Accuracy',
                    value: '${summary.overallAccuracy.toStringAsFixed(1)}%',
                    icon: Icons.gps_fixed,
                    valueColor: _getAccuracyColor(summary.overallAccuracy),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Accuracy by color card
class _AccuracyByColorCard extends StatelessWidget {
  final List<PerformanceStats> colorPerformance;

  const _AccuracyByColorCard({required this.colorPerformance});

  @override
  Widget build(BuildContext context) {
    if (colorPerformance.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final white = colorPerformance.where((p) => p.category == 'white').firstOrNull;
    final black = colorPerformance.where((p) => p.category == 'black').firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contrast, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance by Color',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (white != null)
                  Expanded(child: _ColorStatCard(stats: white, isWhite: true)),
                if (white != null && black != null) const SizedBox(width: 12),
                if (black != null)
                  Expanded(child: _ColorStatCard(stats: black, isWhite: false)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual color stat card
class _ColorStatCard extends StatelessWidget {
  final PerformanceStats stats;
  final bool isWhite;

  const _ColorStatCard({required this.stats, required this.isWhite});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWhite
            ? (isDark ? Colors.grey[800] : Colors.grey[100])
            : (isDark ? Colors.grey[900] : Colors.grey[800]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isWhite ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isWhite ? 'White' : 'Black',
            style: TextStyle(
              color: isWhite
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white70 : Colors.white),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats.avgAccuracy.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _getAccuracyColor(stats.avgAccuracy),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${stats.wins}W / ${stats.draws}D / ${stats.losses}L',
            style: TextStyle(
              fontSize: 12,
              color: isWhite
                  ? (isDark ? Colors.white60 : Colors.black54)
                  : (isDark ? Colors.white54 : Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

/// Speed performance card
class _SpeedPerformanceCard extends StatelessWidget {
  final List<PerformanceStats> speedPerformance;

  const _SpeedPerformanceCard({required this.speedPerformance});

  @override
  Widget build(BuildContext context) {
    if (speedPerformance.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance by Time Control',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...speedPerformance.map((stats) => _SpeedStatRow(stats: stats)),
          ],
        ),
      ),
    );
  }
}

/// Individual speed stat row
class _SpeedStatRow extends StatelessWidget {
  final PerformanceStats stats;

  const _SpeedStatRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(_getSpeedIcon(stats.category), size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatSpeedName(stats.category),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${stats.gamesCount} games',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stats.avgAccuracy.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getAccuracyColor(stats.avgAccuracy),
                ),
              ),
              Text(
                '${stats.winRate.toStringAsFixed(0)}% win',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getSpeedIcon(String category) {
    switch (category) {
      case 'bullet':
        return Icons.bolt;
      case 'blitz':
        return Icons.flash_on;
      case 'rapid':
        return Icons.timer;
      case 'classical':
        return Icons.hourglass_bottom;
      default:
        return Icons.schedule;
    }
  }

  String _formatSpeedName(String category) {
    return category[0].toUpperCase() + category.substring(1);
  }
}

/// Openings card
class _OpeningsCard extends StatelessWidget {
  final List<OpeningStats> openings;

  const _OpeningsCard({required this.openings});

  @override
  Widget build(BuildContext context) {
    if (openings.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final topOpenings = openings.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Top Openings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...topOpenings.map((opening) => _OpeningRow(opening: opening)),
          ],
        ),
      ),
    );
  }
}

/// Individual opening row
class _OpeningRow extends StatelessWidget {
  final OpeningStats opening;

  const _OpeningRow({required this.opening});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.book.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              opening.eco,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.book,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opening.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${opening.gamesCount} games',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${opening.winRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getWinRateColor(opening.winRate),
                    ),
                  ),
                  Icon(
                    Icons.emoji_events,
                    size: 14,
                    color: _getWinRateColor(opening.winRate),
                  ),
                ],
              ),
              Text(
                '${opening.wins}W/${opening.draws}D/${opening.losses}L',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opponent analysis card
class _OpponentAnalysisCard extends StatelessWidget {
  final List<OpponentPerformance> opponentPerformance;

  const _OpponentAnalysisCard({required this.opponentPerformance});

  @override
  Widget build(BuildContext context) {
    if (opponentPerformance.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Performance vs Opponents',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...opponentPerformance.map((perf) => _OpponentRow(performance: perf)),
          ],
        ),
      ),
    );
  }
}

/// Individual opponent performance row
class _OpponentRow extends StatelessWidget {
  final OpponentPerformance performance;

  const _OpponentRow({required this.performance});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(_getCategoryIcon(), size: 20, color: _getCategoryColor()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getCategoryLabel(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${performance.gamesCount} games',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${performance.winRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _getWinRateColor(performance.winRate),
                ),
              ),
              Text(
                '${performance.wins}W/${performance.draws}D/${performance.losses}L',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel() {
    switch (performance.category) {
      case 'lower':
        return 'Lower Rated (-100+)';
      case 'similar':
        return 'Similar Rating (±100)';
      case 'higher':
        return 'Higher Rated (+100+)';
      default:
        return performance.category;
    }
  }

  IconData _getCategoryIcon() {
    switch (performance.category) {
      case 'lower':
        return Icons.arrow_downward;
      case 'similar':
        return Icons.remove;
      case 'higher':
        return Icons.arrow_upward;
      default:
        return Icons.person;
    }
  }

  Color _getCategoryColor() {
    switch (performance.category) {
      case 'lower':
        return AppColors.success;
      case 'similar':
        return AppColors.warning;
      case 'higher':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }
}

/// Stat item widget
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600], size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Helper functions
Color _getAccuracyColor(double accuracy) {
  if (accuracy >= 90) return AppColors.brilliant;
  if (accuracy >= 80) return AppColors.great;
  if (accuracy >= 70) return AppColors.good;
  if (accuracy >= 60) return AppColors.inaccuracy;
  return AppColors.mistake;
}

Color _getWinRateColor(double winRate) {
  if (winRate >= 60) return AppColors.success;
  if (winRate >= 45) return AppColors.warning;
  return AppColors.error;
}
