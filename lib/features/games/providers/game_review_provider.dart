import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/supabase_service.dart';
import '../../../core/database/local_database.dart';
import '../models/analyzed_move.dart';
import '../models/chess_game.dart';
import '../models/game_review.dart';
import '../models/move_classification.dart';
import '../services/game_analysis_service.dart';
import '../utils/chess_position_utils.dart';

/// State for game review
class GameReviewState {
  final GameReview? review;
  final bool isLoading;
  final bool isAnalyzing;
  final double analysisProgress;
  final String? analysisMessage;
  final String? error;
  final int currentMoveIndex;
  final Chess _position;

  GameReviewState({
    this.review,
    this.isLoading = false,
    this.isAnalyzing = false,
    this.analysisProgress = 0,
    this.analysisMessage,
    this.error,
    this.currentMoveIndex = 0,
    Chess? position,
  }) : _position = position ?? Chess.initial;

  /// Current chess position based on moves played
  Chess get position => _position;

  /// Current FEN string
  String get fen => _position.fen;

  /// Side to move
  Side get sideToMove => _position.turn;

  /// The move that was just played (at currentMoveIndex - 1)
  AnalyzedMove? get currentMove {
    if (review == null || review!.moves.isEmpty) return null;
    if (currentMoveIndex <= 0) return null;
    final moveIndex = currentMoveIndex - 1;
    if (moveIndex >= review!.moves.length) return null;
    return review!.moves[moveIndex];
  }

  /// Last move as NormalMove for board highlighting
  NormalMove? get lastMove {
    final move = currentMove;
    if (move == null) return null;
    return ChessPositionUtils.parseUciMove(move.uci);
  }

  GameReviewState copyWith({
    GameReview? review,
    bool? isLoading,
    bool? isAnalyzing,
    double? analysisProgress,
    String? analysisMessage,
    String? error,
    int? currentMoveIndex,
    Chess? position,
  }) {
    return GameReviewState(
      review: review ?? this.review,
      isLoading: isLoading ?? this.isLoading,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      analysisProgress: analysisProgress ?? this.analysisProgress,
      analysisMessage: analysisMessage ?? this.analysisMessage,
      error: error ?? this.error,
      currentMoveIndex: currentMoveIndex ?? this.currentMoveIndex,
      position: position ?? _position,
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
        super(GameReviewState());

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
          final fen = moveData['fen'] as String;
          final san = moveData['san'] as String;
          // Compute UCI from FEN and SAN (server doesn't store UCI)
          final uci = ChessPositionUtils.sanToUci(fen, san) ?? '';
          moves.add(AnalyzedMove(
            id: '${reviewId}_${moveData['move_index']}',
            gameReviewId: reviewId,
            moveNumber: moveData['move_index'] + 1,
            color: (moveData['move_index'] as int) % 2 == 0 ? 'white' : 'black',
            fen: fen,
            san: san,
            uci: uci,
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
      // Don't show error if analysis was cancelled
      final wasCancelled = e.toString().contains('cancelled');
      state = state.copyWith(
        isAnalyzing: false,
        error: wasCancelled ? null : e.toString(),
      );
    }
  }

  /// Navigate to a specific move
  void goToMove(int index) {
    if (state.review == null) return;
    final maxIndex = state.review!.moves.length;
    final clampedIndex = index.clamp(0, maxIndex);

    Chess? position;

    // FEN in AnalyzedMove is "position BEFORE the move"
    // So moves[N].fen = position before move N = position after moves 0..N-1
    //
    // currentMoveIndex = 0: starting position (no moves played)
    // currentMoveIndex = N: position after N moves played = moves[N].fen (if exists)

    if (clampedIndex == 0) {
      // At start - use initial position
      position = Chess.initial;
    } else if (clampedIndex < state.review!.moves.length) {
      // We have a FEN at this index (position before this move = after previous moves)
      final moveFen = state.review!.moves[clampedIndex].fen;
      if (moveFen.isNotEmpty) {
        position = ChessPositionUtils.positionFromFen(moveFen);
      }
    } else {
      // At the very end (after all moves) - need to compute final position
      // Try using the last move's FEN and apply the last move
      if (state.review!.moves.isNotEmpty) {
        final lastMove = state.review!.moves.last;
        if (lastMove.fen.isNotEmpty && lastMove.uci.isNotEmpty) {
          final beforeLast = ChessPositionUtils.positionFromFen(lastMove.fen);
          if (beforeLast != null) {
            final move = ChessPositionUtils.parseUciMove(lastMove.uci);
            if (move != null) {
              position = ChessPositionUtils.makeMove(beforeLast, move);
            }
          }
        }
      }
    }

    // Fallback: Build position from UCI or SAN moves if FEN approach failed
    if (position == null) {
      final uciMoves = state.review!.moves.map((m) => m.uci).toList();
      // Try UCI moves first
      if (uciMoves.isNotEmpty && uciMoves.first.isNotEmpty) {
        position = ChessPositionUtils.buildPositionFromMoves(
          uciMoves,
          upToIndex: clampedIndex,
        );
      }

      // Try SAN moves if UCI didn't work
      if (position == null) {
        final sanMoves = state.review!.moves.map((m) => m.san).toList();
        if (sanMoves.isNotEmpty && sanMoves.first.isNotEmpty) {
          position = ChessPositionUtils.buildPositionFromSanMoves(
            sanMoves,
            upToIndex: clampedIndex,
          );
        }
      }

      // Last resort: use initial position
      if (position == null) {
        position = Chess.initial;
        debugPrint('WARNING: Could not build position for move $clampedIndex - using initial position');
      }
    }

    state = state.copyWith(
      currentMoveIndex: clampedIndex,
      position: position,
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

  /// Cancel ongoing analysis
  void cancelAnalysis() {
    if (_analysisService.isAnalyzing) {
      debugPrint('GameReviewNotifier: Cancelling analysis...');
      _analysisService.cancelAnalysis();
      state = state.copyWith(
        isAnalyzing: false,
        analysisMessage: 'Analysis cancelled',
      );
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    // Cancel any ongoing analysis before disposing
    cancelAnalysis();
    _analysisService.dispose();
    super.dispose();
  }
}

/// Provider factory for game review
final gameReviewProvider = StateNotifierProvider.autoDispose
    .family<GameReviewNotifier, GameReviewState, String>(
  (ref, userId) => GameReviewNotifier(userId: userId),
);
