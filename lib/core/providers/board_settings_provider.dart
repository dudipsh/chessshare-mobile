import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available piece sets
enum ChessPieceSet {
  merida('Merida', PieceSet.merida),
  cburnett('CBurnett', PieceSet.cburnett),
  alpha('Alpha', PieceSet.alpha),
  pirouetti('Pirouetti', PieceSet.pirouetti),
  chessnut('Chessnut', PieceSet.chessnut),
  chess7('Chess7', PieceSet.chess7),
  reillycraig('Reillycraig', PieceSet.reillycraig),
  companion('Companion', PieceSet.companion),
  kosal('Kosal', PieceSet.kosal),
  leipzig('Leipzig', PieceSet.leipzig),
  letter('Letter', PieceSet.letter),
  maestro('Maestro', PieceSet.maestro),
  staunty('Staunty', PieceSet.staunty),
  tatiana('Tatiana', PieceSet.tatiana),
  gioco('Gioco', PieceSet.gioco);

  final String displayName;
  final PieceSet pieceSet;
  const ChessPieceSet(this.displayName, this.pieceSet);
}

/// Available board color schemes
enum BoardColorScheme {
  green('Green', Color(0xFFEBECD0), Color(0xFF779556)),
  brown('Brown', Color(0xFFF0D9B5), Color(0xFFB58863)),
  blue('Blue', Color(0xFFDEE3E6), Color(0xFF8CA2AD)),
  purple('Purple', Color(0xFFE0D0E8), Color(0xFF9878B5)),
  gray('Gray', Color(0xFFD9D9D9), Color(0xFF8B8B8B)),
  wood('Wood', Color(0xFFE8D4B8), Color(0xFFA67B5B)),
  marble('Marble', Color(0xFFE6E6E6), Color(0xFFB8B8B8)),
  ocean('Ocean', Color(0xFFD6E6F2), Color(0xFF6B8FAD));

  final String displayName;
  final Color lightSquare;
  final Color darkSquare;
  const BoardColorScheme(this.displayName, this.lightSquare, this.darkSquare);
}

/// State for board settings
class BoardSettingsState {
  final ChessPieceSet pieceSet;
  final BoardColorScheme colorScheme;
  final bool isMuted;

  const BoardSettingsState({
    this.pieceSet = ChessPieceSet.merida,
    this.colorScheme = BoardColorScheme.green,
    this.isMuted = false,
  });

  BoardSettingsState copyWith({
    ChessPieceSet? pieceSet,
    BoardColorScheme? colorScheme,
    bool? isMuted,
  }) {
    return BoardSettingsState(
      pieceSet: pieceSet ?? this.pieceSet,
      colorScheme: colorScheme ?? this.colorScheme,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

/// Notifier for board settings
class BoardSettingsNotifier extends StateNotifier<BoardSettingsState> {
  static const _pieceSetKey = 'board_piece_set';
  static const _colorSchemeKey = 'board_color_scheme';
  static const _isMutedKey = 'board_is_muted';

  BoardSettingsNotifier() : super(const BoardSettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final pieceSetIndex = prefs.getInt(_pieceSetKey) ?? 0;
      final colorSchemeIndex = prefs.getInt(_colorSchemeKey) ?? 0;
      final isMuted = prefs.getBool(_isMutedKey) ?? false;

      state = BoardSettingsState(
        pieceSet: ChessPieceSet.values[pieceSetIndex.clamp(0, ChessPieceSet.values.length - 1)],
        colorScheme: BoardColorScheme.values[colorSchemeIndex.clamp(0, BoardColorScheme.values.length - 1)],
        isMuted: isMuted,
      );
    } catch (e) {
      // Use defaults if loading fails
    }
  }

  Future<void> setPieceSet(ChessPieceSet pieceSet) async {
    state = state.copyWith(pieceSet: pieceSet);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pieceSetKey, pieceSet.index);
  }

  Future<void> setColorScheme(BoardColorScheme colorScheme) async {
    state = state.copyWith(colorScheme: colorScheme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorSchemeKey, colorScheme.index);
  }

  Future<void> toggleMute() async {
    state = state.copyWith(isMuted: !state.isMuted);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isMutedKey, state.isMuted);
  }

  Future<void> setMuted(bool isMuted) async {
    state = state.copyWith(isMuted: isMuted);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isMutedKey, isMuted);
  }
}

/// Provider for board settings
final boardSettingsProvider = StateNotifierProvider<BoardSettingsNotifier, BoardSettingsState>((ref) {
  return BoardSettingsNotifier();
});
