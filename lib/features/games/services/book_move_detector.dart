import 'package:dartchess/dartchess.dart';

/// Information about a chess opening
class OpeningInfo {
  final String eco;
  final String name;

  const OpeningInfo({required this.eco, required this.name});
}

/// Opening line definition
class _OpeningLine {
  final String eco;
  final String name;
  final String moves; // Space-separated moves in SAN notation

  const _OpeningLine({
    required this.eco,
    required this.name,
    required this.moves,
  });
}

/// Maximum move number to check for book moves
const int _maxBookMoves = 25;

/// Comprehensive database of common opening lines
const List<_OpeningLine> _openingLines = [
  // E4 openings
  _OpeningLine(eco: 'B00', name: "King's Pawn Opening", moves: 'e4'),

  // Sicilian Defense
  _OpeningLine(eco: 'B20', name: 'Sicilian Defense', moves: 'e4 c5'),
  _OpeningLine(eco: 'B21', name: 'Sicilian Defense: Smith-Morra Gambit', moves: 'e4 c5 d4 cxd4 c3'),
  _OpeningLine(eco: 'B22', name: 'Sicilian Defense: Alapin Variation', moves: 'e4 c5 c3'),
  _OpeningLine(eco: 'B30', name: 'Sicilian Defense: Rossolimo Variation', moves: 'e4 c5 Nf3 Nc6 Bb5'),
  _OpeningLine(eco: 'B33', name: 'Sicilian Defense: Sveshnikov Variation', moves: 'e4 c5 Nf3 Nc6 d4 cxd4 Nxd4 Nf6 Nc3 e5'),
  _OpeningLine(eco: 'B50', name: 'Sicilian Defense: Open', moves: 'e4 c5 Nf3 d6 d4'),
  _OpeningLine(eco: 'B54', name: 'Sicilian Defense: Dragon Variation', moves: 'e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 g6'),
  _OpeningLine(eco: 'B90', name: 'Sicilian Defense: Najdorf Variation', moves: 'e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6'),

  // French Defense
  _OpeningLine(eco: 'C00', name: 'French Defense', moves: 'e4 e6'),
  _OpeningLine(eco: 'C01', name: 'French Defense: Exchange Variation', moves: 'e4 e6 d4 d5 exd5'),
  _OpeningLine(eco: 'C02', name: 'French Defense: Advance Variation', moves: 'e4 e6 d4 d5 e5'),
  _OpeningLine(eco: 'C03', name: 'French Defense: Tarrasch Variation', moves: 'e4 e6 d4 d5 Nd2'),
  _OpeningLine(eco: 'C11', name: 'French Defense: Classical Variation', moves: 'e4 e6 d4 d5 Nc3 Nf6'),
  _OpeningLine(eco: 'C15', name: 'French Defense: Winawer Variation', moves: 'e4 e6 d4 d5 Nc3 Bb4'),

  // Caro-Kann Defense
  _OpeningLine(eco: 'B10', name: 'Caro-Kann Defense', moves: 'e4 c6'),
  _OpeningLine(eco: 'B12', name: 'Caro-Kann Defense: Advance Variation', moves: 'e4 c6 d4 d5 e5'),
  _OpeningLine(eco: 'B13', name: 'Caro-Kann Defense: Exchange Variation', moves: 'e4 c6 d4 d5 exd5 cxd5'),
  _OpeningLine(eco: 'B14', name: 'Caro-Kann Defense: Panov-Botvinnik Attack', moves: 'e4 c6 d4 d5 exd5 cxd5 c4'),
  _OpeningLine(eco: 'B15', name: 'Caro-Kann Defense: Main Line', moves: 'e4 c6 d4 d5 Nc3'),
  _OpeningLine(eco: 'B17', name: 'Caro-Kann Defense: Steinitz Variation', moves: 'e4 c6 d4 d5 Nc3 dxe4 Nxe4 Nd7'),
  _OpeningLine(eco: 'B18', name: 'Caro-Kann Defense: Classical Variation', moves: 'e4 c6 d4 d5 Nc3 dxe4 Nxe4 Bf5'),

  // Scandinavian Defense
  _OpeningLine(eco: 'B01', name: 'Scandinavian Defense', moves: 'e4 d5'),
  _OpeningLine(eco: 'B01', name: 'Scandinavian Defense: Main Line', moves: 'e4 d5 exd5 Qxd5'),
  _OpeningLine(eco: 'B01', name: 'Scandinavian Defense: Modern Variation', moves: 'e4 d5 exd5 Nf6'),

  // Pirc/Modern Defense
  _OpeningLine(eco: 'B06', name: 'Modern Defense', moves: 'e4 g6'),
  _OpeningLine(eco: 'B07', name: 'Pirc Defense', moves: 'e4 d6 d4 Nf6'),
  _OpeningLine(eco: 'B08', name: 'Pirc Defense: Classical Variation', moves: 'e4 d6 d4 Nf6 Nc3 g6 Nf3'),

  // Alekhine Defense
  _OpeningLine(eco: 'B02', name: 'Alekhine Defense', moves: 'e4 Nf6'),
  _OpeningLine(eco: 'B03', name: 'Alekhine Defense: Four Pawns Attack', moves: 'e4 Nf6 e5 Nd5 d4 d6 c4 Nb6 f4'),

  // Italian Game
  _OpeningLine(eco: 'C50', name: 'Italian Game', moves: 'e4 e5 Nf3 Nc6 Bc4'),
  _OpeningLine(eco: 'C51', name: 'Evans Gambit', moves: 'e4 e5 Nf3 Nc6 Bc4 Bc5 b4'),
  _OpeningLine(eco: 'C53', name: 'Italian Game: Classical Variation', moves: 'e4 e5 Nf3 Nc6 Bc4 Bc5'),
  _OpeningLine(eco: 'C54', name: 'Italian Game: Giuoco Piano', moves: 'e4 e5 Nf3 Nc6 Bc4 Bc5 c3'),

  // Ruy Lopez
  _OpeningLine(eco: 'C60', name: 'Ruy Lopez', moves: 'e4 e5 Nf3 Nc6 Bb5'),
  _OpeningLine(eco: 'C65', name: 'Ruy Lopez: Berlin Defense', moves: 'e4 e5 Nf3 Nc6 Bb5 Nf6'),
  _OpeningLine(eco: 'C68', name: 'Ruy Lopez: Exchange Variation', moves: 'e4 e5 Nf3 Nc6 Bb5 a6 Bxc6'),
  _OpeningLine(eco: 'C78', name: 'Ruy Lopez: Morphy Defense', moves: 'e4 e5 Nf3 Nc6 Bb5 a6 Ba4 Nf6 O-O'),
  _OpeningLine(eco: 'C84', name: 'Ruy Lopez: Closed Variation', moves: 'e4 e5 Nf3 Nc6 Bb5 a6 Ba4 Nf6 O-O Be7'),

  // Scotch Game
  _OpeningLine(eco: 'C44', name: 'Scotch Game', moves: 'e4 e5 Nf3 Nc6 d4'),
  _OpeningLine(eco: 'C45', name: 'Scotch Game: Main Line', moves: 'e4 e5 Nf3 Nc6 d4 exd4 Nxd4'),

  // Four Knights Game
  _OpeningLine(eco: 'C47', name: 'Four Knights Game', moves: 'e4 e5 Nf3 Nc6 Nc3 Nf6'),
  _OpeningLine(eco: 'C48', name: 'Four Knights Game: Spanish Variation', moves: 'e4 e5 Nf3 Nc6 Nc3 Nf6 Bb5'),

  // Petrov Defense
  _OpeningLine(eco: 'C42', name: 'Petrov Defense', moves: 'e4 e5 Nf3 Nf6'),
  _OpeningLine(eco: 'C43', name: 'Petrov Defense: Steinitz Attack', moves: 'e4 e5 Nf3 Nf6 d4'),

  // Philidor Defense
  _OpeningLine(eco: 'C41', name: 'Philidor Defense', moves: 'e4 e5 Nf3 d6'),

  // Vienna Game
  _OpeningLine(eco: 'C25', name: 'Vienna Game', moves: 'e4 e5 Nc3'),
  _OpeningLine(eco: 'C26', name: 'Vienna Game: Falkbeer Variation', moves: 'e4 e5 Nc3 Nf6'),

  // King's Gambit
  _OpeningLine(eco: 'C30', name: "King's Gambit", moves: 'e4 e5 f4'),
  _OpeningLine(eco: 'C33', name: "King's Gambit Accepted", moves: 'e4 e5 f4 exf4'),
  _OpeningLine(eco: 'C30', name: "King's Gambit Declined", moves: 'e4 e5 f4 Bc5'),

  // D4 openings
  _OpeningLine(eco: 'D00', name: "Queen's Pawn Opening", moves: 'd4'),
  _OpeningLine(eco: 'D00', name: 'Jobava London', moves: 'd4 d5 Nc3'),
  _OpeningLine(eco: 'D00', name: 'Jobava London', moves: 'd4 d5 Nc3 Nf6 Bf4'),
  _OpeningLine(eco: 'A45', name: 'Jobava London', moves: 'd4 Nf6 Nc3 d5 Bf4'),

  // Queen's Gambit
  _OpeningLine(eco: 'D06', name: "Queen's Gambit", moves: 'd4 d5 c4'),
  _OpeningLine(eco: 'D10', name: 'Slav Defense', moves: 'd4 d5 c4 c6'),
  _OpeningLine(eco: 'D20', name: "Queen's Gambit Accepted", moves: 'd4 d5 c4 dxc4'),
  _OpeningLine(eco: 'D30', name: "Queen's Gambit Declined", moves: 'd4 d5 c4 e6'),
  _OpeningLine(eco: 'D35', name: "Queen's Gambit Declined: Exchange Variation", moves: 'd4 d5 c4 e6 Nc3 Nf6 cxd5'),
  _OpeningLine(eco: 'D37', name: "Queen's Gambit Declined: Classical Variation", moves: 'd4 d5 c4 e6 Nc3 Nf6 Nf3 Be7'),

  // London System
  _OpeningLine(eco: 'D02', name: 'London System', moves: 'd4 d5 Nf3 Nf6 Bf4'),
  _OpeningLine(eco: 'A45', name: 'London System', moves: 'd4 Nf6 Bf4'),

  // Catalan
  _OpeningLine(eco: 'E00', name: 'Catalan Opening', moves: 'd4 Nf6 c4 e6 g3'),
  _OpeningLine(eco: 'E01', name: 'Catalan Opening: Closed Variation', moves: 'd4 Nf6 c4 e6 g3 d5 Bg2'),

  // King's Indian Defense
  _OpeningLine(eco: 'E60', name: "King's Indian Defense", moves: 'd4 Nf6 c4 g6'),
  _OpeningLine(eco: 'E62', name: "King's Indian Defense: Fianchetto Variation", moves: 'd4 Nf6 c4 g6 Nc3 Bg7 Nf3 O-O g3'),
  _OpeningLine(eco: 'E70', name: "King's Indian Defense: Classical Variation", moves: 'd4 Nf6 c4 g6 Nc3 Bg7 e4 d6 Nf3'),
  _OpeningLine(eco: 'E80', name: "King's Indian Defense: Sämisch Variation", moves: 'd4 Nf6 c4 g6 Nc3 Bg7 e4 d6 f3'),
  _OpeningLine(eco: 'E90', name: "King's Indian Defense: Main Line", moves: 'd4 Nf6 c4 g6 Nc3 Bg7 e4 d6 Nf3 O-O Be2'),

  // Nimzo-Indian Defense
  _OpeningLine(eco: 'E20', name: 'Nimzo-Indian Defense', moves: 'd4 Nf6 c4 e6 Nc3 Bb4'),
  _OpeningLine(eco: 'E32', name: 'Nimzo-Indian Defense: Classical Variation', moves: 'd4 Nf6 c4 e6 Nc3 Bb4 Qc2'),
  _OpeningLine(eco: 'E40', name: 'Nimzo-Indian Defense: Rubinstein Variation', moves: 'd4 Nf6 c4 e6 Nc3 Bb4 e3'),

  // Queen's Indian Defense
  _OpeningLine(eco: 'E12', name: "Queen's Indian Defense", moves: 'd4 Nf6 c4 e6 Nf3 b6'),
  _OpeningLine(eco: 'E15', name: "Queen's Indian Defense: Classical Variation", moves: 'd4 Nf6 c4 e6 Nf3 b6 g3 Ba6'),

  // Grünfeld Defense
  _OpeningLine(eco: 'D70', name: 'Grünfeld Defense', moves: 'd4 Nf6 c4 g6 Nc3 d5'),
  _OpeningLine(eco: 'D85', name: 'Grünfeld Defense: Exchange Variation', moves: 'd4 Nf6 c4 g6 Nc3 d5 cxd5 Nxd5 e4'),

  // Benoni Defense
  _OpeningLine(eco: 'A60', name: 'Benoni Defense', moves: 'd4 Nf6 c4 c5 d5'),
  _OpeningLine(eco: 'A61', name: 'Benoni Defense: Modern Variation', moves: 'd4 Nf6 c4 c5 d5 e6 Nc3 exd5 cxd5 d6'),

  // Dutch Defense
  _OpeningLine(eco: 'A80', name: 'Dutch Defense', moves: 'd4 f5'),
  _OpeningLine(eco: 'A83', name: 'Dutch Defense: Staunton Gambit', moves: 'd4 f5 e4'),
  _OpeningLine(eco: 'A90', name: 'Dutch Defense: Classical Variation', moves: 'd4 f5 g3 Nf6 Bg2 e6'),

  // English Opening
  _OpeningLine(eco: 'A10', name: 'English Opening', moves: 'c4'),
  _OpeningLine(eco: 'A16', name: 'English Opening: Anglo-Indian Defense', moves: 'c4 Nf6 Nc3'),
  _OpeningLine(eco: 'A20', name: 'English Opening: Symmetrical Variation', moves: 'c4 e5'),
  _OpeningLine(eco: 'A30', name: 'English Opening: Symmetrical', moves: 'c4 c5'),

  // Réti Opening
  _OpeningLine(eco: 'A04', name: 'Réti Opening', moves: 'Nf3'),
  _OpeningLine(eco: 'A05', name: "Réti Opening: King's Indian Attack", moves: 'Nf3 Nf6 g3'),
  _OpeningLine(eco: 'A09', name: 'Réti Opening: Main Line', moves: 'Nf3 d5 c4'),

  // Bird Opening
  _OpeningLine(eco: 'A02', name: 'Bird Opening', moves: 'f4'),
  _OpeningLine(eco: 'A03', name: 'Bird Opening: Dutch Variation', moves: 'f4 d5'),
];

