import 'package:flutter/material.dart';

class AppColors {
  // Primary colors (ChessShare green from logo)
  static const Color primary = Color(0xFF6D974D);
  static const Color primaryLight = Color(0xFF8AB56A);
  static const Color primaryDark = Color(0xFF557A3D);

  // Secondary colors (ChessShare beige from logo)
  static const Color secondary = Color(0xFFEEEDCF);
  static const Color secondaryLight = Color(0xFFF5F4E3);
  static const Color secondaryDark = Color(0xFFD9D8B8);

  // Accent colors
  static const Color accent = Color(0xFF6D974D);
  static const Color accentLight = Color(0xFF8AB56A);

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color draw = Color(0xFF6B7280);

  // Move quality colors
  static const Color brilliant = Color(0xFF00D4FF);
  static const Color great = Color(0xFF14B8A6);
  static const Color best = Color(0xFF22C55E);
  static const Color good = Color(0xFF84CC16);
  static const Color inaccuracy = Color(0xFFEAB308);
  static const Color mistake = Color(0xFFF97316);
  static const Color blunder = Color(0xFFEF4444);
  static const Color book = Color(0xFF8B5CF6);

  // Board colors
  static const Color lightSquare = Color(0xFFEBECD0);
  static const Color darkSquare = Color(0xFF779556);
  static const Color highlight = Color(0x66FFFF00);
  static const Color lastMove = Color(0x669BC700);
  static const Color check = Color(0x66FF0000);

  // Game result colors
  static const Color win = success;
  static const Color loss = error;
  static Color winColor = success;
  static Color lossColor = error;
  static Color drawColor = draw;

  // Get color for move marker
  static Color getMarkerColor(String markerType) {
    switch (markerType.toLowerCase()) {
      case 'brilliant':
        return brilliant;
      case 'great':
        return great;
      case 'best':
        return best;
      case 'good':
        return good;
      case 'inaccuracy':
        return inaccuracy;
      case 'mistake':
        return mistake;
      case 'blunder':
        return blunder;
      case 'book':
        return book;
      default:
        return Colors.white;
    }
  }

  // Get color for game result
  static Color getResultColor(String result) {
    switch (result.toLowerCase()) {
      case 'win':
        return winColor;
      case 'loss':
        return lossColor;
      case 'draw':
        return drawColor;
      default:
        return Colors.white;
    }
  }
}
