import 'dart:async';
import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../../analysis/services/stockfish_service.dart';
import '../../analysis/services/uci_parser.dart';
import '../models/analyzed_move.dart';
import '../models/chess_game.dart';
import '../models/game_review.dart';
import '../models/move_classification.dart';

/// Service for analyzing chess games with Stockfish
class GameAnalysisService {
  final StockfishService _stockfish;
  final int analysisDepth;

  bool _isAnalyzing = false;
  StreamController<AnalysisProgress>? _progressController;

  GameAnalysisService({
    StockfishService? stockfish,
    this.analysisDepth = 18,
  }) : _stockfish = stockfish ?? StockfishService();

  /// Stream of analysis progress updates
  Stream<AnalysisProgress>? get progressStream => _progressController?.stream;

  /// Whether analysis is in progress
  bool get isAnalyzing => _isAnalyzing;

  /// Analyze a game and return the review
  Future<GameReview> analyzeGame({
    required ChessGame game,
    required String userId,
    void Function(AnalysisProgress)? onProgress,
  }) async {
    if (_isAnalyzing) {
      throw StateError('Analysis already in progress');
    }

    _isAnalyzing = true;
    _progressController = StreamController<AnalysisProgress>.broadcast();

    final reviewId = const Uuid().v4();
    final createdAt = DateTime.now();

    try {
      // Initialize Stockfish if needed
      if (_stockfish.state == StockfishState.uninitialized) {
        _reportProgress(0, 'Initializing engine...', onProgress);
        await _stockfish.initialize();
      }

      // Parse the PGN to get positions
      _reportProgress(0, 'Parsing game...', onProgress);
      final positions = _parsePgn(game.pgn);

      if (positions.isEmpty) {
        throw ArgumentError('No moves found in PGN');
      }

      // Create initial review record
      await LocalDatabase.saveGameReview({
        'id': reviewId,
        'user_id': userId,
        'game_id': game.id,
        'status': 'analyzing',
        'progress': 0.0,
        'depth': analysisDepth,
        'created_at': createdAt.toIso8601String(),
      });

      // Analyze each position
      final analyzedMoves = <AnalyzedMove>[];
      int? previousEval;
      int? previousMate;

      for (var i = 0; i < positions.length; i++) {
        final pos = positions[i];
        final progress = (i + 1) / positions.length;

        _reportProgress(progress, 'Analyzing move ${i + 1}/${positions.length}', onProgress);

        // Update database progress
        await LocalDatabase.updateGameReviewProgress(
          reviewId,
          progress,
          'analyzing',
        );

        // Analyze position before the move
        final evalResult = await _analyzePosition(pos.fenBefore);

        // Calculate centipawn loss
        final currentEval = evalResult.centipawns;
        final currentMate = evalResult.mateInMoves;

        int cpl = 0;
        if (previousEval != null && currentEval != null) {
          // Calculate loss from the player's perspective
          if (pos.color == 'white') {
            cpl = (previousEval - currentEval).clamp(0, 999);
          } else {
            cpl = (currentEval - previousEval).clamp(0, 999);
          }
        }

        // Check for missed wins
        bool isMiss = false;
        if (previousMate != null && previousMate > 0 && currentMate == null) {
          isMiss = true; // Had mate, now doesn't
        }

        // Get best move for comparison
        final bestMoveResult = await _getBestMove(pos.fenBefore);

        // Classify the move
        final classification = MoveClassificationExtension.fromCentipawnLoss(
          cpl,
          isBestMove: bestMoveResult.uci == pos.uci,
          isBookMove: i < 10 && cpl == 0, // Simple book detection for first 10 moves
          isMiss: isMiss,
          isForced: pos.legalMoveCount == 1,
        );

        final analyzedMove = AnalyzedMove(
          id: const Uuid().v4(),
          gameReviewId: reviewId,
          moveNumber: i + 1,
          color: pos.color,
          fen: pos.fenBefore,
          san: pos.san,
          uci: pos.uci,
          classification: classification,
          evalBefore: previousEval,
          evalAfter: currentEval,
          mateBefore: previousMate,
          mateAfter: currentMate,
          bestMove: bestMoveResult.san,
          bestMoveUci: bestMoveResult.uci,
          centipawnLoss: cpl,
          hasPuzzle: classification.isPuzzleWorthy,
        );

        analyzedMoves.add(analyzedMove);

        // Update previous eval for next iteration
        // Use the eval after this move (which is the eval before the opponent's move)
        final evalAfterMove = await _analyzePosition(pos.fenAfter);
        previousEval = evalAfterMove.centipawns;
        previousMate = evalAfterMove.mateInMoves;
      }

      // Calculate summaries
      final whiteMoves = analyzedMoves.where((m) => m.color == 'white').toList();
      final blackMoves = analyzedMoves.where((m) => m.color == 'black').toList();

      final whiteSummary = AccuracySummary.fromMoves(whiteMoves);
      final blackSummary = AccuracySummary.fromMoves(blackMoves);

      // Save moves
      await LocalDatabase.saveAnalyzedMoves(
        analyzedMoves.map((m) => m.toJson()).toList(),
      );

      // Complete the review
      await LocalDatabase.completeGameReview(
        reviewId,
        jsonEncode(whiteSummary.toJson()),
        jsonEncode(blackSummary.toJson()),
      );

      // Generate puzzles from mistakes
      await _generatePuzzles(
        userId: userId,
        reviewId: reviewId,
        moves: analyzedMoves,
        game: game,
      );

      _reportProgress(1.0, 'Analysis complete!', onProgress);

      return GameReview(
        id: reviewId,
        userId: userId,
        gameId: game.id,
        game: game,
        status: ReviewStatus.completed,
        progress: 1.0,
        whiteSummary: whiteSummary,
        blackSummary: blackSummary,
        moves: analyzedMoves,
        depth: analysisDepth,
        analyzedAt: DateTime.now(),
        createdAt: createdAt,
      );
    } catch (e) {
      debugPrint('Analysis error: $e');

      // Update review with error
      await LocalDatabase.saveGameReview({
        'id': reviewId,
        'user_id': userId,
        'game_id': game.id,
        'status': 'failed',
        'progress': 0.0,
        'depth': analysisDepth,
        'created_at': createdAt.toIso8601String(),
        'error_message': e.toString(),
      });

      rethrow;
    } finally {
      _isAnalyzing = false;
      await _progressController?.close();
      _progressController = null;
    }
  }

