import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/supabase_service.dart';
import '../../../core/database/local_database.dart';
import '../models/analyzed_move.dart';
import '../models/chess_game.dart';
import '../models/game_review.dart';
import '../models/move_classification.dart';
import '../services/game_analysis_service.dart';

/// State for game review
class GameReviewState {
  final GameReview? review;
  final bool isLoading;
  final bool isAnalyzing;
  final double analysisProgress;
  final String? analysisMessage;
  final String? error;
  final int currentMoveIndex;

  const GameReviewState({
    this.review,
    this.isLoading = false,
    this.isAnalyzing = false,
    this.analysisProgress = 0,
    this.analysisMessage,
    this.error,
    this.currentMoveIndex = 0,
  });

  AnalyzedMove? get currentMove {
    if (review == null || review!.moves.isEmpty) return null;
    if (currentMoveIndex < 0 || currentMoveIndex >= review!.moves.length) return null;
    return review!.moves[currentMoveIndex];
  }

  String get currentFen {
    if (currentMoveIndex == 0) {
      return 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    }
    if (review == null || review!.moves.isEmpty) {
      return 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    }
    final index = (currentMoveIndex - 1).clamp(0, review!.moves.length - 1);
    // Return the FEN after the move at index
    final move = review!.moves[index];
    return move.fen; // This is the FEN before the move, so we need to find the FEN after
  }

  GameReviewState copyWith({
    GameReview? review,
    bool? isLoading,
    bool? isAnalyzing,
    double? analysisProgress,
    String? analysisMessage,
    String? error,
    int? currentMoveIndex,
  }) {
    return GameReviewState(
      review: review ?? this.review,
      isLoading: isLoading ?? this.isLoading,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      analysisProgress: analysisProgress ?? this.analysisProgress,
      analysisMessage: analysisMessage ?? this.analysisMessage,
      error: error ?? this.error,
      currentMoveIndex: currentMoveIndex ?? this.currentMoveIndex,
    );
  }
}

/// Provider for game review state
class GameReviewNotifier extends StateNotifier<GameReviewState> {
  final GameAnalysisService _analysisService;
  final String _userId;

  GameReviewNotifier({
    required String userId,
    GameAnalysisService? analysisService,
  })  : _userId = userId,
        _analysisService = analysisService ?? GameAnalysisService(),
        super(const GameReviewState());

  /// Load existing review for a game
  Future<void> loadReview(ChessGame game) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // First check local database
      final existingReview = await LocalDatabase.getGameReviewByGameId(
        _userId,
        game.id,
      );

      if (existingReview != null && existingReview['status'] == 'completed') {
        // Load from local database
        final moves = await LocalDatabase.getAnalyzedMoves(existingReview['id'] as String);

        final review = GameReview(
          id: existingReview['id'] as String,
          userId: _userId,
          gameId: game.id,
          game: game,
          status: ReviewStatus.completed,
          progress: 1.0,
          whiteSummary: existingReview['white_summary'] != null
              ? AccuracySummary.fromJson(
                  jsonDecode(existingReview['white_summary'] as String))
              : null,
          blackSummary: existingReview['black_summary'] != null
              ? AccuracySummary.fromJson(
                  jsonDecode(existingReview['black_summary'] as String))
              : null,
          moves: moves.map((m) => AnalyzedMove.fromJson(m)).toList(),
          depth: existingReview['depth'] as int? ?? 18,
          analyzedAt: existingReview['analyzed_at'] != null
              ? DateTime.parse(existingReview['analyzed_at'] as String)
              : null,
          createdAt: DateTime.parse(existingReview['created_at'] as String),
        );

        state = state.copyWith(
          review: review,
          isLoading: false,
          currentMoveIndex: 0,
        );
        return;
      }

      // Check Supabase for existing review (if authenticated)
      final serverReview = await _loadReviewFromServer(game);
      if (serverReview != null) {
        state = state.copyWith(
          review: serverReview,
          isLoading: false,
          currentMoveIndex: 0,
        );
        return;
      }

