/// Data models for chess insights.
class InsightsSummary {
  final int totalGames;
  final double overallAccuracy;
  final double whiteAccuracy;
  final double blackAccuracy;

  const InsightsSummary({
    required this.totalGames,
    required this.overallAccuracy,
    required this.whiteAccuracy,
    required this.blackAccuracy,
  });

  factory InsightsSummary.empty() => const InsightsSummary(
        totalGames: 0,
        overallAccuracy: 0,
        whiteAccuracy: 0,
        blackAccuracy: 0,
      );
}

class OpeningStats {
  final String eco;
  final String name;
  final int gamesCount;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;
  final double avgAccuracy;

  const OpeningStats({
    required this.eco,
    required this.name,
    required this.gamesCount,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
    required this.avgAccuracy,
  });
}

class PerformanceStats {
  final String category; // 'white', 'black', 'bullet', 'blitz', 'rapid', 'classical'
  final int gamesCount;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;
  final double avgAccuracy;

  const PerformanceStats({
    required this.category,
    required this.gamesCount,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
    required this.avgAccuracy,
  });
}

class OpponentPerformance {
  final String category; // 'lower', 'similar', 'higher'
  final int gamesCount;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;

  const OpponentPerformance({
    required this.category,
    required this.gamesCount,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
  });
}

class InsightsData {
  final InsightsSummary summary;
  final List<OpeningStats> openings;
  final List<PerformanceStats> colorPerformance;
  final List<PerformanceStats> speedPerformance;
  final List<OpponentPerformance> opponentPerformance;

  const InsightsData({
    required this.summary,
    required this.openings,
    required this.colorPerformance,
    required this.speedPerformance,
    required this.opponentPerformance,
  });

  factory InsightsData.empty() => InsightsData(
        summary: InsightsSummary.empty(),
        openings: const [],
        colorPerformance: const [],
        speedPerformance: const [],
        opponentPerformance: const [],
      );

  bool get hasEnoughData => summary.totalGames >= 5;
}
