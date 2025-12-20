import 'base_repository.dart';

/// Repository for insights-related data
class InsightsRepository {
  /// Get insights summary (accuracy stats)
  static Future<List<Map<String, dynamic>>> getSummary() async {
    final result = await BaseRepository.executeRpc<List<Map<String, dynamic>>>(
      functionName: 'get_insights_summary',
      parser: (response) {
        if (response == null || response is! List) return <Map<String, dynamic>>[];
        return response.cast<Map<String, dynamic>>();
      },
      defaultValue: <Map<String, dynamic>>[],
    );
    return result.data ?? [];
  }

  /// Get opening stats
  static Future<List<Map<String, dynamic>>> getOpeningStats() async {
    final result = await BaseRepository.executeRpc<List<Map<String, dynamic>>>(
      functionName: 'get_insights_opening_stats',
      parser: (response) {
        if (response == null || response is! List) return <Map<String, dynamic>>[];
        return response.cast<Map<String, dynamic>>();
      },
      defaultValue: <Map<String, dynamic>>[],
    );
    return result.data ?? [];
  }

  /// Get performance stats (by color and speed)
  static Future<List<Map<String, dynamic>>> getPerformanceStats() async {
    final result = await BaseRepository.executeRpc<List<Map<String, dynamic>>>(
      functionName: 'get_insights_performance_stats',
      parser: (response) {
        if (response == null || response is! List) return <Map<String, dynamic>>[];
        return response.cast<Map<String, dynamic>>();
      },
      defaultValue: <Map<String, dynamic>>[],
    );
    return result.data ?? [];
  }

  /// Get opponent performance
  static Future<List<Map<String, dynamic>>> getOpponentPerformance() async {
    final result = await BaseRepository.executeRpc<List<Map<String, dynamic>>>(
      functionName: 'get_insights_opponent_performance',
      parser: (response) {
        if (response == null || response is! List) return <Map<String, dynamic>>[];
        return response.cast<Map<String, dynamic>>();
      },
      defaultValue: <Map<String, dynamic>>[],
    );
    return result.data ?? [];
  }

  /// Get games with mistakes (for practice)
  static Future<List<Map<String, dynamic>>> getGamesWithMistakes() async {
    final result = await BaseRepository.executeRpc<List<Map<String, dynamic>>>(
      functionName: 'get_games_with_mistakes',
      parser: (response) {
        if (response == null || response is! List) return <Map<String, dynamic>>[];
        return response.cast<Map<String, dynamic>>();
      },
      defaultValue: <Map<String, dynamic>>[],
    );
    return result.data ?? [];
  }
}
