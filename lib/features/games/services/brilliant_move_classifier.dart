import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

/// BrilliantMoveClassifier - Strict "Brilliant (!!) heuristic
/// Based on web version: BrilliantMoveClassifier.ts
///
/// Anti-spam measures:
/// - Near-best gate (centipawnLoss)
/// - Not forced gate
/// - Eval stability gate (player perspective)
/// - SEE (Static Exchange Evaluation)
/// - Anti-exchange gate
/// - Queen-trade killer
/// - Normal CAPTURE filter: equal/normal trade isn't brilliant

/// Piece values for SEE calculation
int _getPieceValue(Role role) {
  switch (role) {
    case Role.pawn:
      return 100;
    case Role.knight:
      return 320;
    case Role.bishop:
      return 330;
    case Role.rook:
      return 500;
    case Role.queen:
      return 900;
    case Role.king:
      return 20000;
  }
}

/// Configuration for brilliant move detection
class BrilliantConfig {
  static const int maxCpLoss = 25;

  static const int maxEvalBefore = 450;
  static const int minEvalBefore = -80;
  static const int minImprovement = -40;

  static const int minSeeGainForOpponent = 120;

  static const int maxImmediateGainToCallBrilliant = 200;

  static const int minImmediateSacForCapture = 150;

  static const int captureEqualTol = 120;

  static const bool allowCaptureBrilliantOnlyIfMateOrBigSwing = true;
  static const int captureBigSwing = 250;

  static const int minBestToSecondGap = 120;

  static const int seeMaxPlies = 12;

  static const int exchangeValueTolerance = 120;

  static const bool queenSacRequiresBest = true;
  static const bool queenRequiresMateOrBigSwing = true;
  static const int queenMinSwing = 250;
}

/// Context for brilliant move detection
class BrilliantContext {
  final String fenBefore;
  final String moveSan;
  final String moveUci;
  final int evalBefore; // White perspective
  final int evalAfter; // White perspective
  final bool isWhiteMove;
  final int centipawnLoss;
  final int legalMoveCount;
  final int? mateAfter;
  final int? mateBefore;

  BrilliantContext({
    required this.fenBefore,
    required this.moveSan,
    required this.moveUci,
    required this.evalBefore,
    required this.evalAfter,
    required this.isWhiteMove,
    required this.centipawnLoss,
    required this.legalMoveCount,
    this.mateAfter,
    this.mateBefore,
  });
}

