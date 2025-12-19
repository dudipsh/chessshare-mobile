import 'dart:async';
import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../../../core/services/global_stockfish_manager.dart';
import '../../analysis/services/stockfish_service.dart';
import '../../analysis/services/uci_parser.dart';
import '../models/analyzed_move.dart';
import '../models/chess_game.dart';
import '../models/game_review.dart';
import '../models/move_classification.dart';
import 'book_move_detector.dart';

/// Configuration for game analysis
class AnalysisConfig {
  /// Depth for quick analysis (most moves)
  final int quickDepth;

  /// Depth for critical positions (captures, checks, low eval swings)
  final int criticalDepth;

  /// Max time per move in milliseconds (fallback if depth not reached)
  final int maxMoveTimeMs;

  /// Number of threads for Stockfish
  final int threads;

  /// Hash table size in MB
  final int hashSizeMb;

  const AnalysisConfig({
    this.quickDepth = 12,
    this.criticalDepth = 16,
    this.maxMoveTimeMs = 500,
    this.threads = 2,
    this.hashSizeMb = 64,
  });

  /// Fast config for quick analysis
  static const fast = AnalysisConfig(
    quickDepth: 10,
    criticalDepth: 14,
    maxMoveTimeMs: 300,
    threads: 2,
    hashSizeMb: 32,
  );

  /// Balanced config (default)
  static const balanced = AnalysisConfig(
    quickDepth: 12,
    criticalDepth: 16,
    maxMoveTimeMs: 500,
    threads: 2,
    hashSizeMb: 64,
  );

  /// Deep config for thorough analysis
  static const deep = AnalysisConfig(
    quickDepth: 16,
    criticalDepth: 20,
    maxMoveTimeMs: 1000,
    threads: 4,
    hashSizeMb: 128,
  );
}

/// Service for analyzing chess games with Stockfish
class GameAnalysisService {
  static const _ownerId = 'GameAnalysisService';

  StockfishService? _stockfish;
  final AnalysisConfig config;

  bool _isAnalyzing = false;
  bool _isCancelled = false;
  StreamController<AnalysisProgress>? _progressController;

  // Cache for position evaluations to avoid re-analyzing
  final Map<String, _EvalResult> _evalCache = {};

  // Book move detector
  final BookMoveDetector _bookMoveDetector = BookMoveDetector();

  // Cache for book moves (move index -> is book)
  final Map<int, bool> _bookMoveCache = {};

  GameAnalysisService({
    this.config = AnalysisConfig.fast,
  });

  /// Stream of analysis progress updates
  Stream<AnalysisProgress>? get progressStream => _progressController?.stream;

  /// Whether analysis is in progress
  bool get isAnalyzing => _isAnalyzing;

  /// Cancel the current analysis
  void cancelAnalysis() {
    if (_isAnalyzing) {
      debugPrint('GameAnalysisService: Cancelling analysis...');
      _isCancelled = true;
    }
  }

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
    _isCancelled = false;
    _progressController = StreamController<AnalysisProgress>.broadcast();
    _evalCache.clear();
    _bookMoveCache.clear();

    final reviewId = const Uuid().v4();
    final createdAt = DateTime.now();

