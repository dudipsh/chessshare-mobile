import 'package:flutter/material.dart';

/// Classification of a chess move based on engine analysis
enum MoveClassification {
  book,       // Opening book move
  brilliant,  // Exceptional move finding a tactic
  great,      // Very accurate move (CPL 0-10)
  best,       // Top engine move
  good,       // Good move (CPL 10-25)
  inaccuracy, // Small mistake (CPL 25-50)
  mistake,    // Significant mistake (CPL 50-100)
  miss,       // Missed a winning opportunity
  blunder,    // Major mistake (CPL > 100)
  forced,     // Only legal move
  none,       // Unclassified
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

  /// Whether this is a mistake that should generate a puzzle
  bool get isPuzzleWorthy {
    switch (this) {
      case MoveClassification.mistake:
      case MoveClassification.blunder:
      case MoveClassification.miss:
        return true;
      default:
        return false;
    }
  }

  /// Centipawn loss threshold for this classification
  static MoveClassification fromCentipawnLoss(
    int cpl, {
    bool isBestMove = false,
    bool isBookMove = false,
    bool isBrilliant = false,
    bool isMiss = false,
    bool isForced = false,
  }) {
    if (isBookMove) return MoveClassification.book;
    if (isBrilliant) return MoveClassification.brilliant;
    if (isForced) return MoveClassification.forced;
    if (isMiss) return MoveClassification.miss;
    if (isBestMove || cpl == 0) return MoveClassification.best;
    if (cpl <= 10) return MoveClassification.great;
    if (cpl <= 25) return MoveClassification.good;
    if (cpl <= 50) return MoveClassification.inaccuracy;
    if (cpl <= 100) return MoveClassification.mistake;
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
