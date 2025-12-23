import 'package:flutter/material.dart';

/// Classification of a chess move based on engine analysis
/// Thresholds match the web version for consistency
enum MoveClassification {
  book,       // Opening book move
  brilliant,  // Exceptional move with sacrifice
  great,      // Forcing check move ≤15cp loss
  best,       // Top engine move (≤15cp loss)
  good,       // Good move (15-35cp loss)
  inaccuracy, // Small mistake (35-60cp loss)
  miss,       // Missed opportunity (60-100cp loss)
  mistake,    // Significant mistake (100-200cp loss)
  blunder,    // Major mistake (>200cp loss)
  forced,     // Only legal move
  none,       // Unclassified
}

/// Thresholds for move classification (in centipawns)
/// Adjusted for mobile's lower analysis depth (10-16) vs web (18-20+)
/// Lower depth = more volatile evaluations, so thresholds are slightly higher
class ClassificationThresholds {
  // Mobile-adjusted thresholds (about 20-30% higher than web due to depth difference)
  // Web uses depth 18-20, mobile uses depth 10-16
  static const int best = 20;        // 0-20cp = Best move (web: 15)
  static const int good = 50;        // 20-50cp = Good move (web: 35)
  static const int inaccuracy = 90;  // 50-90cp = Inaccuracy (web: 60)
  static const int miss = 140;       // 90-140cp = Miss (web: 100)
  static const int mistake = 280;    // 140-280cp = Mistake (web: 200)
  // >280cp = Blunder (web: >200)

  /// For position forgiveness
  static const int dominantThreshold = 500;
  static const int stillWinningThreshold = 400;
}

/// Game phase multipliers for forgiveness
/// Applied to centipawn loss based on move number
class GamePhaseForgiveness {
  static const double opening = 0.85;      // Moves 1-6: 15% forgiveness
  static const double postOpening = 0.95;  // Moves 7-20: 5% forgiveness
  static const double middlegame = 1.0;    // Moves 21-25: NO forgiveness
  static const double endgame = 0.9;       // Moves 26+: 10% forgiveness

  static double getMultiplier(int moveNumber) {
    if (moveNumber <= 6) return opening;
    if (moveNumber <= 20) return postOpening;
    if (moveNumber <= 25) return middlegame;
    return endgame;
  }
}

extension MoveClassificationExtension on MoveClassification {
  /// Display name for the classification
  String get displayName {
    switch (this) {
      case MoveClassification.book:
        return 'Book';
      case MoveClassification.brilliant:
        return 'Brilliant';
      case MoveClassification.great:
        return 'Great';
      case MoveClassification.best:
        return 'Best';
      case MoveClassification.good:
        return 'Good';
      case MoveClassification.inaccuracy:
        return 'Inaccuracy';
      case MoveClassification.mistake:
        return 'Mistake';
      case MoveClassification.miss:
        return 'Miss';
      case MoveClassification.blunder:
        return 'Blunder';
      case MoveClassification.forced:
        return 'Forced';
      case MoveClassification.none:
        return '';
    }
  }

  /// Symbol for the classification (matches Chess.com style)
  String get symbol {
    switch (this) {
      case MoveClassification.book:
        return '📖';
      case MoveClassification.brilliant:
        return '!!';
      case MoveClassification.great:
        return '!';
      case MoveClassification.best:
        return '✓';
      case MoveClassification.good:
        return '';
      case MoveClassification.inaccuracy:
        return '?!';
      case MoveClassification.miss:
        return '×';
      case MoveClassification.mistake:
        return '?';
      case MoveClassification.blunder:
        return '??';
      case MoveClassification.forced:
        return '□';
      case MoveClassification.none:
        return '';
    }
  }

  /// Color for the classification marker
  Color get color {
    switch (this) {
      case MoveClassification.book:
        return const Color(0xFFA88B5A); // Tan/book color
      case MoveClassification.brilliant:
        return const Color(0xFF26C2A3); // Cyan
      case MoveClassification.great:
        return const Color(0xFF5C8BB0); // Blue
      case MoveClassification.best:
        return const Color(0xFF96BC4B); // Green
      case MoveClassification.good:
        return const Color(0xFF97AF8B); // Light green
      case MoveClassification.inaccuracy:
        return const Color(0xFFF7C631); // Yellow
      case MoveClassification.mistake:
        return const Color(0xFFE58F2A); // Orange
      case MoveClassification.miss:
        return const Color(0xFFDB6C50); // Light red/coral
      case MoveClassification.blunder:
        return const Color(0xFFCA3431); // Red
      case MoveClassification.forced:
        return const Color(0xFF808080); // Gray
      case MoveClassification.none:
        return Colors.transparent;
    }
  }

