import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/supabase_service.dart';
import '../../../core/repositories/base_repository.dart';
import '../../../core/repositories/insights_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/insights_data.dart';

/// State for insights data
class InsightsState {
  final InsightsData data;
  final bool isLoading;
  final String? error;

  const InsightsState({
    required this.data,
    this.isLoading = false,
    this.error,
  });

  InsightsState copyWith({
    InsightsData? data,
    bool? isLoading,
    String? error,
  }) {
    return InsightsState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider for insights
class InsightsNotifier extends StateNotifier<InsightsState> {
  InsightsNotifier({bool initialLoading = false})
      : super(InsightsState(
          data: InsightsData.empty(),
          isLoading: initialLoading,
        ));

  /// Load all insights data from the server
  Future<void> loadInsights() async {
    // Check if we can make authenticated calls
    if (!BaseRepository.canMakeAuthCalls) {
      debugPrint('InsightsProvider: Cannot load - Supabase not ready or user not authenticated');
      debugPrint('InsightsProvider: isReady=${SupabaseService.isReady}, user=${SupabaseService.currentUser?.id}');
      state = state.copyWith(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load all data in parallel
      final results = await Future.wait([
        _loadSummary(),
        _loadOpeningStats(),
        _loadPerformanceStats(),
        _loadOpponentPerformance(),
      ]);

      final summary = results[0] as InsightsSummary;
      final openings = results[1] as List<OpeningStats>;
      final performance = results[2] as Map<String, List<PerformanceStats>>;
      final opponents = results[3] as List<OpponentPerformance>;

      state = state.copyWith(
        data: InsightsData(
          summary: summary,
          openings: openings,
          colorPerformance: performance['color'] ?? [],
          speedPerformance: performance['speed'] ?? [],
          opponentPerformance: opponents,
        ),
        isLoading: false,
      );
    } catch (e) {
      debugPrint('InsightsProvider: Error loading insights: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load summary stats
  Future<InsightsSummary> _loadSummary() async {
    final response = await InsightsRepository.getSummary();

    if (response.isEmpty) {
      return InsightsSummary.empty();
    }

    debugPrint('InsightsProvider: Found ${response.length} game reviews');
    int totalGames = response.length;

    // Calculate accuracies exactly like the web app:
    // For each game, use accuracy_white if player played white, accuracy_black if player played black
    final List<double> accuracies = [];
    double totalWhiteAcc = 0;
    double totalBlackAcc = 0;
    int whiteCount = 0;
    int blackCount = 0;

    for (final row in response) {
      final playerColor = row['player_color'] as String?;
      final accWhite = (row['accuracy_white'] as num?)?.toDouble();
      final accBlack = (row['accuracy_black'] as num?)?.toDouble();

      // Get player's accuracy based on which color they played
      final playerAccuracy = playerColor == 'white' ? accWhite : accBlack;

      if (playerAccuracy != null) {
        accuracies.add(playerAccuracy);
      }

      // Track per-color stats
      if (playerColor == 'white' && accWhite != null) {
        totalWhiteAcc += accWhite;
        whiteCount++;
      } else if (playerColor == 'black' && accBlack != null) {
        totalBlackAcc += accBlack;
        blackCount++;
      }
    }

    final overallAvg = accuracies.isNotEmpty
        ? accuracies.reduce((a, b) => a + b) / accuracies.length
        : 0.0;
    final whiteAvg = whiteCount > 0 ? totalWhiteAcc / whiteCount : 0.0;
    final blackAvg = blackCount > 0 ? totalBlackAcc / blackCount : 0.0;

    return InsightsSummary(
      totalGames: totalGames,
      overallAccuracy: overallAvg,
      whiteAccuracy: whiteAvg,
      blackAccuracy: blackAvg,
    );
  }

  /// Load opening stats
  Future<List<OpeningStats>> _loadOpeningStats() async {
    final response = await InsightsRepository.getOpeningStats();

    if (response.isEmpty) {
      return [];
    }

    // Group by opening name
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final row in response) {
      final name = row['opening_name'] as String? ?? 'Unknown';
      grouped.putIfAbsent(name, () => []).add(row);
    }

    // Calculate stats for each opening
    final List<OpeningStats> openings = [];
    for (final entry in grouped.entries) {
      final games = entry.value;
      int wins = 0, losses = 0, draws = 0;
      double totalAcc = 0;
      int accCount = 0;
      String eco = '';

      for (final game in games) {
        final result = game['game_result'] as String?;
        final color = game['player_color'] as String?;

        if (result == 'win') {
          wins++;
        } else if (result == 'loss') {
          losses++;
        } else {
          draws++;
        }

        eco = game['opening_eco'] as String? ?? eco;

        final acc = color == 'white'
            ? (game['accuracy_white'] as num?)?.toDouble()
            : (game['accuracy_black'] as num?)?.toDouble();
        if (acc != null) {
          totalAcc += acc;
          accCount++;
        }
      }

      final total = wins + losses + draws;
      openings.add(OpeningStats(
        eco: eco,
        name: entry.key,
        gamesCount: total,
        wins: wins,
        losses: losses,
        draws: draws,
        winRate: total > 0 ? (wins / total * 100) : 0,
        avgAccuracy: accCount > 0 ? totalAcc / accCount : 0,
      ));
    }

    // Sort by games count
    openings.sort((a, b) => b.gamesCount.compareTo(a.gamesCount));
    return openings;
  }

  /// Load performance stats (by color and speed)
  Future<Map<String, List<PerformanceStats>>> _loadPerformanceStats() async {
    final response = await InsightsRepository.getPerformanceStats();

    if (response.isEmpty) {
      return {'color': [], 'speed': []};
    }

    // Group by color
    final Map<String, _StatsAccumulator> colorStats = {
      'white': _StatsAccumulator(),
      'black': _StatsAccumulator(),
    };

    // Group by speed
    final Map<String, _StatsAccumulator> speedStats = {
      'bullet': _StatsAccumulator(),
      'blitz': _StatsAccumulator(),
      'rapid': _StatsAccumulator(),
      'classical': _StatsAccumulator(),
    };

    for (final row in response) {
      final color = row['player_color'] as String?;
      final speed = row['speed'] as String?;
      final result = row['game_result'] as String?;
      final accWhite = (row['accuracy_white'] as num?)?.toDouble();
      final accBlack = (row['accuracy_black'] as num?)?.toDouble();

      // Update color stats
      if (color != null && colorStats.containsKey(color)) {
        colorStats[color]!.addGame(result, color == 'white' ? accWhite : accBlack);
      }

      // Update speed stats
      if (speed != null && speedStats.containsKey(speed)) {
        speedStats[speed]!.addGame(result, color == 'white' ? accWhite : accBlack);
      }
    }

    return {
      'color': colorStats.entries
          .map((e) => e.value.toStats(e.key))
          .where((s) => s.gamesCount > 0)
          .toList(),
      'speed': speedStats.entries
          .map((e) => e.value.toStats(e.key))
          .where((s) => s.gamesCount > 0)
          .toList(),
    };
  }

  /// Load opponent performance
  Future<List<OpponentPerformance>> _loadOpponentPerformance() async {
    final response = await InsightsRepository.getOpponentPerformance();

    if (response.isEmpty) {
      return [];
    }

    // Group by opponent strength
    final Map<String, _OpponentAccumulator> stats = {
      'lower': _OpponentAccumulator(),
      'similar': _OpponentAccumulator(),
      'higher': _OpponentAccumulator(),
    };

    for (final row in response) {
      final playerRating = (row['player_rating'] as num?)?.toInt();
      final opponentRating = (row['opponent_rating'] as num?)?.toInt();
      final result = row['game_result'] as String?;

      if (playerRating == null || opponentRating == null) continue;

      final diff = opponentRating - playerRating;
      String category;
      if (diff < -100) {
        category = 'lower';
      } else if (diff > 100) {
        category = 'higher';
      } else {
        category = 'similar';
      }

      stats[category]!.addGame(result);
    }

    return stats.entries
        .map((e) => e.value.toOpponentPerformance(e.key))
        .where((s) => s.gamesCount > 0)
        .toList();
  }
}

/// Helper class to accumulate stats
class _StatsAccumulator {
  int wins = 0;
  int losses = 0;
  int draws = 0;
  double totalAcc = 0;
  int accCount = 0;

  void addGame(String? result, double? accuracy) {
    if (result == 'win') {
      wins++;
    } else if (result == 'loss') {
      losses++;
    } else {
      draws++;
    }

    if (accuracy != null) {
      totalAcc += accuracy;
      accCount++;
    }
  }

  int get total => wins + losses + draws;

  PerformanceStats toStats(String category) {
    return PerformanceStats(
      category: category,
      gamesCount: total,
      wins: wins,
      losses: losses,
      draws: draws,
      winRate: total > 0 ? (wins / total * 100) : 0,
      avgAccuracy: accCount > 0 ? totalAcc / accCount : 0,
    );
  }
}

/// Helper class for opponent stats
class _OpponentAccumulator {
  int wins = 0;
  int losses = 0;
  int draws = 0;

  void addGame(String? result) {
    if (result == 'win') {
      wins++;
    } else if (result == 'loss') {
      losses++;
    } else {
      draws++;
    }
  }

  int get total => wins + losses + draws;

  OpponentPerformance toOpponentPerformance(String category) {
    return OpponentPerformance(
      category: category,
      gamesCount: total,
      wins: wins,
      losses: losses,
      draws: draws,
      winRate: total > 0 ? (wins / total * 100) : 0,
    );
  }
}

/// Provider
final insightsProvider = StateNotifierProvider<InsightsNotifier, InsightsState>((ref) {
  // Check if user is authenticated with Supabase (not just local profile)
  final auth = ref.watch(authProvider);
  // Need: authenticated + not guest + has Supabase user (online mode)
  final canLoadFromServer = auth.isAuthenticated && !auth.isGuest && auth.user != null;

  // Create notifier with initial loading state if we're going to auto-load
  final notifier = InsightsNotifier(initialLoading: canLoadFromServer);

  // Auto-load when user is authenticated with Supabase
  if (canLoadFromServer) {
    Future.microtask(() => notifier.loadInsights());
  }

  return notifier;
});

/// Convenience providers
final hasEnoughInsightsDataProvider = Provider<bool>((ref) {
  return ref.watch(insightsProvider).data.hasEnoughData;
});

final analyzedGamesCountProvider = Provider<int>((ref) {
  return ref.watch(insightsProvider).data.summary.totalGames;
});
