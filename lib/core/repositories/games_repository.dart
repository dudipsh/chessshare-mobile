import 'base_repository.dart';

/// Game review info from server
class GameReviewInfo {
  final String id;
  final String externalGameId;
  final double? accuracyWhite;
  final double? accuracyBlack;
  final DateTime? reviewedAt;
  final int puzzleCount;

  GameReviewInfo({
    required this.id,
    required this.externalGameId,
    this.accuracyWhite,
    this.accuracyBlack,
    this.reviewedAt,
    this.puzzleCount = 0,
  });

  factory GameReviewInfo.fromJson(Map<String, dynamic> json) {
    return GameReviewInfo(
      id: json['id'] as String,
      externalGameId: json['external_game_id'] as String,
      accuracyWhite: (json['accuracy_white'] as num?)?.toDouble(),
      accuracyBlack: (json['accuracy_black'] as num?)?.toDouble(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      puzzleCount: (json['puzzle_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Repository for games-related data
class GamesRepository {
  /// Get all user game reviews with puzzle counts
  static Future<List<GameReviewInfo>> getUserGameReviews() async {
    final result = await BaseRepository.executeRpc<List<GameReviewInfo>>(
      functionName: 'get_user_game_reviews',
      parser: (response) {
        if (response == null || response is! List) return <GameReviewInfo>[];
        return response
            .map((e) => GameReviewInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      defaultValue: <GameReviewInfo>[],
    );
    return result.data ?? [];
  }

  /// Get game review by external ID
  static Future<Map<String, dynamic>?> getGameReview({
    required String platform,
    required String externalGameId,
  }) async {
    final result = await BaseRepository.executeRpc<Map<String, dynamic>?>(
      functionName: 'get_game_review',
      params: {
        'p_platform': platform,
        'p_external_game_id': externalGameId,
      },
      parser: (response) {
        if (response == null) return null;
        if (response is List && response.isNotEmpty) {
          return response.first as Map<String, dynamic>;
        }
        if (response is Map) {
          return response as Map<String, dynamic>;
        }
        return null;
      },
      defaultValue: null,
    );
    return result.data;
  }

  /// Get game review moves
  static Future<List<Map<String, dynamic>>> getGameReviewMoves(String gameReviewId) async {
    final result = await BaseRepository.executeRpc<List<Map<String, dynamic>>>(
      functionName: 'get_game_review_moves',
      params: {'p_game_review_id': gameReviewId},
      parser: (response) {
        if (response == null || response is! List) return <Map<String, dynamic>>[];
        return response.cast<Map<String, dynamic>>();
      },
      defaultValue: <Map<String, dynamic>>[],
    );
    return result.data ?? [];
  }

  /// Save game review
  static Future<String?> saveGameReview({
    required String externalGameId,
    required String platform,
    required String pgn,
    required String playerColor,
    required String gameResult,
    required String speed,
    String? timeControl,
    required DateTime playedAt,
    required String opponentUsername,
    int? opponentRating,
    int? playerRating,
    String? openingEco,
    String? openingName,
    double? accuracyWhite,
    double? accuracyBlack,
    int movesTotal = 0,
    int movesBook = 0,
    int movesBrilliant = 0,
    int movesGreat = 0,
    int movesBest = 0,
    int movesGood = 0,
    int movesInaccuracy = 0,
    int movesMistake = 0,
    int movesBlunder = 0,
  }) async {
    final result = await BaseRepository.executeRpc<String?>(
      functionName: 'save_game_review',
      params: {
        'p_external_game_id': externalGameId,
        'p_platform': platform,
        'p_pgn': pgn,
        'p_player_color': playerColor,
        'p_game_result': gameResult,
        'p_speed': speed,
        'p_time_control': timeControl,
        'p_played_at': playedAt.toUtc().toIso8601String(),
        'p_opponent_username': opponentUsername,
        'p_opponent_rating': opponentRating,
        'p_player_rating': playerRating,
        'p_opening_eco': openingEco,
        'p_opening_name': openingName,
        'p_accuracy_white': accuracyWhite,
        'p_accuracy_black': accuracyBlack,
        'p_moves_total': movesTotal,
        'p_moves_book': movesBook,
        'p_moves_brilliant': movesBrilliant,
        'p_moves_great': movesGreat,
        'p_moves_best': movesBest,
        'p_moves_good': movesGood,
        'p_moves_inaccuracy': movesInaccuracy,
        'p_moves_mistake': movesMistake,
        'p_moves_blunder': movesBlunder,
      },
      parser: (response) => response as String?,
      defaultValue: null,
    );
    return result.data;
  }

  /// Save game review moves
  static Future<bool> saveGameReviewMoves({
    required String gameReviewId,
    required List<Map<String, dynamic>> moves,
  }) async {
    final result = await BaseRepository.executeRpc<bool>(
      functionName: 'save_game_review_moves',
      params: {
        'p_game_review_id': gameReviewId,
        'p_moves': moves,
      },
      parser: (_) => true,
      defaultValue: false,
    );
    return result.success;
  }

  /// Save personal mistakes (puzzles generated from analysis)
  static Future<bool> savePersonalMistakes({
    required String gameReviewId,
    required List<Map<String, dynamic>> mistakes,
  }) async {
    final result = await BaseRepository.executeRpc<bool>(
      functionName: 'save_personal_mistakes',
      params: {
        'p_game_review_id': gameReviewId,
        'p_mistakes': mistakes,
      },
      parser: (_) => true,
      defaultValue: false,
    );
    return result.success;
  }
}