  /// Icon for the classification
  IconData get icon {
    switch (this) {
      case MoveClassification.book:
        return Icons.menu_book;
      case MoveClassification.brilliant:
        return Icons.auto_awesome;
      case MoveClassification.great:
        return Icons.star;
      case MoveClassification.best:
        return Icons.check_circle;
      case MoveClassification.good:
        return Icons.thumb_up_outlined;
      case MoveClassification.inaccuracy:
        return Icons.info;
      case MoveClassification.mistake:
        return Icons.error_outline;
      case MoveClassification.miss:
        return Icons.close;
      case MoveClassification.blunder:
        return Icons.dangerous;
      case MoveClassification.forced:
        return Icons.arrow_forward;
      case MoveClassification.none:
        return Icons.circle_outlined;
    }
  }

  /// Whether this is a good move (no accuracy loss)
  bool get isGood {
    switch (this) {
      case MoveClassification.book:
      case MoveClassification.brilliant:
      case MoveClassification.great:
      case MoveClassification.best:
      case MoveClassification.good:
      case MoveClassification.forced:
        return true;
      default:
        return false;
    }
  }

  /// Whether this is a positive puzzle-worthy move (brilliant/great finds)
  bool get isPositivePuzzle {
    switch (this) {
      case MoveClassification.brilliant:
      case MoveClassification.great:
        return true;
      default:
        return false;
    }
  }

  /// Whether this is a mistake that should generate a puzzle
  bool get isPuzzleWorthy {
    switch (this) {
      case MoveClassification.inaccuracy:
      case MoveClassification.mistake:
      case MoveClassification.blunder:
      case MoveClassification.miss:
        return true;
      default:
        return false;
    }
  }

  /// Classify move based on centipawn loss
  /// Uses web thresholds: BEST ≤15, GOOD ≤35, INACCURACY ≤60, MISS ≤100, MISTAKE ≤200, BLUNDER >200
  static MoveClassification fromCentipawnLoss(
    int cpl, {
    bool isBestMove = false,
    bool isBookMove = false,
    bool isBrilliant = false,
    bool isGreat = false,
    bool isMiss = false,
    bool isForced = false,
    int? moveNumber,
    int? evalBefore,
    int? evalAfter,
    bool isCheck = false,
  }) {
    // Special classifications first (order matters)
    if (isBookMove) return MoveClassification.book;
    if (isBrilliant) return MoveClassification.brilliant;
    if (isForced) return MoveClassification.forced;

    // Apply game phase forgiveness if move number provided
    int adjustedCpl = cpl;
    if (moveNumber != null) {
      final multiplier = GamePhaseForgiveness.getMultiplier(moveNumber);
      adjustedCpl = (cpl * multiplier).round();
    }

    // Position forgiveness: if dominantly winning before AND after
    if (evalBefore != null && evalAfter != null) {
      final dominantBefore = evalBefore >= ClassificationThresholds.dominantThreshold;
      final stillWinning = evalAfter >= ClassificationThresholds.stillWinningThreshold;
      if (dominantBefore && stillWinning && adjustedCpl <= ClassificationThresholds.miss) {
        return MoveClassification.good;
      }
    }

    // Best move check - comes before miss to prevent false positives
    // If the player played the engine's top choice, it can't be a miss
    if (isBestMove || adjustedCpl == 0) return MoveClassification.best;

    // Great move: forcing check with ≤15cp loss
    if (isGreat || (isCheck && adjustedCpl <= ClassificationThresholds.best)) {
      return MoveClassification.great;
    }

    // Miss: specifically for missed tactical opportunities (only if not best move)
    if (isMiss) return MoveClassification.miss;

    // Threshold-based classification (web thresholds)
    if (adjustedCpl <= ClassificationThresholds.best) return MoveClassification.best;
    if (adjustedCpl <= ClassificationThresholds.good) return MoveClassification.good;
    if (adjustedCpl <= ClassificationThresholds.inaccuracy) return MoveClassification.inaccuracy;
    if (adjustedCpl <= ClassificationThresholds.miss) return MoveClassification.miss;
    if (adjustedCpl <= ClassificationThresholds.mistake) return MoveClassification.mistake;
    return MoveClassification.blunder;
  }

  /// Convert to string for storage
  String toJson() => name;

  /// Parse from string
  static MoveClassification fromJson(String? value) {
    if (value == null) return MoveClassification.none;
    return MoveClassification.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MoveClassification.none,
    );
  }
}