/// Classifier for detecting brilliant moves
class BrilliantMoveClassifier {
  /// Check if a move is brilliant
  bool isBrilliant(BrilliantContext ctx) {
    try {
      // 1) Near-best: must have low CPL
      if (ctx.centipawnLoss > BrilliantConfig.maxCpLoss) {
        return false;
      }

      // 2) Not forced: must have alternatives
      if (ctx.legalMoveCount <= 1) {
        return false;
      }

      // Calculate player-perspective eval
      final playerEvalBefore = ctx.isWhiteMove ? ctx.evalBefore : -ctx.evalBefore;
      final improvement = ctx.isWhiteMove
          ? ctx.evalAfter - ctx.evalBefore
          : ctx.evalBefore - ctx.evalAfter;

      // 3) Eval stability: must not hurt position too much
      if (improvement < BrilliantConfig.minImprovement) {
        return false;
      }

      // 4) Avoid already crushing / dead-lost positions
      if (playerEvalBefore > BrilliantConfig.maxEvalBefore) {
        return false;
      }
      if (playerEvalBefore < BrilliantConfig.minEvalBefore) {
        return false;
      }

      // Parse position and move
      final setup = Setup.parseFen(ctx.fenBefore);
      final position = Chess.fromSetup(setup);

      // Get move details
      final moveInfo = _parseMove(position, ctx.moveUci);
      if (moveInfo == null) {
        return false;
      }

      final movedPiece = moveInfo.movedPiece;
      final capturedPiece = moveInfo.capturedPiece;
      final targetSquare = moveInfo.to;

      // Apply move
      final positionAfter = position.playUnchecked(moveInfo.move);

      // Mate flags
      final wasMate = _isMateScore(ctx.mateBefore);
      final isMateNow = _isMateScore(ctx.mateAfter);
      final isWinningMateNow = isMateNow &&
          !wasMate &&
          (ctx.isWhiteMove ? (ctx.mateAfter ?? 0) > 0 : (ctx.mateAfter ?? 0) < 0);

      // =========================
      // NORMAL CAPTURE KILLER
      // =========================
      if (capturedPiece != null) {
        final moverV = _getPieceValue(movedPiece);
        final capV = _getPieceValue(capturedPiece);

        final sacAmount = moverV - capV;
        final equalish = (moverV - capV).abs() <= BrilliantConfig.captureEqualTol;

        if (equalish || sacAmount < BrilliantConfig.minImmediateSacForCapture) {
          if (BrilliantConfig.allowCaptureBrilliantOnlyIfMateOrBigSwing) {
            final bigSwing = improvement >= BrilliantConfig.captureBigSwing;
            if (!isWinningMateNow && !bigSwing) {
              return false;
            }
          } else {
            return false;
          }
        }
      }

      // =========================
      // QUEEN KILLERS
      // =========================
      if (movedPiece == Role.queen) {
        final queenCapturable = _squareHasLegalCapture(positionAfter, targetSquare);
        if (queenCapturable) {
          if (BrilliantConfig.queenSacRequiresBest && ctx.centipawnLoss != 0) {
            return false;
          }

          if (BrilliantConfig.queenRequiresMateOrBigSwing) {
            final bigSwing = improvement >= BrilliantConfig.queenMinSwing;
            if (!isWinningMateNow && !bigSwing) {
              return false;
            }
          }
        }
      }

      // =========================
      // MAIN SIGNAL: sacrifice illusion
      // =========================
      final sig = _sacrificeSignalStrict(position, moveInfo);
      if (!sig.isBrilliantSignal) {
        return false;
      }

      // =========================
      // ANTI-EXCHANGE
      // =========================
      if (_isTrivialExchangeAfterOurMove(positionAfter, targetSquare, movedPiece)) {
        return false;
      }

      // =========================
      // ANTI "NORMAL WIN"
      // =========================
      if (_isNormalWinningCapture(sig)) {
        return false;
      }

      // Extra guard
      if (capturedPiece != null && !sig.immediateSacrifice && sig.immediateMaterialGain > 0) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('BrilliantMoveClassifier error: $e');
      return false;
    }
  }

  /// Check if score represents mate
  bool _isMateScore(int? score) {
    if (score == null) return false;
    return score.abs() > 90000;
  }