/// Map of FEN positions to openings for fast lookup
final Map<String, OpeningInfo> _fenToOpeningMap = {};

/// Flag to track initialization
bool _initialized = false;

/// Initialize the opening database maps
void _initializeMaps() {
  if (_initialized) return;

  for (final line in _openingLines) {
    try {
      var position = Chess.initial;
      final moves = line.moves.split(' ');

      for (final moveStr in moves) {
        // Try to parse and make the move
        final move = position.parseSan(moveStr);
        if (move != null) {
          position = position.play(move) as Chess;
        }
      }

      // Use position-only FEN (without move counters) as key
      final fen = position.fen;
      final positionKey = fen.split(' ').take(4).join(' ');
      _fenToOpeningMap[positionKey] = OpeningInfo(eco: line.eco, name: line.name);
    } catch (e) {
      // Skip invalid move sequences
    }
  }

  _initialized = true;
}

/// Book Move Detector Service
/// Detects if a chess move is a known theoretical/book move using local ECO database
class BookMoveDetector {
  static final BookMoveDetector _instance = BookMoveDetector._();
  factory BookMoveDetector() => _instance;
  BookMoveDetector._() {
    _initializeMaps();
  }

  /// Check if a move is a known book/theoretical move
  ({bool isBook, OpeningInfo? opening}) isBookMove(
    String fen,
    String moveUci,
    int moveNumber, {
    String? moveSan,
  }) {
    // After opening phase, don't check
    if (moveNumber > _maxBookMoves) {
      return (isBook: false, opening: null);
    }

    try {
      final position = Chess.fromSetup(Setup.parseFen(fen));

      // Parse and make the move
      Move? move;
      if (moveUci.length >= 4) {
        final from = Square.fromName(moveUci.substring(0, 2));
        final to = Square.fromName(moveUci.substring(2, 4));
        Role? promotion;
        if (moveUci.length > 4) {
          switch (moveUci[4].toLowerCase()) {
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
        move = NormalMove(from: from, to: to, promotion: promotion);
      }

      if (move == null) {
        return (isBook: false, opening: null);
      }

      // Make the move to get resulting position
      final newPosition = position.play(move);
      final resultingFen = newPosition.fen;
      final positionKey = resultingFen.split(' ').take(4).join(' ');

      // Check if resulting position is in database
      final opening = _fenToOpeningMap[positionKey];
      if (opening != null) {
        return (isBook: true, opening: opening);
      }

      // Check if position before the move is a known opening
      final beforeKey = fen.split(' ').take(4).join(' ');
      final openingBefore = _fenToOpeningMap[beforeKey];
      if (openingBefore != null) {
        // We're extending from a known opening - could be book
        return (isBook: true, opening: openingBefore);
      }

      return (isBook: false, opening: null);
    } catch (e) {
      return (isBook: false, opening: null);
    }
  }

  /// Get opening info for a FEN position
  OpeningInfo? getOpeningForPosition(String fen) {
    final positionKey = fen.split(' ').take(4).join(' ');
    return _fenToOpeningMap[positionKey];
  }

  /// Get database size (for debugging)
  int get databaseSize => _fenToOpeningMap.length;
}
