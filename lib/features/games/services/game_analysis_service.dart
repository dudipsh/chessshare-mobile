import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartchess/dartchess.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/supabase_service.dart';
import '../../../core/database/local_database.dart';
import '../../../core/repositories/games_repository.dart';
import '../../../core/services/global_stockfish_manager.dart';
import '../../analysis/services/stockfish_service.dart';
import '../../analysis/services/uci_parser.dart';
import '../models/analyzed_move.dart';
import '../models/chess_game.dart';
import '../models/game_review.dart';
import '../utils/chess_position_utils.dart';
import 'book_move_detector.dart';
import 'brilliant_move_classifier.dart';

/// Configuration for game analysis
class AnalysisConfig {
  /// Depth for quick analysis (most moves)
  final int quickDepth;

  /// Depth for critical positions (captures, checks, low eval swings)
  final int criticalDepth;

  /// Max time per move in milliseconds (fallback if depth not reached)
  final int maxMoveTimeMs;

  /// Number of threads for Stockfish (0 = auto-detect based on CPU cores)
  final int _threads;

  /// Hash table size in MB
  final int hashSizeMb;

  const AnalysisConfig({
    this.quickDepth = 12,
    this.criticalDepth = 16,
    this.maxMoveTimeMs = 500,
    int threads = 0,
    this.hashSizeMb = 64,
  }) : _threads = threads;

  /// Get optimal thread count based on CPU cores
  /// Uses half of available cores (leave some for UI), min 2, max 8
  static int get optimalThreads {
    final cores = Platform.numberOfProcessors;
    return (cores ~/ 2).clamp(2, 8);
  }

  /// Actual threads to use (auto-detect if 0)
  int get threads => _threads > 0 ? _threads : optimalThreads;

  /// Fast config for quick analysis (uses dynamic thread count via threads=0)
  static const fast = AnalysisConfig(
    quickDepth: 10,
    criticalDepth: 14,
    maxMoveTimeMs: 300,
    threads: 0, // Auto-detect at runtime
    hashSizeMb: 32,
  );

  /// Balanced config (default, uses dynamic thread count via threads=0)
  static const balanced = AnalysisConfig(
    quickDepth: 12,
    criticalDepth: 16,
    maxMoveTimeMs: 500,
    threads: 0, // Auto-detect at runtime
    hashSizeMb: 64,
  );

  /// Deep config for thorough analysis (uses dynamic thread count via threads=0)
  static const deep = AnalysisConfig(
    quickDepth: 16,
    criticalDepth: 20,
    maxMoveTimeMs: 1000,
    threads: 0, // Auto-detect at runtime
    hashSizeMb: 128,
  );
}

/// Service for analyzing chess games with Stockfish
class GameAnalysisService {
  static const _ownerId = 'shared'; // Use shared owner to reuse pre-loaded instance

  StockfishService? _stockfish;
  final AnalysisConfig config;

  bool _isAnalyzing = false;
  bool _isCancelled = false;
  StreamController<AnalysisProgress>? _progressController;

  // Cache for position evaluations to avoid re-analyzing
  final Map<String, _EvalResult> _evalCache = {};

  // Book move detector
  final BookMoveDetector _bookMoveDetector = BookMoveDetector();

  // Brilliant move classifier (strict, like web version)
  final BrilliantMoveClassifier _brilliantClassifier = BrilliantMoveClassifier();

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

        // Analyze position BEFORE the move (with best move in same call - optimization!)
        // This reduces engine calls from 3 per move to 2 per move
        final isCritical = i < 5 || i > positions.length - 5;
        final evalBefore = await _analyzePositionFast(pos.fenBefore, isCritical: isCritical, needBestMove: true);

        // Check cancellation after engine analysis
        if (_isCancelled) {
          throw StateError('Analysis cancelled');
        }

        // Analyze position AFTER the move
        // Note: This result will be cached and reused as evalBefore for the next move
        final evalAfter = await _analyzePositionFast(pos.fenAfter, isCritical: false);

        final evalBeforeCp = evalBefore.centipawns;
        final evalAfterCp = evalAfter.centipawns;
        final mateBefore = evalBefore.mateInMoves;
        final mateAfter = evalAfter.mateInMoves;

        // Best move was captured in the evalBefore call (optimization)
        final bestMoveUci = evalBefore.bestMoveUci ?? '';
        final bestMoveSan = evalBefore.bestMoveSan ?? '';

        // Check if the played move is the best move (case-insensitive like web)
        // Also handle potential whitespace/null issues
        final normalizedBestMove = bestMoveUci.trim().toLowerCase();
        final normalizedPlayedMove = pos.uci.trim().toLowerCase();
        final isBestMove = normalizedBestMove.isNotEmpty &&
                          normalizedPlayedMove.isNotEmpty &&
                          normalizedBestMove == normalizedPlayedMove;

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

        // Note: The web classifies "MISS" purely based on centipawn loss (60-100cp),
        // NOT based on missed mates. We follow the same approach for consistency.
        // Mate-based miss detection was removed as it caused false positives at low depth.
        const isMiss = false;

        // Check if this is a check move (for Great move detection)
        final isCheck = pos.san.contains('+') || pos.san.contains('#');