  /// Parse a UCI move and extract details
  _MoveInfo? _parseMove(Chess position, String uci) {
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

      final piece = position.board.pieceAt(from);
      if (piece == null) return null;

      final capturedPiece = position.board.pieceAt(to);
      final move = NormalMove(from: from, to: to, promotion: promotion);

      return _MoveInfo(
        move: move,
        movedPiece: piece.role,
        capturedPiece: capturedPiece?.role,
        from: from,
        to: to,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if square has legal capture available
  bool _squareHasLegalCapture(Position position, Square square) {
    // Get all legal moves that capture on target square
    for (final entry in position.legalMoves.entries) {
      final destinations = entry.value;

      if (destinations.has(square)) {
        // Check if there's a piece on the target square
        if (position.board.pieceAt(square) != null) {
          return true;
        }
      }
    }
    return false;
  }

  /// Get all legal moves that capture on a specific square
  List<NormalMove> _getLegalCapturesToSquare(Position position, Square square) {
    final captures = <NormalMove>[];

    for (final entry in position.legalMoves.entries) {
      final from = entry.key;
      final destinations = entry.value;

      if (destinations.has(square) && position.board.pieceAt(square) != null) {
        captures.add(NormalMove(from: from, to: square));
      }
    }

    return captures;
  }

  /// Calculate sacrifice signal for brilliant move detection
  _SacrificeSignal _sacrificeSignalStrict(Chess position, _MoveInfo moveInfo) {
    final moverValue = _getPieceValue(moveInfo.movedPiece);
    final capturedValue =
        moveInfo.capturedPiece != null ? _getPieceValue(moveInfo.capturedPiece!) : 0;

    final immediateSacAmount = moveInfo.capturedPiece != null ? moverValue - capturedValue : 0;
    final immediateSacrifice = moveInfo.capturedPiece != null &&
        immediateSacAmount >= BrilliantConfig.minImmediateSacForCapture;

    final immediateMaterialGain =
        moveInfo.capturedPiece != null ? (capturedValue - moverValue).clamp(0, 99999) : 0;

    // Apply move
    final positionAfter = position.playUnchecked(moveInfo.move);
    final square = moveInfo.to;

    final movedPieceIsCapturable = _squareHasLegalCapture(positionAfter, square);
    if (!movedPieceIsCapturable) {
      return _SacrificeSignal(
        movedPieceIsCapturable: false,
        opponentBestSeeGainIfCaptures: 0,
        immediateSacrifice: immediateSacrifice,
        immediateSacAmount: immediateSacAmount,
        immediateMaterialGain: immediateMaterialGain,
        isBrilliantSignal: false,
      );
    }

    final opponentBestSeeGainIfCaptures = _bestSeeGainForCapturingSquare(
      positionAfter,
      square,
      BrilliantConfig.seeMaxPlies,
    );

    if (opponentBestSeeGainIfCaptures < BrilliantConfig.minSeeGainForOpponent) {
      return _SacrificeSignal(
        movedPieceIsCapturable: movedPieceIsCapturable,
        opponentBestSeeGainIfCaptures: opponentBestSeeGainIfCaptures,
        immediateSacrifice: immediateSacrifice,
        immediateSacAmount: immediateSacAmount,
        immediateMaterialGain: immediateMaterialGain,
        isBrilliantSignal: false,
      );
    }

    final isBrilliantSignal = (moveInfo.capturedPiece == null &&
            opponentBestSeeGainIfCaptures >= BrilliantConfig.minSeeGainForOpponent) ||
        (moveInfo.capturedPiece != null &&
            (immediateSacrifice ||
                opponentBestSeeGainIfCaptures >= BrilliantConfig.minSeeGainForOpponent));

    return _SacrificeSignal(
      movedPieceIsCapturable: movedPieceIsCapturable,
      opponentBestSeeGainIfCaptures: opponentBestSeeGainIfCaptures,
      immediateSacrifice: immediateSacrifice,
      immediateSacAmount: immediateSacAmount,
      immediateMaterialGain: immediateMaterialGain,
      isBrilliantSignal: isBrilliantSignal,
    );
  }

  /// Check if this is a normal winning capture (not brilliant)
  bool _isNormalWinningCapture(_SacrificeSignal sig) {
    if (sig.immediateMaterialGain >= BrilliantConfig.maxImmediateGainToCallBrilliant &&
        !sig.immediateSacrifice) {
      return true;
    }
    if (sig.opponentBestSeeGainIfCaptures < BrilliantConfig.minSeeGainForOpponent) {
      return true;
    }
    return false;
  }

  /// Check if move results in trivial exchange
  bool _isTrivialExchangeAfterOurMove(Position positionAfterOurMove, Square targetSquare, Role movedPiece) {
    try {
      // Find opponent captures on target square
      final oppCaps = _getLegalCapturesToSquare(positionAfterOurMove, targetSquare);

      if (oppCaps.isEmpty) return false;

      for (final oppCap in oppCaps) {
        final oppPiece = positionAfterOurMove.board.pieceAt(oppCap.from)?.role;
        if (oppPiece == null) continue;

        final oppPieceValue = _getPieceValue(oppPiece);

        // Apply opponent capture
        final posAfterOpp = positionAfterOurMove.playUnchecked(oppCap);

        // Find our recaptures
        final ourRecaps = _getLegalCapturesToSquare(posAfterOpp, targetSquare);

        // Queen-trade killer
        if (movedPiece == Role.queen && oppPiece == Role.queen && ourRecaps.isNotEmpty) {
          return true;
        }

        for (final rec in ourRecaps) {
          final ourPiece = posAfterOpp.board.pieceAt(rec.from)?.role;
          if (ourPiece == null) continue;

          final ourPieceValue = _getPieceValue(ourPiece);

          if ((oppPieceValue - ourPieceValue).abs() <= BrilliantConfig.exchangeValueTolerance) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Calculate best SEE gain for opponent capturing on square
  int _bestSeeGainForCapturingSquare(Position position, Square square, int maxPlies) {
    // Find all captures to square
    final captures = _getLegalCapturesToSquare(position, square);

    // Sort by piece value (prefer capturing with least valuable piece)
    captures.sort((a, b) {
      final aValue = _getPieceValue(position.board.pieceAt(a.from)?.role ?? Role.queen);
      final bValue = _getPieceValue(position.board.pieceAt(b.from)?.role ?? Role.queen);
      return aValue.compareTo(bValue);
    });

    if (captures.isEmpty) return 0;

    int best = 0;
    for (final cap in captures) {
      final gain = _seeForSpecificFirstCapture(position, cap, square, maxPlies);
      if (gain > best) best = gain;
    }
    return best;
  }

  /// Static Exchange Evaluation for a specific first capture
  int _seeForSpecificFirstCapture(
    Position position,
    NormalMove firstCapture,
    Square square,
    int maxPlies,
  ) {
    try {
      final victim = position.board.pieceAt(square);
      final victimValue = victim != null ? _getPieceValue(victim.role) : 0;

      // KING FIX: king has no "trade cost" in SEE
      final firstAttacker = position.board.pieceAt(firstCapture.from);
      final firstAttackerValue =
          (firstAttacker?.role == Role.king) ? 0 : _getPieceValue(firstAttacker?.role ?? Role.pawn);

      // Apply first capture
      var currentPos = position.playUnchecked(firstCapture);

      final gains = <int>[victimValue];

      int ply = 1;
      while (ply < maxPlies) {
        final recapture = _leastValuableCaptureToSquare(currentPos, square);
        if (recapture == null) break;

        final currentVictim = currentPos.board.pieceAt(square);
        final currentVictimValue = currentVictim != null ? _getPieceValue(currentVictim.role) : 0;

        currentPos = currentPos.playUnchecked(recapture);

        if (gains.length > ply - 1) {
          gains.add(currentVictimValue - gains[ply - 1]);
        }
        ply++;
      }

      // Minimax the gains array
      for (int i = gains.length - 1; i > 0; i--) {
        if (i - 1 >= 0) {
          gains[i - 1] = gains[i - 1] > -gains[i] ? gains[i - 1] : -gains[i];
        }
      }

      final net = (gains.isNotEmpty ? gains[0] : 0) - firstAttackerValue;
      return net > 0 ? net : 0;
    } catch (e) {
      return 0;
    }
  }

  /// Find least valuable piece that can capture on square
  NormalMove? _leastValuableCaptureToSquare(Position position, Square square) {
    final captures = _getLegalCapturesToSquare(position, square);

    if (captures.isEmpty) return null;

    // Sort by piece value (least valuable first)
    captures.sort((a, b) {
      final aValue = _getPieceValue(position.board.pieceAt(a.from)?.role ?? Role.queen);
      final bValue = _getPieceValue(position.board.pieceAt(b.from)?.role ?? Role.queen);
      return aValue.compareTo(bValue);
    });

    return captures.first;
  }
}

/// Move information
class _MoveInfo {
  final NormalMove move;
  final Role movedPiece;
  final Role? capturedPiece;
  final Square from;
  final Square to;

  _MoveInfo({
    required this.move,
    required this.movedPiece,
    required this.capturedPiece,
    required this.from,
    required this.to,
  });
}

/// Sacrifice signal result
class _SacrificeSignal {
  final bool movedPieceIsCapturable;
  final int opponentBestSeeGainIfCaptures;
  final bool immediateSacrifice;
  final int immediateSacAmount;
  final int immediateMaterialGain;
  final bool isBrilliantSignal;

  _SacrificeSignal({
    required this.movedPieceIsCapturable,
    required this.opponentBestSeeGainIfCaptures,
    required this.immediateSacrifice,
    required this.immediateSacAmount,
    required this.immediateMaterialGain,
    required this.isBrilliantSignal,
  });
}