    try {
      // Acquire Stockfish from global manager
      _reportProgress(0, 'Initializing engine...', onProgress);
      _stockfish = await GlobalStockfishManager.instance.acquire(
        _ownerId,
        config: StockfishConfig(
          multiPv: 1,
          hashSizeMb: config.hashSizeMb,
          threads: config.threads,
          maxDepth: config.criticalDepth,
        ),
      );

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
        'depth': config.quickDepth,
        'created_at': createdAt.toIso8601String(),
      });

      // Analyze each position - optimized with caching and time limits
      final analyzedMoves = <AnalyzedMove>[];

      // First pass: get all evaluations (using cache)
      _reportProgress(0, 'Evaluating positions...', onProgress);

      for (var i = 0; i < positions.length; i++) {
        // Check for cancellation
        if (_isCancelled) {
          debugPrint('GameAnalysisService: Analysis cancelled at move $i');
          throw StateError('Analysis cancelled');
        }

        final pos = positions[i];
        final progress = (i + 1) / positions.length;

        _reportProgress(progress * 0.8, 'Move ${i + 1}/${positions.length}', onProgress);

        // Update database progress every 5 moves
        if (i % 5 == 0) {
          await LocalDatabase.updateGameReviewProgress(
            reviewId,
            progress * 0.8,
            'analyzing',
          );
        }

        // Check for book move using ECO database
        final bookResult = _bookMoveDetector.isBookMove(
          pos.fenBefore,
          pos.uci,
          i + 1,
          moveSan: pos.san,
        );
        final isBookMove = bookResult.isBook;
        _bookMoveCache[i] = isBookMove;

        // If it's a book move, skip engine analysis
        if (isBookMove) {
          final analyzedMove = AnalyzedMove(
            id: const Uuid().v4(),
            gameReviewId: reviewId,
            moveNumber: i + 1,
            color: pos.color,
            fen: pos.fenBefore,
            san: pos.san,
            uci: pos.uci,
            classification: MoveClassification.book,
            evalBefore: null,
            evalAfter: null,
            mateBefore: null,
            mateAfter: null,
            bestMove: pos.san,
            bestMoveUci: pos.uci,
            centipawnLoss: 0,
            hasPuzzle: false,
          );
          analyzedMoves.add(analyzedMove);
          continue;
        }

        // Analyze position BEFORE the move
        final evalBefore = await _analyzePositionFast(pos.fenBefore, isCritical: i < 5 || i > positions.length - 5);

        // Check cancellation after engine analysis
        if (_isCancelled) {
          debugPrint('GameAnalysisService: Analysis cancelled at move $i');
          throw StateError('Analysis cancelled');
        }

        // Analyze position AFTER the move
        final evalAfter = await _analyzePositionFast(pos.fenAfter, isCritical: false);

        final evalBeforeCp = evalBefore.centipawns;
        final evalAfterCp = evalAfter.centipawns;
        final mateBefore = evalBefore.mateInMoves;
        final mateAfter = evalAfter.mateInMoves;

        // Get best move for this position
        final bestMoveResult = await _getBestMoveFast(pos.fenBefore);
        final bestMoveUci = bestMoveResult.uci;
        final bestMoveSan = bestMoveResult.san;

        // Check if the played move is the best move
        final isBestMove = bestMoveUci == pos.uci;

        // Calculate centipawn loss properly:
        // CPL = eval if best move was played - eval after actual move
        // For White: higher eval is better, so loss = best_eval - actual_eval
        // For Black: lower eval is better (from engine perspective which is always White POV)
        int cpl = 0;
        if (evalBeforeCp != null && evalAfterCp != null && !isBestMove) {
          if (pos.color == 'white') {
            // White wants higher eval. If eval dropped, that's a loss.
            // Before: eval of position before move (what White could maintain with best play)
            // After: eval after White's move (what White actually got)
            // Loss = what we had - what we got (if negative, no loss)
            cpl = (evalBeforeCp - evalAfterCp).clamp(0, 999);
          } else {
            // Black wants lower eval (engine gives positive = good for White)
            // If eval increased after Black's move, that's bad for Black
            // Loss = what we got - what we had (if eval went up, Black lost advantage)
            cpl = (evalAfterCp - evalBeforeCp).clamp(0, 999);
          }
        }

        // Check for missed wins (had mate, now doesn't)
        bool isMiss = false;
        if (mateBefore != null && mateAfter == null) {
          // Had a forced mate before, but not after the move
          if (pos.color == 'white' && mateBefore > 0) {
            isMiss = true; // White had mate in N, now doesn't
          } else if (pos.color == 'black' && mateBefore < 0) {
            isMiss = true; // Black had mate in N (negative), now doesn't
          }
        }

        // Check if this is a check move (for Great move detection)
        final isCheck = pos.san.contains('+') || pos.san.contains('#');

        // Check for brilliant move (sacrifice with good result)
        final isBrilliant = _detectBrilliantMove(
          san: pos.san,
          cpl: cpl,
          evalBefore: evalBeforeCp,
          evalAfter: evalAfterCp,
          legalMoveCount: pos.legalMoveCount,
        );

        // Check for great move (forcing check with ≤15cp loss)
        final isGreat = isCheck && cpl <= ClassificationThresholds.best && !isBrilliant;

        // Classify the move with game phase forgiveness and position context
        // Note: Book moves are handled above and skip this section
        final classification = MoveClassificationExtension.fromCentipawnLoss(
          cpl,
          isBestMove: isBestMove,
          isBookMove: false, // Book moves are already handled above
          isBrilliant: isBrilliant,
          isGreat: isGreat,
          isMiss: isMiss,
          isForced: pos.legalMoveCount == 1,
          moveNumber: i + 1,
          evalBefore: evalBeforeCp,
          evalAfter: evalAfterCp,
          isCheck: isCheck,
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
          evalBefore: evalBeforeCp,
          evalAfter: evalAfterCp,
          mateBefore: mateBefore,
          mateAfter: mateAfter,
          bestMove: bestMoveSan,
          bestMoveUci: bestMoveUci,
          centipawnLoss: cpl,
          hasPuzzle: classification.isPuzzleWorthy,
        );

        analyzedMoves.add(analyzedMove);
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
        depth: config.quickDepth,
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
        'depth': config.quickDepth,
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

  /// Fast position analysis with caching
  Future<_EvalResult> _analyzePositionFast(String fen, {bool isCritical = false}) async {
    // Check cache first
    if (_evalCache.containsKey(fen)) {
      return _evalCache[fen]!;
    }

    final depth = isCritical ? config.criticalDepth : config.quickDepth;
    final completer = Completer<_EvalResult>();
    StreamSubscription<String>? subscription;
    _EvalResult? lastResult;

    subscription = _stockfish!.outputStream.listen((line) {
      if (line.startsWith('info') && line.contains('depth')) {
        final parsed = UciParser.parseInfo(line);
        if (parsed?.pv?.evaluation != null) {
          final eval = parsed!.pv!.evaluation;
          lastResult = _EvalResult(
            centipawns: eval.centipawns,
            mateInMoves: eval.mateInMoves,
          );

          // Check if we reached target depth
          if (line.contains('depth $depth')) {
            if (!completer.isCompleted) {
              completer.complete(lastResult);
            }
            subscription?.cancel();
          }
        }
      }
    });

    _stockfish!.setPosition(fen);
    _stockfish!.startAnalysis(moveTimeMs: config.maxMoveTimeMs);

    // Use time-based timeout
    final result = await completer.future.timeout(
      Duration(milliseconds: config.maxMoveTimeMs + 200),
      onTimeout: () {
        subscription?.cancel();
        _stockfish!.stop();
        return lastResult ?? _EvalResult(centipawns: 0);
      },
    );

    // Cache the result
    _evalCache[fen] = result;
    return result;
  }

  /// Legacy method for compatibility
  Future<_EvalResult> _analyzePosition(String fen) async {
    return _analyzePositionFast(fen, isCritical: true);
  }

  /// Get best move for a position (fast version)
  Future<_BestMoveResult> _getBestMoveFast(String fen) async {
    final completer = Completer<_BestMoveResult>();
    StreamSubscription<String>? subscription;
    String? bestMoveUci;

    subscription = _stockfish!.outputStream.listen((line) {
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

    _stockfish!.setPosition(fen);
    _stockfish!.startAnalysis(moveTimeMs: config.maxMoveTimeMs);

    return completer.future.timeout(
      Duration(milliseconds: config.maxMoveTimeMs + 200),
      onTimeout: () {
        subscription?.cancel();
        _stockfish!.stop();
        return _BestMoveResult(uci: '', san: '');
      },
    );
  }

  /// Legacy method for compatibility
  Future<_BestMoveResult> _getBestMove(String fen) async {
    return _getBestMoveFast(fen);
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

  /// Detect brilliant moves (sacrifices that lead to improvement)
  /// Based on web version: BrilliantMoveClassifier.ts
  bool _detectBrilliantMove({
    required String san,
    required int cpl,
    int? evalBefore,
    int? evalAfter,
    required int legalMoveCount,
  }) {
    // Must have low centipawn loss
    if (cpl > ClassificationThresholds.brilliantMaxCpl) return false;

    // Must not be a forced move
    if (legalMoveCount <= 1) return false;

    // Must have valid evaluations
    if (evalBefore == null || evalAfter == null) return false;

    // Must not already be winning significantly
    if (evalBefore > ClassificationThresholds.brilliantMaxEvalBefore) return false;
    if (evalBefore < ClassificationThresholds.brilliantMinEvalBefore) return false;

    // Calculate improvement (from perspective of moving side)
    final improvement = evalAfter - evalBefore;

    // Must have significant improvement
    if (improvement < ClassificationThresholds.brilliantMinImprovement) return false;

    // Simple sacrifice detection: capture on a defended square
    // Full implementation would need SEE (Static Exchange Evaluation)
    // For now, use heuristics based on piece movements

    // Check for piece sacrifice patterns
    final isCapture = san.contains('x');
    final isPieceSacrifice = _isPieceSacrificePattern(san);

    // Must involve some form of sacrifice
    if (!isCapture && !isPieceSacrifice) return false;

    return true;
  }

  /// Check if move looks like a piece sacrifice
  bool _isPieceSacrificePattern(String san) {
    // Queen, Rook, Bishop, Knight moving to potentially attacked squares
    final piece = san.isNotEmpty ? san[0] : '';

    // Major piece moves (not pawns) that could be sacrifices
    if (piece == 'Q' || piece == 'R' || piece == 'B' || piece == 'N') {
      // Check for aggressive moves (captures or moves that look sacrificial)
      if (san.contains('x')) return true;

      // King-side or queen-side attacks often involve sacrifices
      if (san.contains('+')) return true;
    }

    return false;
  }

  Future<void> dispose() async {
    // Cancel any ongoing analysis
    cancelAnalysis();
    // Release Stockfish to global manager (don't dispose directly)
    await GlobalStockfishManager.instance.release(_ownerId);
    _stockfish = null;
    _evalCache.clear();
    _bookMoveCache.clear();
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