        // Check for brilliant move using strict classifier (like web version)
        final isBrilliant = evalBeforeCp != null && evalAfterCp != null
            ? _brilliantClassifier.isBrilliant(BrilliantContext(
                fenBefore: pos.fenBefore,
                moveSan: pos.san,
                moveUci: pos.uci,
                evalBefore: evalBeforeCp,
                evalAfter: evalAfterCp,
                isWhiteMove: pos.color == 'white',
                centipawnLoss: cpl,
                legalMoveCount: pos.legalMoveCount,
                mateBefore: mateBefore,
                mateAfter: mateAfter,
              ))
            : false;

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

      // Generate puzzles from mistakes (locally)
      final puzzleMoves = await _generatePuzzles(
        userId: userId,
        reviewId: reviewId,
        moves: analyzedMoves,
        game: game,
      );

      // Sync to server if authenticated
      await _syncToServer(
        game: game,
        reviewId: reviewId,
        analyzedMoves: analyzedMoves,
        whiteSummary: whiteSummary,
        blackSummary: blackSummary,
        puzzleMoves: puzzleMoves,
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

      // Release Stockfish after analysis completes
      if (_stockfish != null) {
        await GlobalStockfishManager.instance.release(_ownerId);
        _stockfish = null;
      }
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
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      // PGN parsing error
    }

