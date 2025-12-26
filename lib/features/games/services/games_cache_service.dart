import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chess_game.dart';

/// Service for caching games locally
class GamesCacheService {
  static const _gamesKey = 'cached_games';
  static const _cacheTimestampKey = 'games_cache_timestamp';
  static const _cacheDuration = Duration(hours: 24);

  /// Check if cache is valid (less than 24 hours old)
  static Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now().difference(cacheTime) < _cacheDuration;
    } catch (e) {
      return false;
    }
  }

  /// Get cached games
  static Future<List<ChessGame>> getCachedGames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_gamesKey);
      if (jsonString == null) return [];

      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((e) => ChessGame.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Cache games
  static Future<void> cacheGames(List<ChessGame> games) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = games.map((g) => g.toJson()).toList();
      await prefs.setString(_gamesKey, json.encode(jsonList));
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Clear games cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_gamesKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Clear games by platform (when unlinking an account)
  static Future<void> clearGamesByPlatform(GamePlatform platform) async {
    try {
      final existingGames = await getCachedGames();
      final filteredGames = existingGames.where((g) => g.platform != platform).toList();
      await cacheGames(filteredGames);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Add games to existing cache (for incremental updates)
  static Future<void> addGamesToCache(List<ChessGame> newGames) async {
    try {
      final existingGames = await getCachedGames();

      // Create a map to dedupe by game ID
      final gamesMap = <String, ChessGame>{};
      for (final game in existingGames) {
        gamesMap[game.id] = game;
      }
      for (final game in newGames) {
        gamesMap[game.id] = game;
      }

      // Sort by date (newest first)
      final allGames = gamesMap.values.toList()
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt));

      await cacheGames(allGames);
    } catch (e) {
      // Ignore errors
    }
  }
}
