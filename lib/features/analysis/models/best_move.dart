import 'package:dartchess/dartchess.dart';

/// Represents the engine's best move
class BestMove {
  /// Move in UCI format (e.g., "e2e4")
  final String uci;

  /// Source square
  final Square from;

  /// Destination square
  final Square to;

  /// Promotion piece (if pawn promotion)
  final Role? promotion;

  /// Ponder move (opponent's expected response)
  final String? ponder;

  const BestMove({
    required this.uci,
    required this.from,
    required this.to,
    this.promotion,
    this.ponder,
  });

  /// Create from UCI string
  factory BestMove.fromUci(String uci, {String? ponder}) {
    if (uci.length < 4) {
      throw ArgumentError('Invalid UCI move: $uci');
    }

    final from = Square.fromName(uci.substring(0, 2));
    final to = Square.fromName(uci.substring(2, 4));

    Role? promotion;
    if (uci.length > 4) {
      promotion = _parsePromotion(uci[4]);
    }

    return BestMove(
      uci: uci,
      from: from,
      to: to,
      promotion: promotion,
      ponder: ponder,
    );
  }

  /// Convert to NormalMove for dartchess
  NormalMove toNormalMove() {
    return NormalMove(from: from, to: to, promotion: promotion);
  }

  static Role? _parsePromotion(String char) {
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

  @override
  String toString() => 'BestMove($uci${ponder != null ? ' ponder $ponder' : ''})';
}
