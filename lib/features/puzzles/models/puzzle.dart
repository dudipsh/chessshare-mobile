import 'package:dartchess/dartchess.dart';

/// A chess puzzle generated from game analysis
class Puzzle {
  final String id;
  final String fen;
  final List<String> solution; // UCI moves
  final List<String> solutionSan; // SAN moves
  final int rating;
  final PuzzleTheme theme;
  final String? description;

  const Puzzle({
    required this.id,
    required this.fen,
    required this.solution,
    this.solutionSan = const [],
    this.rating = 1500,
    this.theme = PuzzleTheme.tactics,
    this.description,
  });

  /// Get the side to move in this puzzle
  Side get sideToMove {
    try {
      final position = Chess.fromSetup(Setup.parseFen(fen));
      return position.turn;
    } catch (e) {
      return Side.white;
    }
  }

  /// Get the first move of the solution
  String? get firstMove => solution.isNotEmpty ? solution.first : null;

  /// Check if a UCI move matches the next expected move
  bool isCorrectMove(String uci, int moveIndex) {
    if (moveIndex < 0 || moveIndex >= solution.length) return false;
    return solution[moveIndex] == uci;
  }

  Puzzle copyWith({
    String? id,
    String? fen,
    List<String>? solution,
    List<String>? solutionSan,
    int? rating,
    PuzzleTheme? theme,
    String? description,
  }) {
    return Puzzle(
      id: id ?? this.id,
      fen: fen ?? this.fen,
      solution: solution ?? this.solution,
      solutionSan: solutionSan ?? this.solutionSan,
      rating: rating ?? this.rating,
      theme: theme ?? this.theme,
      description: description ?? this.description,
    );
  }
}

enum PuzzleTheme {
  tactics,
  mateIn1,
  mateIn2,
  mateIn3,
  fork,
  pin,
  skewer,
  discoveredAttack,
  doubleCheck,
  sacrifice,
  endgame,
  opening,
  middlegame,
}

extension PuzzleThemeExtension on PuzzleTheme {
  String get displayName {
    switch (this) {
      case PuzzleTheme.tactics:
        return 'Tactics';
      case PuzzleTheme.mateIn1:
        return 'Mate in 1';
      case PuzzleTheme.mateIn2:
        return 'Mate in 2';
      case PuzzleTheme.mateIn3:
        return 'Mate in 3';
      case PuzzleTheme.fork:
        return 'Fork';
      case PuzzleTheme.pin:
        return 'Pin';
      case PuzzleTheme.skewer:
        return 'Skewer';
      case PuzzleTheme.discoveredAttack:
        return 'Discovered Attack';
      case PuzzleTheme.doubleCheck:
        return 'Double Check';
      case PuzzleTheme.sacrifice:
        return 'Sacrifice';
      case PuzzleTheme.endgame:
        return 'Endgame';
      case PuzzleTheme.opening:
        return 'Opening';
      case PuzzleTheme.middlegame:
        return 'Middlegame';
    }
  }
}

/// State of puzzle solving
enum PuzzleState {
  ready,
  playing,
  correct,
  incorrect,
  completed,
}
