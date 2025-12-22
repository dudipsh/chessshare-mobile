import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../providers/insights_provider.dart';
import '../widgets/accuracy_by_color_card.dart';
import '../widgets/openings_card.dart';
import '../widgets/opponent_analysis_card.dart';
import '../widgets/progress_indicator.dart';
import '../widgets/speed_performance_card.dart';
import '../widgets/summary_card.dart';

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
            SummaryCard(summary: state.data.summary),
            const SizedBox(height: 16),
            AccuracyByColorCard(colorPerformance: state.data.colorPerformance),
            const SizedBox(height: 16),
            SpeedPerformanceCard(speedPerformance: state.data.speedPerformance),
            const SizedBox(height: 16),
            OpeningsCard(openings: state.data.openings),
            const SizedBox(height: 16),
            OpponentAnalysisCard(opponentPerformance: state.data.opponentPerformance),
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
            InsightsProgressIndicator(current: currentGames, total: 5),
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
