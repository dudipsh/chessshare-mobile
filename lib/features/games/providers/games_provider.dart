import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/chess_com_api.dart';
import '../../../core/api/lichess_api.dart';
import '../../../core/repositories/games_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/chess_game.dart';
import '../services/games_cache_service.dart';

// Games state
class GamesState {
  final List<ChessGame> games;
  final bool isLoading;
  final bool isInitialLoading; // True until first cache load completes
  final String? error;
  final bool isImporting;
  final String? importingPlatform;
  final int importProgress;
  final int importTotal;
  final String? activeChessComUsername;
  final String? activeLichessUsername;
  final bool hasAutoImported;
  final bool isSyncingInBackground; // Background sync indicator

  GamesState({
    this.games = const [],
    this.isLoading = false,
    this.isInitialLoading = true, // Start as loading until cache loads
    this.error,
    this.isImporting = false,
    this.importingPlatform,
    this.importProgress = 0,
    this.importTotal = 0,
    this.activeChessComUsername,
    this.activeLichessUsername,
    this.hasAutoImported = false,
    this.isSyncingInBackground = false,
  });

  GamesState copyWith({
    List<ChessGame>? games,
    bool? isLoading,
    bool? isInitialLoading,
    String? error,
    bool? isImporting,
    String? importingPlatform,
    int? importProgress,
    int? importTotal,
    String? activeChessComUsername,
    String? activeLichessUsername,
    bool? hasAutoImported,
    bool? isSyncingInBackground,
  }) {
    return GamesState(
      games: games ?? this.games,
      isLoading: isLoading ?? this.isLoading,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      error: error,
      isImporting: isImporting ?? this.isImporting,
      importingPlatform: importingPlatform ?? this.importingPlatform,
      importProgress: importProgress ?? this.importProgress,
      importTotal: importTotal ?? this.importTotal,
      activeChessComUsername: activeChessComUsername ?? this.activeChessComUsername,
      activeLichessUsername: activeLichessUsername ?? this.activeLichessUsername,
      hasAutoImported: hasAutoImported ?? this.hasAutoImported,
      isSyncingInBackground: isSyncingInBackground ?? this.isSyncingInBackground,
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
  bool _disposed = false;

  GamesNotifier(this._userId, this._chessComUsername, this._lichessUsername)
      : super(GamesState(
          activeChessComUsername: _chessComUsername,
          activeLichessUsername: _lichessUsername,
          // Don't show loading - we'll load from cache first for instant UI
          isLoading: false,
        )) {
    _initialize();
  }

  /// Check if the notifier is still mounted (not disposed)
  bool get mounted => !_disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _initialize() async {
    // Step 1: Load cached games FIRST for instant UI display
    await _loadFromCache();

    // Step 2: Load game reviews from server (metadata only, quick)
    // Await this to ensure reviews are loaded before importing new games
    await _loadGameReviewsFromServer();

    // Step 3: Auto-import new games in background (won't block UI)
    _autoImportInBackground();
  }

  /// Load games from local cache for instant display
  Future<void> _loadFromCache() async {
    if (!mounted) return;

    try {
      final cachedGames = await GamesCacheService.getCachedGames();
      if (mounted) {
        if (cachedGames.isNotEmpty) {
          debugPrint('Loaded ${cachedGames.length} games from cache');
          state = state.copyWith(games: cachedGames, isInitialLoading: false);
        } else {
          state = state.copyWith(isInitialLoading: false);
        }
      }
    } catch (e) {
      debugPrint('Error loading games from cache: $e');
      if (mounted) {
        state = state.copyWith(isInitialLoading: false);
      }
    }
  }

  /// Auto-import games from saved profiles in background
  /// This runs silently without blocking the UI
  Future<void> _autoImportInBackground() async {
    if (!mounted) return;

    if (state.hasAutoImported) return;

    final hasChessCom = _chessComUsername?.isNotEmpty ?? false;
    final hasLichess = _lichessUsername?.isNotEmpty ?? false;

    // If no profiles to import from, mark as done
    if (!hasChessCom && !hasLichess) {
      if (mounted) {
        state = state.copyWith(hasAutoImported: true);
      }
      return;
    }

    // Show background sync indicator (small, non-blocking)
    if (mounted) {
      state = state.copyWith(isSyncingInBackground: true);
    }

    try {
      // Import from Chess.com first if available
      if (hasChessCom && mounted) {
        await _importFromChessComSilent(_chessComUsername!);
      }

      // Then import from Lichess if available
      if (hasLichess && mounted) {
        await _importFromLichessSilent(_lichessUsername!);
      }
    } finally {
      if (mounted) {
        state = state.copyWith(
          isSyncingInBackground: false,
          hasAutoImported: true,
        );
      }
    }
  }

  /// Silent import from Chess.com (no loading UI, for background sync)
  Future<void> _importFromChessComSilent(String username) async {
    if (!mounted) return;

    try {
      final isValid = await ChessComApi.validateUsername(username);
      if (!mounted || !isValid) return;

      final archives = await ChessComApi.getArchives(username);
      if (!mounted || archives.isEmpty) return;

      final maxArchives = archives.take(3).toList();
      final allGames = <ChessGame>[];

      for (final archive in maxArchives) {
        if (!mounted) return;
        final archiveGames = await ChessComApi.getGamesFromArchive(archive, username);
        allGames.addAll(archiveGames);
      }

      if (!mounted) return;

      // Merge with existing games
      final existingIds = state.games.map((g) => g.externalId).toSet();
      final newGames = allGames.where((g) => !existingIds.contains(g.externalId)).toList();

      if (newGames.isNotEmpty) {
        final mergedGames = [...state.games, ...newGames]
          ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

        state = state.copyWith(games: mergedGames);
        _updateGamesWithAnalysisStatus();
        await GamesCacheService.cacheGames(state.games);
        debugPrint('Background sync: Added ${newGames.length} new Chess.com games');
      }
    } catch (e) {
      debugPrint('Background Chess.com sync error: $e');
    }
  }

  /// Silent import from Lichess (no loading UI, for background sync)
  Future<void> _importFromLichessSilent(String username) async {
    if (!mounted) return;

    try {
      final isValid = await LichessApi.validateUsername(username);
      if (!mounted || !isValid) return;

      final games = await LichessApi.getGames(username, max: 100);
      if (!mounted) return;

      // Merge with existing games
      final existingIds = state.games.map((g) => g.externalId).toSet();
      final newGames = games.where((g) => !existingIds.contains(g.externalId)).toList();

      if (newGames.isNotEmpty) {
        final mergedGames = [...state.games, ...newGames]
          ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

        state = state.copyWith(games: mergedGames);
        _updateGamesWithAnalysisStatus();
        await GamesCacheService.cacheGames(state.games);
        debugPrint('Background sync: Added ${newGames.length} new Lichess games');
      }
    } catch (e) {
      debugPrint('Background Lichess sync error: $e');
    }
  }

  /// Refresh games from saved profiles (silent - keeps existing games visible)
  Future<void> refreshFromSavedProfiles() async {
    if (!mounted) return;

    // Use silent refresh - don't clear games or show loading
    state = state.copyWith(isSyncingInBackground: true);

    try {
      final chessComUser = _chessComUsername;
      final lichessUser = _lichessUsername;

      if (chessComUser != null && chessComUser.isNotEmpty && mounted) {
        await _importFromChessComSilent(chessComUser);
      }
      if (lichessUser != null && lichessUser.isNotEmpty && mounted) {
        await _importFromLichessSilent(lichessUser);
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isSyncingInBackground: false);
      }
    }
  }

  /// Load game reviews from the server to know which games are analyzed
  Future<void> _loadGameReviewsFromServer() async {
    if (!mounted) return;

    final userId = _userId;
    if (userId == null || userId.startsWith('guest_')) return;

    // Use repository with centralized error handling
    final reviews = await GamesRepository.getUserGameReviews();

    if (!mounted) return;

    for (final review in reviews) {
      _reviewsCache[review.externalGameId] = _GameReviewInfo(
        id: review.id,
        accuracyWhite: review.accuracyWhite,
        accuracyBlack: review.accuracyBlack,
        reviewedAt: review.reviewedAt,
        puzzleCount: review.puzzleCount,
      );
    }

    if (reviews.isNotEmpty) {
      debugPrint('Loaded ${_reviewsCache.length} game reviews from server');
    }

    // Update any existing games with their analysis status
    if (mounted && state.games.isNotEmpty) {
      _updateGamesWithAnalysisStatus();
      // Cache the updated games with accuracy data
      await GamesCacheService.cacheGames(state.games);
      debugPrint('Cached games with analysis status');
    }
  }

  /// Update games with their analysis status from the cache
  void _updateGamesWithAnalysisStatus() {
    if (!mounted) return;

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
          puzzleCount: review.puzzleCount,
        );
      }
      return game;
    }).toList();

    if (mounted) {
      state = state.copyWith(games: updatedGames);
    }
  }

  Future<void> importFromChessCom(String username) async {
    if (!mounted) return;

    state = state.copyWith(
      isImporting: true,
      importingPlatform: 'Chess.com',
      importProgress: 0,
      error: null,
    );

    try {
      // Validate username
      final isValid = await ChessComApi.validateUsername(username);
      if (!mounted) return;

      if (!isValid) {
        state = state.copyWith(
          isImporting: false,
          error: 'Username not found on Chess.com',
        );
        return;
      }

      // Get archives
      final archives = await ChessComApi.getArchives(username);
      if (!mounted) return;

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
        if (!mounted) return;
        final archiveGames = await ChessComApi.getGamesFromArchive(
          maxArchives[i],
          username,
        );
        allGames.addAll(archiveGames);
        if (mounted) {
          state = state.copyWith(importProgress: i + 1);
        }
      }

      if (!mounted) return;

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

      // Cache games for offline access
      await GamesCacheService.cacheGames(state.games);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isImporting: false,
          error: 'Failed to import: ${e.toString()}',
        );
      }
    }
  }

  Future<void> importFromLichess(String username) async {
    if (!mounted) return;

    state = state.copyWith(
      isImporting: true,
      importingPlatform: 'Lichess',
      importProgress: 0,
      error: null,
    );

    try {
      // Validate username
      final isValid = await LichessApi.validateUsername(username);
      if (!mounted) return;

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
      if (!mounted) return;

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

      // Cache games for offline access
      await GamesCacheService.cacheGames(state.games);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isImporting: false,
          error: 'Failed to import: ${e.toString()}',
        );
      }
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
  final int puzzleCount;

  _GameReviewInfo({
    required this.id,
    this.accuracyWhite,
    this.accuracyBlack,
    this.reviewedAt,
    this.puzzleCount = 0,
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
