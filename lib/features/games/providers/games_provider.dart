import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/chess_com_api.dart';
import '../../../core/api/lichess_api.dart';
import '../../../core/api/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chess_game.dart';

// Games state
class GamesState {
  final List<ChessGame> games;
  final bool isLoading;
  final String? error;
  final bool isImporting;
  final String? importingPlatform;
  final int importProgress;
  final int importTotal;
  final String? activeChessComUsername;
  final String? activeLichessUsername;
  final bool hasAutoImported;

  GamesState({
    this.games = const [],
    this.isLoading = false,
    this.error,
    this.isImporting = false,
    this.importingPlatform,
    this.importProgress = 0,
    this.importTotal = 0,
    this.activeChessComUsername,
    this.activeLichessUsername,
    this.hasAutoImported = false,
  });

  GamesState copyWith({
    List<ChessGame>? games,
    bool? isLoading,
    String? error,
    bool? isImporting,
    String? importingPlatform,
    int? importProgress,
    int? importTotal,
    String? activeChessComUsername,
    String? activeLichessUsername,
    bool? hasAutoImported,
  }) {
    return GamesState(
      games: games ?? this.games,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isImporting: isImporting ?? this.isImporting,
      importingPlatform: importingPlatform ?? this.importingPlatform,
      importProgress: importProgress ?? this.importProgress,
      importTotal: importTotal ?? this.importTotal,
      activeChessComUsername: activeChessComUsername ?? this.activeChessComUsername,
      activeLichessUsername: activeLichessUsername ?? this.activeLichessUsername,
      hasAutoImported: hasAutoImported ?? this.hasAutoImported,
    );
  }

  bool get hasGames => games.isNotEmpty;
  bool get hasSavedProfiles => activeChessComUsername != null || activeLichessUsername != null;
}

// Filter state
class GamesFilter {
  final GameResult? result;
  final GameSpeed? speed;
  final GamePlatform? platform;
  final String? search;

  GamesFilter({this.result, this.speed, this.platform, this.search});

  GamesFilter copyWith({
    GameResult? result,
    GameSpeed? speed,
    GamePlatform? platform,
    String? search,
    bool clearResult = false,
    bool clearSpeed = false,
    bool clearPlatform = false,
  }) {
    return GamesFilter(
      result: clearResult ? null : (result ?? this.result),
      speed: clearSpeed ? null : (speed ?? this.speed),
      platform: clearPlatform ? null : (platform ?? this.platform),
      search: search ?? this.search,
    );
  }

  bool get hasFilters => result != null || speed != null || platform != null;
}

// Games notifier
class GamesNotifier extends StateNotifier<GamesState> {
  final String? _userId;
  final String? _chessComUsername;
  final String? _lichessUsername;
  Map<String, _GameReviewInfo> _reviewsCache = {};

