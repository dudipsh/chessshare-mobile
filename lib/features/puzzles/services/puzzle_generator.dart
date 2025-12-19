import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:uuid/uuid.dart';

import '../../analysis/services/stockfish_service.dart';
import '../../analysis/services/uci_parser.dart';
import '../models/puzzle.dart';

/// Service that generates puzzles from a chess game
class PuzzleGenerator {
  final StockfishService _stockfish;
  bool _isInitialized = false;

  PuzzleGenerator() : _stockfish = StockfishService(
    config: const StockfishConfig(
      multiPv: 1,
      maxDepth: 18,
      hashSizeMb: 64,
    ),
  );

  /// Initialize the engine
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _stockfish.initialize();
    _isInitialized = true;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _stockfish.dispose();
    _isInitialized = false;
  }

  /// Generate puzzles from a PGN game
  Future<List<Puzzle>> generateFromPgn(String pgn) async {
    if (!_isInitialized) await initialize();

    final puzzles = <Puzzle>[];
    final game = PgnGame.parsePgn(pgn);

    Chess position = Chess.initial;
    final positions = <_PositionData>[];

    // Collect all positions with their moves
    for (final node in game.moves.mainline()) {
      final san = node.san;
      if (san == null) continue;

      final move = position.parseSan(san);
      if (move == null || move is! NormalMove) continue;

      positions.add(_PositionData(
        fen: position.fen,
        playedMove: move,
        playedSan: san,
      ));

      position = position.play(move) as Chess;
    }

    // Analyze positions to find tactical moments
    for (int i = 0; i < positions.length; i++) {
      final posData = positions[i];
      final analysis = await _analyzePosition(posData.fen);

      if (analysis != null && analysis.isTactical) {
        // Check if the played move was a blunder
        final playedMoveUci = '${posData.playedMove.from.name}${posData.playedMove.to.name}';

        if (analysis.bestMoveUci != playedMoveUci) {
          // Found a missed tactic - create puzzle from opponent's perspective
          // Get the position after the blunder
          if (i + 1 < positions.length) {
            final afterBlunderFen = positions[i + 1].fen;
            final puzzleAnalysis = await _analyzePosition(afterBlunderFen);

            if (puzzleAnalysis != null && puzzleAnalysis.pvMoves.isNotEmpty) {
              final puzzle = _createPuzzle(
                fen: afterBlunderFen,
                solution: puzzleAnalysis.pvMoves,
                evalDiff: analysis.evalDiff,
              );
              if (puzzle != null) {
                puzzles.add(puzzle);
              }
            }
          }
        } else if (analysis.isBrilliant) {
          // Good tactical move - show it as a puzzle
          final puzzle = _createPuzzle(
            fen: posData.fen,
            solution: analysis.pvMoves,
            evalDiff: analysis.evalDiff,
            isBrilliant: true,
          );
          if (puzzle != null) {
            puzzles.add(puzzle);
          }
        }
      }
    }

    return puzzles;
  }

  /// Generate puzzles from a list of FEN positions (simpler approach)
  Future<List<Puzzle>> generateFromPositions(List<String> fens) async {
    if (!_isInitialized) await initialize();

    final puzzles = <Puzzle>[];

    for (final fen in fens) {
      final analysis = await _analyzePosition(fen);

      if (analysis != null && analysis.pvMoves.length >= 2) {
        final puzzle = _createPuzzle(
          fen: fen,
          solution: analysis.pvMoves.take(4).toList(),
          evalDiff: 0,
        );
        if (puzzle != null) {
          puzzles.add(puzzle);
        }
      }
    }

    return puzzles;
  }

  Future<_AnalysisResult?> _analyzePosition(String fen) async {
    final completer = Completer<_AnalysisResult?>();
    String? bestMove;
    List<String> pvMoves = [];
    int? evalCp;
    int? evalMate;

    late StreamSubscription<String> sub;
    sub = _stockfish.outputStream.listen((line) {
      if (UciParser.isInfoLine(line)) {
        final result = UciParser.parseInfo(line);
        if (result?.pv != null) {
          pvMoves = result!.pv!.uciMoves;
          evalCp = result.pv!.evaluation.centipawns;
          evalMate = result.pv!.evaluation.mateInMoves;
        }
      }
      if (UciParser.isBestMoveLine(line)) {
        final bm = UciParser.parseBestMove(line);
        bestMove = bm?.uci;
        sub.cancel();

        if (bestMove != null) {
          completer.complete(_AnalysisResult(
            bestMoveUci: bestMove!,
            pvMoves: pvMoves,
            evalCp: evalCp,
            evalMate: evalMate,
          ));
        } else {
          completer.complete(null);
        }
      }
    });

    _stockfish.setPosition(fen);
    _stockfish.startAnalysis(depth: 18);

    // Timeout after 5 seconds
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        sub.cancel();
        _stockfish.stop();
        return null;
      },
    );
  }

  Puzzle? _createPuzzle({
    required String fen,
    required List<String> solution,
    required int evalDiff,
    bool isBrilliant = false,
  }) {
    if (solution.length < 2) return null;

    // Convert UCI moves to SAN
    final sanMoves = <String>[];
    try {
      Chess pos = Chess.fromSetup(Setup.parseFen(fen));
      for (final uci in solution) {
        if (uci.length < 4) continue;
        final from = Square.fromName(uci.substring(0, 2));
        final to = Square.fromName(uci.substring(2, 4));
        Role? promo;
        if (uci.length > 4) {
          promo = _parsePromotion(uci[4]);
        }
        final move = NormalMove(from: from, to: to, promotion: promo);
        final (_, san) = pos.makeSan(move);
        sanMoves.add(san);
        pos = pos.play(move) as Chess;
      }
    } catch (e) {
      // Ignore parse errors
    }

    // Determine puzzle theme
    PuzzleTheme theme = PuzzleTheme.tactics;
    if (solution.isNotEmpty) {
      // Check for mate
      try {
        Chess pos = Chess.fromSetup(Setup.parseFen(fen));
        for (final uci in solution) {
          if (uci.length < 4) continue;
          final from = Square.fromName(uci.substring(0, 2));
          final to = Square.fromName(uci.substring(2, 4));
          Role? promo;
          if (uci.length > 4) {
            promo = _parsePromotion(uci[4]);
          }
          final move = NormalMove(from: from, to: to, promotion: promo);
          pos = pos.play(move) as Chess;
        }
        if (pos.isCheckmate) {
          final numMoves = (solution.length + 1) ~/ 2;
          theme = numMoves == 1
              ? PuzzleTheme.mateIn1
              : numMoves == 2
                  ? PuzzleTheme.mateIn2
                  : PuzzleTheme.mateIn3;
        }
      } catch (e) {
        // Ignore
      }
    }

    // Calculate rating based on evaluation difference
    int rating = 1500;
    if (evalDiff.abs() > 500) {
      rating = 1200;
    } else if (evalDiff.abs() > 300) {
      rating = 1400;
    } else if (evalDiff.abs() > 150) {
      rating = 1600;
    } else {
      rating = 1800;
    }

    return Puzzle(
      id: const Uuid().v4(),
      fen: fen,
      solution: solution,
      solutionSan: sanMoves,
      rating: rating,
      theme: theme,
    );
  }

  Role? _parsePromotion(String char) {
    switch (char.toLowerCase()) {
      case 'q':
        return Role.queen;
      case 'r':
        return Role.rook;
      case 'b':
        return Role.bishop;
      case 'n':
        return Role.knight;
      default:
        return null;
    }
  }
}

class _PositionData {
  final String fen;
  final NormalMove playedMove;
  final String playedSan;

  _PositionData({
    required this.fen,
    required this.playedMove,
    required this.playedSan,
  });
}

class _AnalysisResult {
  final String bestMoveUci;
  final List<String> pvMoves;
  final int? evalCp;
  final int? evalMate;

  _AnalysisResult({
    required this.bestMoveUci,
    required this.pvMoves,
    this.evalCp,
    this.evalMate,
  });

  bool get isTactical {
    // Mate found
    if (evalMate != null && evalMate!.abs() <= 5) return true;
    // Large eval advantage
    if (evalCp != null && evalCp!.abs() > 200) return true;
    return false;
  }

  bool get isBrilliant {
    // Only move that wins significant material
    if (evalCp != null && evalCp! > 300) return true;
    // Forced mate
    if (evalMate != null && evalMate! > 0 && evalMate! <= 3) return true;
    return false;
  }

  int get evalDiff {
    if (evalMate != null) return evalMate! > 0 ? 1000 : -1000;
    return evalCp ?? 0;
  }
}