    return moves;
  }

  /// Fast position analysis with caching - captures both eval AND best move in one call
  /// This is a major optimization: instead of 3 engine calls per move (evalBefore, evalAfter, bestMove),
  /// we now do 2 calls (evalBefore with bestMove, evalAfter)
  Future<_EvalResult> _analyzePositionFast(String fen, {bool isCritical = false, bool needBestMove = false}) async {
    final requiredDepth = isCritical ? config.criticalDepth : config.quickDepth;

    // Check cache - only use if cached at sufficient depth
    if (_evalCache.containsKey(fen)) {
      final cached = _evalCache[fen]!;
      // Reuse if cached depth is sufficient and we have best move if needed
      if (cached.depth >= requiredDepth && (!needBestMove || cached.bestMoveUci != null)) {
        return cached;
      }
    }

    // IMPORTANT: Stop any ongoing analysis before starting new one
    // This prevents race conditions where old analysis output gets captured
    _stockfish!.stop();
    await Future.delayed(const Duration(milliseconds: 10));

    // Determine whose turn it is from the FEN
    // FEN format: pieces turn castling enpassant halfmove fullmove
    final isBlackToMove = fen.split(' ').length > 1 && fen.split(' ')[1] == 'b';

    final completer = Completer<_EvalResult>();
    StreamSubscription<String>? subscription;
    int? lastCp;
    int? lastMate;
    String? lastBestMoveUci;
    int lastDepth = 0;
    bool positionSet = false;

    subscription = _stockfish!.outputStream.listen((line) {
      // Only process output after we've set the position
      if (!positionSet) return;

      if (line.startsWith('info') && line.contains('depth')) {
        final parsed = UciParser.parseInfo(line);
        if (parsed?.pv?.evaluation != null) {
          final eval = parsed!.pv!.evaluation;
          // Stockfish reports score from side-to-move's perspective
          // We need to normalize to White's perspective (positive = good for White)
          final cp = eval.centipawns;
          final mate = eval.mateInMoves;
          lastCp = isBlackToMove && cp != null ? -cp : cp;
          lastMate = isBlackToMove && mate != null ? -mate : mate;

          // Capture best move from PV
          if (parsed.pv!.uciMoves.isNotEmpty) {
            final candidateMove = parsed.pv!.uciMoves.first;
            // Validate that this move is legal for the current position
            if (ChessPositionUtils.validateMove(fen, candidateMove) != null) {
              lastBestMoveUci = candidateMove;
            }
          }

          // Track actual depth reached
          final depthMatch = RegExp(r'depth (\d+)').firstMatch(line);
          if (depthMatch != null) {
            lastDepth = int.parse(depthMatch.group(1)!);
          }

          // Check if we reached target depth
          if (lastDepth >= requiredDepth) {
            if (!completer.isCompleted) {
              String? bestMoveSan;
              if (lastBestMoveUci != null) {
                try {
                  final position = Chess.fromSetup(Setup.parseFen(fen));
                  final move = _parseUciMove(lastBestMoveUci!);
                  if (move != null && position.isLegal(move)) {
                    bestMoveSan = position.makeSan(move).$2;
                  }
                } catch (_) {}
              }
              completer.complete(_EvalResult(
                centipawns: lastCp,
                mateInMoves: lastMate,
                bestMoveUci: lastBestMoveUci,
                bestMoveSan: bestMoveSan,
                depth: lastDepth,
              ));
            }
            subscription?.cancel();
          }
        }
      }

      // Also capture bestmove line as backup
      if (needBestMove && line.startsWith('bestmove') && lastBestMoveUci == null) {
        final parts = line.split(' ');
        if (parts.length >= 2 && parts[1] != '(none)') {
          final candidateMove = parts[1];
          if (ChessPositionUtils.validateMove(fen, candidateMove) != null) {
            lastBestMoveUci = candidateMove;
          }
        }
      }
    });

    _stockfish!.setPosition(fen);
    positionSet = true;
    _stockfish!.startAnalysis(moveTimeMs: config.maxMoveTimeMs);

    // Use time-based timeout
    final result = await completer.future.timeout(
      Duration(milliseconds: config.maxMoveTimeMs + 200),
      onTimeout: () {
        subscription?.cancel();
        _stockfish!.stop();

        String? bestMoveSan;
        if (lastBestMoveUci != null) {
          try {
            final position = Chess.fromSetup(Setup.parseFen(fen));
            final move = _parseUciMove(lastBestMoveUci!);
            if (move != null && position.isLegal(move)) {
              bestMoveSan = position.makeSan(move).$2;
            }
          } catch (_) {}
        }

        return _EvalResult(
          centipawns: lastCp ?? 0,
          mateInMoves: lastMate,
          bestMoveUci: lastBestMoveUci,
          bestMoveSan: bestMoveSan,
          depth: lastDepth,
        );
      },
    );

    // Cache the result
    _evalCache[fen] = result;
    return result;
  }

  /// Sync analysis results to server (if authenticated)
  Future<void> _syncToServer({
    required ChessGame game,
    required String reviewId,
    required List<AnalyzedMove> analyzedMoves,
    required AccuracySummary whiteSummary,
    required AccuracySummary blackSummary,
    required List<AnalyzedMove> puzzleMoves,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      return;
    }

    try {

      // 1. Save game review metadata
      final serverReviewId = await GamesRepository.saveGameReview(
        externalGameId: game.externalId,
        platform: game.platform == GamePlatform.chesscom ? 'chesscom' : 'lichess',
        pgn: game.pgn,
        playerColor: game.playerColor,
        gameResult: game.result.name,
        speed: game.speed.name,
        timeControl: game.timeControl,
        playedAt: game.playedAt,
        opponentUsername: game.opponentUsername,
        opponentRating: game.opponentRating,
        playerRating: game.playerRating,
        openingEco: game.openingEco,
        openingName: game.openingName,
        accuracyWhite: whiteSummary.accuracy,
        accuracyBlack: blackSummary.accuracy,
        movesTotal: analyzedMoves.length,
        movesBook: analyzedMoves.where((m) => m.classification == MoveClassification.book).length,
        movesBrilliant: analyzedMoves.where((m) => m.classification == MoveClassification.brilliant).length,
        movesGreat: analyzedMoves.where((m) => m.classification == MoveClassification.great).length,
        movesBest: analyzedMoves.where((m) => m.classification == MoveClassification.best).length,
        movesGood: analyzedMoves.where((m) => m.classification == MoveClassification.good).length,
        movesInaccuracy: analyzedMoves.where((m) => m.classification == MoveClassification.inaccuracy).length,
        movesMistake: analyzedMoves.where((m) => m.classification == MoveClassification.mistake).length,
        movesBlunder: analyzedMoves.where((m) => m.classification == MoveClassification.blunder).length,
      );

      if (serverReviewId == null) {
        return;
      }

      // 2. Save move evaluations
      final movesData = analyzedMoves.map((m) => {
        'move_index': m.moveNumber - 1,
        'fen': m.fen,
        'san': m.san,
        'evaluation_before': m.evalBefore,
        'evaluation_after': m.evalAfter,
        'marker_type': m.classification.name,
        'best_move': m.bestMove,
        'centipawn_loss': m.centipawnLoss,
      }).toList();

      await GamesRepository.saveGameReviewMoves(
        gameReviewId: serverReviewId,
        moves: movesData,
      );

      // 3. Save personal mistakes (puzzles)
      if (puzzleMoves.isNotEmpty) {
        final mistakesData = puzzleMoves
            .where((m) => m.bestMoveUci != null)
            .map((m) => {
              'fen': m.fen,
              'solution_sequence': [m.bestMoveUci],
              'classification': m.classification.name,
              'theme': _inferTheme(m),
            })
            .toList();

        if (mistakesData.isNotEmpty) {
          await GamesRepository.savePersonalMistakes(
            gameReviewId: serverReviewId,
            mistakes: mistakesData,
          );
        }
      }
    } catch (_) {
      // Don't throw - server sync failure shouldn't break local analysis
    }
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

  /// Generate puzzles from mistakes - returns the puzzle data for server sync
  Future<List<AnalyzedMove>> _generatePuzzles({
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

    return playerMistakes;
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
    // Cancel any ongoing analysis
    cancelAnalysis();
    // Release Stockfish to global manager if still held
    if (_stockfish != null) {
      await GlobalStockfishManager.instance.release(_ownerId);
      _stockfish = null;
    }
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

/// Internal class for evaluation results (includes best move for efficiency)
class _EvalResult {
  final int? centipawns;
  final int? mateInMoves;
  final String? bestMoveUci;
  final String? bestMoveSan;
  final int depth;

  _EvalResult({
    this.centipawns,
    this.mateInMoves,
    this.bestMoveUci,
    this.bestMoveSan,
    this.depth = 0,
  });
}

