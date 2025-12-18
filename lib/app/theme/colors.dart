import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF1A1A2E);
  static const Color primaryLight = Color(0xFF16213E);
  static const Color primaryDark = Color(0xFF0F0F1A);

  // Accent colors
  static const Color accent = Color(0xFF4ECDC4);
  static const Color accentLight = Color(0xFF7EDDD7);

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