      // No existing review found, auto-analyze
      state = state.copyWith(isLoading: false);
      await analyzeGame(game);
    } catch (e) {
      debugPrint('Error loading review: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load review from Supabase server
  Future<GameReview?> _loadReviewFromServer(ChessGame game) async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return null;

      // Convert platform enum to string for API call
      final platform = game.platform == GamePlatform.chesscom ? 'chesscom' : 'lichess';

      // Call RPC to get game review
      final response = await SupabaseService.client.rpc('get_game_review', params: {
        'p_platform': platform,
        'p_external_game_id': game.externalId,
      });

      if (response == null || (response is List && response.isEmpty)) {
        return null;
      }

      final reviewData = response is List ? response.first : response;
      final reviewId = reviewData['id'] as String;

      // Get move evaluations
      final movesResponse = await SupabaseService.client.rpc('get_game_review_moves', params: {
        'p_game_review_id': reviewId,
      });

      final moves = <AnalyzedMove>[];
      if (movesResponse != null && movesResponse is List) {
        for (final moveData in movesResponse) {
          moves.add(AnalyzedMove(
            id: '${reviewId}_${moveData['move_index']}',
            gameReviewId: reviewId,
            moveNumber: moveData['move_index'] + 1,
            color: (moveData['move_index'] as int) % 2 == 0 ? 'white' : 'black',
            fen: moveData['fen'] as String,
            san: moveData['san'] as String,
            uci: '', // Not stored in server
            classification: MoveClassificationExtension.fromJson(
              moveData['marker_type'] as String? ?? 'good',
            ),
            evalBefore: moveData['evaluation_before'] as int?,
            evalAfter: moveData['evaluation_after'] as int?,
            bestMove: moveData['best_move'] as String?,
            centipawnLoss: moveData['centipawn_loss'] as int? ?? 0,
          ));
        }
      }

      // Build accuracy summaries
      final whiteMoves = moves.where((m) => m.color == 'white').toList();
      final blackMoves = moves.where((m) => m.color == 'black').toList();

      final review = GameReview(
        id: reviewId,
        userId: _userId,
        gameId: game.id,
        game: game,
        status: ReviewStatus.completed,
        progress: 1.0,
        whiteSummary: reviewData['accuracy_white'] != null
            ? AccuracySummary.fromMoves(whiteMoves)
            : null,
        blackSummary: reviewData['accuracy_black'] != null
            ? AccuracySummary.fromMoves(blackMoves)
            : null,
        moves: moves,
        depth: 18,
        analyzedAt: reviewData['reviewed_at'] != null
            ? DateTime.parse(reviewData['reviewed_at'] as String)
            : null,
        createdAt: DateTime.now(),
      );

      // Cache to local database for offline access
      await _cacheReviewLocally(review);

      debugPrint('Loaded game review from server: ${review.id}');
      return review;
    } catch (e) {
      debugPrint('Error loading review from server: $e');
      return null;
    }
  }

  /// Cache a server-loaded review to local database
  Future<void> _cacheReviewLocally(GameReview review) async {
    try {
      await LocalDatabase.saveGameReview({
        'id': review.id,
        'user_id': review.userId,
        'game_id': review.gameId,
        'status': 'completed',
        'progress': 1.0,
        'depth': review.depth,
        'white_summary': review.whiteSummary != null
            ? jsonEncode(review.whiteSummary!.toJson())
            : null,
        'black_summary': review.blackSummary != null
            ? jsonEncode(review.blackSummary!.toJson())
            : null,
        'created_at': review.createdAt.toIso8601String(),
        'analyzed_at': review.analyzedAt?.toIso8601String(),
      });

      await LocalDatabase.saveAnalyzedMoves(
        review.moves.map((m) => m.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error caching review locally: $e');
    }
  }

  /// Analyze a game
  Future<void> analyzeGame(ChessGame game) async {
    if (_analysisService.isAnalyzing) return;

    state = state.copyWith(
      isAnalyzing: true,
      analysisProgress: 0,
      analysisMessage: 'Starting analysis...',
      error: null,
    );

    try {
      final review = await _analysisService.analyzeGame(
        game: game,
        userId: _userId,
        onProgress: (progress) {
          state = state.copyWith(
            analysisProgress: progress.progress,
            analysisMessage: progress.message,
          );
        },
      );

      state = state.copyWith(
        review: review,
        isAnalyzing: false,
        analysisProgress: 1.0,
        analysisMessage: null,
        currentMoveIndex: 0,
      );
    } catch (e) {
      debugPrint('Analysis error: $e');
      state = state.copyWith(
        isAnalyzing: false,
        error: e.toString(),
      );
    }
  }

  /// Navigate to a specific move
  void goToMove(int index) {
    if (state.review == null) return;
    final maxIndex = state.review!.moves.length;
    state = state.copyWith(
      currentMoveIndex: index.clamp(0, maxIndex),
    );
  }

  /// Go to the next move
  void nextMove() {
    goToMove(state.currentMoveIndex + 1);
  }

  /// Go to the previous move
  void previousMove() {
    goToMove(state.currentMoveIndex - 1);
  }

  /// Go to the first move
  void goToStart() {
    goToMove(0);
  }

  /// Go to the last move
  void goToEnd() {
    if (state.review == null) return;
    goToMove(state.review!.moves.length);
  }

  /// Dispose resources
  @override
  void dispose() {
    _analysisService.dispose();
    super.dispose();
  }
}

/// Provider factory for game review
final gameReviewProvider = StateNotifierProvider.autoDispose
    .family<GameReviewNotifier, GameReviewState, String>(
  (ref, userId) => GameReviewNotifier(userId: userId),
);