  GamesNotifier(this._userId, this._chessComUsername, this._lichessUsername)
      : super(GamesState(
          activeChessComUsername: _chessComUsername,
          activeLichessUsername: _lichessUsername,
          // Start with loading if we have saved profiles to import from
          isLoading: (_chessComUsername?.isNotEmpty ?? false) ||
              (_lichessUsername?.isNotEmpty ?? false),
        )) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadGameReviewsFromServer();
    // Auto-import if we have saved profiles
    await _autoImportIfNeeded();
  }

  /// Auto-import games from saved profiles
  Future<void> _autoImportIfNeeded() async {
    if (state.hasAutoImported) {
      // Clear loading state if already imported
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
      return;
    }

    final hasChessCom = _chessComUsername?.isNotEmpty ?? false;
    final hasLichess = _lichessUsername?.isNotEmpty ?? false;

    // If no profiles to import from, clear loading state
    if (!hasChessCom && !hasLichess) {
      state = state.copyWith(isLoading: false, hasAutoImported: true);
      return;
    }

    // Import from Chess.com first if available
    if (hasChessCom) {
      await importFromChessCom(_chessComUsername!);
    }

    // Then import from Lichess if available
    if (hasLichess) {
      await importFromLichess(_lichessUsername!);
    }

    state = state.copyWith(isLoading: false, hasAutoImported: true);
  }

  /// Refresh games from saved profiles
  Future<void> refreshFromSavedProfiles() async {
    final chessComUser = _chessComUsername;
    final lichessUser = _lichessUsername;

    if (chessComUser != null && chessComUser.isNotEmpty) {
      await importFromChessCom(chessComUser);
    }
    if (lichessUser != null && lichessUser.isNotEmpty) {
      await importFromLichess(lichessUser);
    }
  }

  /// Load game reviews from the server to know which games are analyzed
  Future<void> _loadGameReviewsFromServer() async {
    final userId = _userId;
    if (userId == null || userId.startsWith('guest_')) return;

    try {
      final response = await SupabaseService.client
          .from('game_reviews')
          .select('id, external_game_id, accuracy_white, accuracy_black, reviewed_at')
          .eq('user_id', userId);

      for (final review in response) {
        final externalGameId = review['external_game_id'] as String?;
        if (externalGameId != null) {
          _reviewsCache[externalGameId] = _GameReviewInfo(
            id: review['id'] as String,
            accuracyWhite: (review['accuracy_white'] as num?)?.toDouble(),
            accuracyBlack: (review['accuracy_black'] as num?)?.toDouble(),
            reviewedAt: review['reviewed_at'] != null
                ? DateTime.parse(review['reviewed_at'] as String)
                : null,
          );
        }
      }
      debugPrint('Loaded ${_reviewsCache.length} game reviews from server');

      // Update any existing games with their analysis status
      if (state.games.isNotEmpty) {
        _updateGamesWithAnalysisStatus();
      }
    } catch (e) {
      debugPrint('Error loading game reviews: $e');
    }
  }

  /// Update games with their analysis status from the cache
  void _updateGamesWithAnalysisStatus() {
    final updatedGames = state.games.map((game) {
      final review = _reviewsCache[game.externalId];
      if (review != null) {
        return ChessGame(
          id: game.id,
          externalId: game.externalId,
          platform: game.platform,
          pgn: game.pgn,
          playerColor: game.playerColor,
          result: game.result,
          speed: game.speed,
          timeControl: game.timeControl,
          playedAt: game.playedAt,
          opponentUsername: game.opponentUsername,
          opponentRating: game.opponentRating,
          playerRating: game.playerRating,
          openingName: game.openingName,
          openingEco: game.openingEco,
          accuracyWhite: review.accuracyWhite,
          accuracyBlack: review.accuracyBlack,
          isAnalyzed: true,
        );
      }
      return game;
    }).toList();

    state = state.copyWith(games: updatedGames);
  }

  Future<void> importFromChessCom(String username) async {
    state = state.copyWith(
      isImporting: true,
      importingPlatform: 'Chess.com',
      importProgress: 0,
      error: null,
    );

    try {
      // Validate username
      final isValid = await ChessComApi.validateUsername(username);
      if (!isValid) {
        state = state.copyWith(
          isImporting: false,
          error: 'Username not found on Chess.com',
        );
        return;
      }

      // Get archives
      final archives = await ChessComApi.getArchives(username);
      if (archives.isEmpty) {
        state = state.copyWith(
          isImporting: false,
          error: 'No games found',
        );
        return;
      }

      // Import from recent archives (max 3 months)
      final maxArchives = archives.take(3).toList();
      state = state.copyWith(importTotal: maxArchives.length);

      final allGames = <ChessGame>[];
      for (var i = 0; i < maxArchives.length; i++) {
        final archiveGames = await ChessComApi.getGamesFromArchive(
          maxArchives[i],
          username,
        );
        allGames.addAll(archiveGames);
        state = state.copyWith(importProgress: i + 1);
      }

      // Merge with existing games (avoid duplicates)
      final existingIds = state.games.map((g) => g.externalId).toSet();
      final newGames = allGames.where((g) => !existingIds.contains(g.externalId));

      final mergedGames = [...state.games, ...newGames]
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

      state = state.copyWith(
        games: mergedGames,
        isImporting: false,
        importProgress: 0,
        importTotal: 0,
      );

      // Update games with analysis status from cache
      _updateGamesWithAnalysisStatus();
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        error: 'Failed to import: ${e.toString()}',
      );
    }
  }

  Future<void> importFromLichess(String username) async {
    state = state.copyWith(
      isImporting: true,
      importingPlatform: 'Lichess',
      importProgress: 0,
      error: null,
    );

    try {
      // Validate username
      final isValid = await LichessApi.validateUsername(username);
      if (!isValid) {
        state = state.copyWith(
          isImporting: false,
          error: 'Username not found on Lichess',
        );
        return;
      }

      state = state.copyWith(importTotal: 100);

      // Get recent games
      final games = await LichessApi.getGames(username, max: 100);

      state = state.copyWith(importProgress: 100);

      // Merge with existing games (avoid duplicates)
      final existingIds = state.games.map((g) => g.externalId).toSet();
      final newGames = games.where((g) => !existingIds.contains(g.externalId));

      final mergedGames = [...state.games, ...newGames]
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

      state = state.copyWith(
        games: mergedGames,
        isImporting: false,
        importProgress: 0,
        importTotal: 0,
      );

      // Update games with analysis status from cache
      _updateGamesWithAnalysisStatus();
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        error: 'Failed to import: ${e.toString()}',
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void removeGame(String gameId) {
    state = state.copyWith(
      games: state.games.where((g) => g.id != gameId).toList(),
    );
  }
}

/// Helper class for caching game review info
class _GameReviewInfo {
  final String id;
  final double? accuracyWhite;
  final double? accuracyBlack;
  final DateTime? reviewedAt;

  _GameReviewInfo({
    required this.id,
    this.accuracyWhite,
    this.accuracyBlack,
    this.reviewedAt,
  });
}

// Providers
final gamesProvider = StateNotifierProvider<GamesNotifier, GamesState>((ref) {
  final profile = ref.watch(authProvider).profile;
  return GamesNotifier(
    profile?.id,
    profile?.chessComUsername,
    profile?.lichessUsername,
  );
});

final gamesFilterProvider = StateProvider<GamesFilter>((ref) {
  return GamesFilter();
});

// Filtered games provider
final filteredGamesProvider = Provider<List<ChessGame>>((ref) {
  final state = ref.watch(gamesProvider);
  final filter = ref.watch(gamesFilterProvider);

  var games = state.games;

  if (filter.result != null) {
    games = games.where((g) => g.result == filter.result).toList();
  }

  if (filter.speed != null) {
    games = games.where((g) => g.speed == filter.speed).toList();
  }

  if (filter.platform != null) {
    games = games.where((g) => g.platform == filter.platform).toList();
  }

  if (filter.search != null && filter.search!.isNotEmpty) {
    final search = filter.search!.toLowerCase();
    games = games.where((g) =>
        g.opponentUsername.toLowerCase().contains(search) ||
        (g.openingName?.toLowerCase().contains(search) ?? false)).toList();
  }

  return games;
});

// Stats providers
final gamesStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final games = ref.watch(gamesProvider).games;

  if (games.isEmpty) {
    return {
      'total': 0,
      'wins': 0,
      'losses': 0,
      'draws': 0,
      'winRate': 0.0,
    };
  }

  final wins = games.where((g) => g.result == GameResult.win).length;
  final losses = games.where((g) => g.result == GameResult.loss).length;
  final draws = games.where((g) => g.result == GameResult.draw).length;

  return {
    'total': games.length,
    'wins': wins,
    'losses': losses,
    'draws': draws,
    'winRate': (wins / games.length * 100),
  };
});
