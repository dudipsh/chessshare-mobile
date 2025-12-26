import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents captured pieces for both sides
class CapturedPiecesState {
  /// Pieces captured by white (black pieces that were taken)
  final List<PieceKind> capturedByWhite;

  /// Pieces captured by black (white pieces that were taken)
  final List<PieceKind> capturedByBlack;

  /// Material advantage for white (positive = white ahead, negative = black ahead)
  final int materialAdvantage;

  const CapturedPiecesState({
    this.capturedByWhite = const [],
    this.capturedByBlack = const [],
    this.materialAdvantage = 0,
  });

  CapturedPiecesState copyWith({
    List<PieceKind>? capturedByWhite,
    List<PieceKind>? capturedByBlack,
    int? materialAdvantage,
  }) {
    return CapturedPiecesState(
      capturedByWhite: capturedByWhite ?? this.capturedByWhite,
      capturedByBlack: capturedByBlack ?? this.capturedByBlack,
      materialAdvantage: materialAdvantage ?? this.materialAdvantage,
    );
  }
}

/// Piece kind enum for captured pieces display
enum PieceKind {
  pawn(1),
  knight(3),
  bishop(3),
  rook(5),
  queen(9),
  king(0);

  final int value;
  const PieceKind(this.value);
}

/// Notifier for managing captured pieces state
class CapturedPiecesNotifier extends StateNotifier<CapturedPiecesState> {
  CapturedPiecesNotifier() : super(const CapturedPiecesState());

  /// Calculate captured pieces from a FEN string
  void updateFromFen(String fen) {
    // Starting pieces count for each side
    const startingPieces = {
      'P': 8, 'N': 2, 'B': 2, 'R': 2, 'Q': 1, 'K': 1,
      'p': 8, 'n': 2, 'b': 2, 'r': 2, 'q': 1, 'k': 1,
    };

    // Count current pieces on the board
    final currentPieces = <String, int>{};
    final fenBoard = fen.split(' ').first;

    for (final char in fenBoard.split('')) {
      if (RegExp(r'[pnbrqkPNBRQK]').hasMatch(char)) {
        currentPieces[char] = (currentPieces[char] ?? 0) + 1;
      }
    }

    // Calculate captured pieces
    final capturedByWhite = <PieceKind>[];
    final capturedByBlack = <PieceKind>[];

    // Black pieces captured by white
    for (final entry in {'p': PieceKind.pawn, 'n': PieceKind.knight,
        'b': PieceKind.bishop, 'r': PieceKind.rook, 'q': PieceKind.queen}.entries) {
      final starting = startingPieces[entry.key] ?? 0;
      final current = currentPieces[entry.key] ?? 0;
      final captured = starting - current;
      for (var i = 0; i < captured; i++) {
        capturedByWhite.add(entry.value);
      }
    }

    // White pieces captured by black
    for (final entry in {'P': PieceKind.pawn, 'N': PieceKind.knight,
        'B': PieceKind.bishop, 'R': PieceKind.rook, 'Q': PieceKind.queen}.entries) {
      final starting = startingPieces[entry.key] ?? 0;
      final current = currentPieces[entry.key] ?? 0;
      final captured = starting - current;
      for (var i = 0; i < captured; i++) {
        capturedByBlack.add(entry.value);
      }
    }

    // Sort by piece value (highest first for better display)
    capturedByWhite.sort((a, b) => b.value.compareTo(a.value));
    capturedByBlack.sort((a, b) => b.value.compareTo(a.value));

    // Calculate material advantage
    final whiteMaterial = capturedByWhite.fold<int>(0, (sum, p) => sum + p.value);
    final blackMaterial = capturedByBlack.fold<int>(0, (sum, p) => sum + p.value);
    final materialAdvantage = whiteMaterial - blackMaterial;

    state = CapturedPiecesState(
      capturedByWhite: capturedByWhite,
      capturedByBlack: capturedByBlack,
      materialAdvantage: materialAdvantage,
    );
  }

  /// Reset captured pieces state
  void reset() {
    state = const CapturedPiecesState();
  }
}

/// Provider for captured pieces - can be scoped per screen if needed
final capturedPiecesProvider =
    StateNotifierProvider<CapturedPiecesNotifier, CapturedPiecesState>((ref) {
  return CapturedPiecesNotifier();
});
