// dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/captured_pieces_provider.dart';
import 'piece_icon.dart';

/// Displays captured pieces in a compact row.
///
/// Shows pieces captured by the specified side, ordered by value (highest first).
/// Includes material advantage indicator when there is a difference.
class CapturedPiecesDisplay extends ConsumerWidget {
  /// If true, shows pieces captured by white (black pieces).
  /// If false, shows pieces captured by black (white pieces).
  final bool showCapturedByWhite;

  /// Size of each piece icon
  final double pieceSize;

  /// Height of the container
  final double height;

  /// Spacing between pieces (positive for gap, set small for compact display)
  final double spacing;

  const CapturedPiecesDisplay({
    super.key,
    required this.showCapturedByWhite,
    this.pieceSize = 18,
    this.height = 24,
    this.spacing = 4, // Small gap between pieces; first stays in place
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capturedState = ref.watch(capturedPiecesProvider);
    final pieces = showCapturedByWhite
        ? capturedState.capturedByWhite
        : capturedState.capturedByBlack;
    final advantage = capturedState.materialAdvantage;

    // Show advantage on the side that's ahead
    final showAdvantage = showCapturedByWhite
        ? advantage > 0  // White is ahead, show on white's captured pieces
        : advantage < 0; // Black is ahead, show on black's captured pieces

    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Captured pieces: keep first in place, add spacing before each subsequent piece
          if (pieces.isNotEmpty) ...[
            PieceIcon(
              piece: _pieceKindToLetter(pieces[0]),
              isWhite: !showCapturedByWhite, // Captured pieces are opposite color
              size: pieceSize,
            ),
            for (var i = 1; i < pieces.length; i++) ...[
              SizedBox(width: spacing),
              PieceIcon(
                piece: _pieceKindToLetter(pieces[i]),
                isWhite: !showCapturedByWhite,
                size: pieceSize,
              ),
            ],
          ],
          // Small gap before the advantage text
          if (showAdvantage && advantage.abs() > 0) const SizedBox(width: 4),
          // Material advantage indicator
          if (showAdvantage && advantage.abs() > 0)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                '+${advantage.abs()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _pieceKindToLetter(PieceKind kind) {
    switch (kind) {
      case PieceKind.pawn:
        return 'P';
      case PieceKind.knight:
        return 'N';
      case PieceKind.bishop:
        return 'B';
      case PieceKind.rook:
        return 'R';
      case PieceKind.queen:
        return 'Q';
      case PieceKind.king:
        return 'K';
    }
  }
}

/// A simpler version that takes pieces directly without using the provider.
/// Useful for screens that manage their own captured pieces state.
class CapturedPiecesRow extends StatelessWidget {
  /// List of piece letters (P, N, B, R, Q, K)
  final List<String> pieces;

  /// Whether the pieces displayed are white
  final bool isWhite;

  /// Material advantage to display (optional)
  final int? materialAdvantage;

  /// Size of each piece icon
  final double pieceSize;

  /// Height of the container
  final double height;

  /// Spacing between pieces (positive for gap)
  final double spacing;

  const CapturedPiecesRow({
    super.key,
    required this.pieces,
    required this.isWhite,
    this.materialAdvantage,
    this.pieceSize = 18,
    this.height = 24,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pieces.isNotEmpty) ...[
            PieceIcon(
              piece: pieces[0],
              isWhite: isWhite,
              size: pieceSize,
            ),
            for (var i = 1; i < pieces.length; i++) ...[
              SizedBox(width: spacing),
              PieceIcon(
                piece: pieces[i],
                isWhite: isWhite,
                size: pieceSize,
              ),
            ],
          ],
          if (materialAdvantage != null && materialAdvantage! > 0)
            const SizedBox(width: 4),
          if (materialAdvantage != null && materialAdvantage! > 0)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                '+$materialAdvantage',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
