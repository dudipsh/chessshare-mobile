import 'package:dartchess/dartchess.dart' show PieceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/board_settings_provider.dart';

/// A widget that displays a chess piece image using the user's selected piece set.
///
/// This widget provides a consistent way to display chess pieces throughout the app,
/// using the same piece images as the chess board.
class PieceIcon extends ConsumerWidget {
  /// The piece to display (e.g., 'K' for king, 'Q' for queen, etc.)
  /// Accepts: K, Q, R, B, N, P (case-insensitive)
  final String piece;

  /// Whether to display the white or black version of the piece
  final bool isWhite;

  /// The size of the piece icon
  final double size;

  const PieceIcon({
    super.key,
    required this.piece,
    required this.isWhite,
    this.size = 24,
  });

  /// Create a PieceIcon from a piece letter (K, Q, R, B, N, P)
  factory PieceIcon.fromLetter(String letter, {bool isWhite = true, double size = 24}) {
    return PieceIcon(
      piece: letter.toUpperCase(),
      isWhite: isWhite,
      size: size,
    );
  }

  /// Create a PieceIcon from a role name (king, queen, rook, bishop, knight, pawn)
  factory PieceIcon.fromRole(String role, {bool isWhite = true, double size = 24}) {
    final letter = _roleToLetter(role);
    return PieceIcon(
      piece: letter,
      isWhite: isWhite,
      size: size,
    );
  }

  static String _roleToLetter(String role) {
    switch (role.toLowerCase()) {
      case 'king':
        return 'K';
      case 'queen':
        return 'Q';
      case 'rook':
        return 'R';
      case 'bishop':
        return 'B';
      case 'knight':
        return 'N';
      case 'pawn':
        return 'P';
      default:
        return 'P';
    }
  }

  PieceKind? _getPieceKind() {
    final upperPiece = piece.toUpperCase();
    if (isWhite) {
      switch (upperPiece) {
        case 'K':
          return PieceKind.whiteKing;
        case 'Q':
          return PieceKind.whiteQueen;
        case 'R':
          return PieceKind.whiteRook;
        case 'B':
          return PieceKind.whiteBishop;
        case 'N':
          return PieceKind.whiteKnight;
        case 'P':
          return PieceKind.whitePawn;
      }
    } else {
      switch (upperPiece) {
        case 'K':
          return PieceKind.blackKing;
        case 'Q':
          return PieceKind.blackQueen;
        case 'R':
          return PieceKind.blackRook;
        case 'B':
          return PieceKind.blackBishop;
        case 'N':
          return PieceKind.blackKnight;
        case 'P':
          return PieceKind.blackPawn;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardSettings = ref.watch(boardSettingsProvider);
    final pieceKind = _getPieceKind();

    if (pieceKind == null) {
      return SizedBox(width: size, height: size);
    }

    final pieceAssets = boardSettings.pieceSet.pieceSet.assets;
    final assetImage = pieceAssets[pieceKind];

    if (assetImage == null) {
      return SizedBox(width: size, height: size);
    }

    return Image(
      image: assetImage,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to Unicode if image fails to load
        return SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(
              _getFallbackUnicode(),
              style: TextStyle(fontSize: size * 0.8),
            ),
          ),
        );
      },
    );
  }

  String _getFallbackUnicode() {
    final upperPiece = piece.toUpperCase();
    if (isWhite) {
      switch (upperPiece) {
        case 'K':
          return '♔';
        case 'Q':
          return '♕';
        case 'R':
          return '♖';
        case 'B':
          return '♗';
        case 'N':
          return '♘';
        case 'P':
          return '♙';
      }
    } else {
      switch (upperPiece) {
        case 'K':
          return '♚';
        case 'Q':
          return '♛';
        case 'R':
          return '♜';
        case 'B':
          return '♝';
        case 'N':
          return '♞';
        case 'P':
          return '♟';
      }
    }
    return '♙';
  }
}

/// A widget that displays a move in algebraic notation with piece icons.
///
/// For example, "Qxf3" becomes [Queen Icon]xf3
class MoveWithPieceIcon extends ConsumerWidget {
  /// The move in SAN notation (e.g., "Qxf3", "e4", "O-O")
  final String san;

  /// Whether the move was made by white
  final bool isWhite;

  /// Font size for the text portion
  final double fontSize;

  /// Size of the piece icon
  final double pieceSize;

  /// Text color
  final Color? color;

  /// Font weight
  final FontWeight fontWeight;

  const MoveWithPieceIcon({
    super.key,
    required this.san,
    required this.isWhite,
    this.fontSize = 14,
    this.pieceSize = 18,
    this.color,
    this.fontWeight = FontWeight.normal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (san.isEmpty) return const SizedBox.shrink();

    // Handle castling
    if (san == 'O-O' || san == 'O-O-O') {
      return Text(
        san,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
      );
    }

    // Check if the move starts with a piece letter
    final firstChar = san[0];
    if ('KQRBN'.contains(firstChar)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PieceIcon(
            piece: firstChar,
            isWhite: isWhite,
            size: pieceSize,
          ),
          Text(
            san.substring(1),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
            ),
          ),
        ],
      );
    }

    // Pawn moves - just show the notation
    return Text(
      san,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
    );
  }
}