  void _reportProgress(
    double progress,
    String message,
    void Function(AnalysisProgress)? onProgress,
  ) {
    final update = AnalysisProgress(progress: progress, message: message);
    _progressController?.add(update);
    onProgress?.call(update);
  }

  /// Parse PGN and extract all positions
  List<_ParsedMove> _parsePgn(String pgn) {
    final moves = <_ParsedMove>[];

    try {
      // Extract moves section (after headers)
      final moveText = pgn
          .split('\n')
          .where((line) => !line.startsWith('[') && line.trim().isNotEmpty)
          .join(' ')
          .replaceAll(RegExp(r'\{[^}]*\}'), '') // Remove comments
          .replaceAll(RegExp(r'\([^)]*\)'), '') // Remove variations
          .replaceAll(RegExp(r'\$\d+'), '') // Remove NAGs
          .replaceAll(RegExp(r'\d+\.\.\.'), '') // Remove move continuation dots
          .replaceAll(RegExp(r'1-0|0-1|1/2-1/2|\*'), '') // Remove result
          .trim();

      // Parse move tokens
      final tokens = moveText.split(RegExp(r'\s+'));
      var position = Chess.initial;

      for (final token in tokens) {
        if (token.isEmpty) continue;

        // Skip move numbers
        if (RegExp(r'^\d+\.?$').hasMatch(token)) continue;

        final fenBefore = position.fen;
        final sideToMove = position.turn;

        try {
          // Parse and play the move
          final move = position.parseSan(token);
          if (move == null) continue;

          final legalMoves = position.legalMoves.length;

          // Play the move
          final result = position.play(move);
          position = result as Chess;

          moves.add(_ParsedMove(
            san: token,
            uci: move.uci,
            fenBefore: fenBefore,
            fenAfter: position.fen,
            color: sideToMove == Side.white ? 'white' : 'black',
            legalMoveCount: legalMoves,
          ));
        } catch (e) {
          debugPrint('Error parsing move $token: $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('Error parsing PGN: $e');
    }

    return moves;
  }

  /// Analyze a position and return the evaluation
  Future<_EvalResult> _analyzePosition(String fen) async {
    final completer = Completer<_EvalResult>();
    StreamSubscription<String>? subscription;

    subscription = _stockfish.outputStream.listen((line) {
      if (line.startsWith('info') && line.contains('depth $analysisDepth')) {
        final parsed = UciParser.parseInfo(line);
        if (parsed?.pv?.evaluation != null) {
          final eval = parsed!.pv!.evaluation;
          if (!completer.isCompleted) {
            completer.complete(_EvalResult(
              centipawns: eval.centipawns,
              mateInMoves: eval.mateInMoves,
            ));
          }
          subscription?.cancel();
        }
      }
    });

    _stockfish.setPosition(fen);
    _stockfish.startAnalysis(depth: analysisDepth);

    // Timeout after 5 seconds
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        subscription?.cancel();
        return _EvalResult(centipawns: 0);
      },
    );
  }

  /// Get best move for a position
  Future<_BestMoveResult> _getBestMove(String fen) async {
    final completer = Completer<_BestMoveResult>();
    StreamSubscription<String>? subscription;
    String? bestMoveUci;

    subscription = _stockfish.outputStream.listen((line) {
      if (line.startsWith('info') && line.contains('pv')) {
        final parsed = UciParser.parseInfo(line);
        if (parsed?.pv != null && parsed!.pv!.uciMoves.isNotEmpty) {
          bestMoveUci = parsed.pv!.uciMoves.first;
        }
      }

      if (line.startsWith('bestmove')) {
        final parts = line.split(' ');
        if (parts.length >= 2 && parts[1] != '(none)') {
          bestMoveUci = parts[1];
        }

        // Convert UCI to SAN
        String? san;
        if (bestMoveUci != null) {
          try {
            final position = Chess.fromSetup(Setup.parseFen(fen));
            final move = _parseUciMove(bestMoveUci!);
            if (move != null) {
              san = position.makeSan(move).$2;
            }
          } catch (e) {
            debugPrint('Error converting UCI to SAN: $e');
          }
        }

        if (!completer.isCompleted) {
          completer.complete(_BestMoveResult(
            uci: bestMoveUci ?? '',
            san: san ?? bestMoveUci ?? '',
          ));
        }
        subscription?.cancel();
      }
    });

    _stockfish.setPosition(fen);
    _stockfish.startAnalysis(depth: analysisDepth);

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        subscription?.cancel();
        return _BestMoveResult(uci: '', san: '');
      },
    );
  }

  /// Parse UCI move string to NormalMove
  NormalMove? _parseUciMove(String uci) {
    if (uci.length < 4) return null;

    try {
      final from = Square.fromName(uci.substring(0, 2));
      final to = Square.fromName(uci.substring(2, 4));

      Role? promotion;
      if (uci.length > 4) {
        switch (uci[4].toLowerCase()) {
          case 'q':
            promotion = Role.queen;
            break;
          case 'r':
            promotion = Role.rook;
            break;
          case 'b':
            promotion = Role.bishop;
            break;
          case 'n':
            promotion = Role.knight;
            break;
        }
      }

      return NormalMove(from: from, to: to, promotion: promotion);
    } catch (e) {
      return null;
    }
  }

  /// Generate puzzles from mistakes
  Future<void> _generatePuzzles({
    required String userId,
    required String reviewId,
    required List<AnalyzedMove> moves,
    required ChessGame game,
  }) async {
    // Only generate puzzles from player's mistakes
    final playerMistakes = moves
        .where((m) => m.color == game.playerColor)
        .where((m) => m.classification.isPuzzleWorthy)
        .toList();

    for (final move in playerMistakes) {
      if (move.bestMoveUci == null || move.bestMove == null) continue;

      await LocalDatabase.savePersonalMistake({
        'id': const Uuid().v4(),
        'user_id': userId,
        'game_review_id': reviewId,
        'move_id': move.id,
        'fen': move.fen,
        'solution_uci': move.bestMoveUci,
        'solution_san': move.bestMove,
        'classification': move.classification.name,
        'theme': _inferTheme(move),
        'rating': 1500, // Start at default rating
        'times_practiced': 0,
        'times_correct': 0,
        'ease_factor': 2.5,
        'interval_days': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  String? _inferTheme(AnalyzedMove move) {
    // Simple theme inference based on the best move
    final san = move.bestMove ?? '';

    if (san.contains('x')) return 'capture';
    if (san.contains('+')) return 'check';
    if (san.contains('#')) return 'checkmate';
    if (san.startsWith('O-O')) return 'castling';

    return null;
  }

  Future<void> dispose() async {
    await _stockfish.dispose();
    await _progressController?.close();
  }
}

/// Progress update during analysis
class AnalysisProgress {
  final double progress; // 0.0 to 1.0
  final String message;

  AnalysisProgress({
    required this.progress,
    required this.message,
  });
}

/// Internal class for parsed moves
class _ParsedMove {
  final String san;
  final String uci;
  final String fenBefore;
  final String fenAfter;
  final String color;
  final int legalMoveCount;

  _ParsedMove({
    required this.san,
    required this.uci,
    required this.fenBefore,
    required this.fenAfter,
    required this.color,
    required this.legalMoveCount,
  });
}

/// Internal class for evaluation results
class _EvalResult {
  final int? centipawns;
  final int? mateInMoves;

  _EvalResult({
    this.centipawns,
    this.mateInMoves,
  });
}

/// Internal class for best move results
class _BestMoveResult {
  final String uci;
  final String san;

  _BestMoveResult({
    required this.uci,
    required this.san,
  });
}
