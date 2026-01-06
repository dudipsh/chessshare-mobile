import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../features/games/models/chess_game.dart';

class ChessComApi {
  static const String _baseUrl = 'https://api.chess.com/pub';

  /// Get player profile
  static Future<Map<String, dynamic>?> getProfile(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/player/$username'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('ChessComApi.getProfile error: $e');
      return null;
    }
  }

  /// Get player stats (ratings)
  static Future<Map<String, dynamic>?> getStats(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/player/$username/stats'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('ChessComApi.getStats error: $e');
      return null;
    }
  }

  /// Get list of game archive URLs
  static Future<List<String>> getArchives(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/player/$username/games/archives'),
        headers: {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final archives = data['archives'] as List<dynamic>;
        return archives.cast<String>().reversed.toList(); // Most recent first
      }
      return [];
    } catch (e) {
      print('ChessComApi.getArchives error: $e');
      return [];
    }
  }

  /// Get games from a specific archive URL
  static Future<List<ChessGame>> getGamesFromArchive(
    String archiveUrl,
    String playerUsername,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(archiveUrl),
        headers: {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final games = data['games'] as List<dynamic>;

        return games
            .map((g) => ChessGame.fromChessCom(
                  g as Map<String, dynamic>,
                  playerUsername,
                ))
            .toList()
          ..sort((a, b) => b.playedAt.compareTo(a.playedAt)); // Most recent first
      }
      return [];
    } catch (e) {
      print('ChessComApi.getGamesFromArchive error: $e');
      return [];
    }
  }

  /// Get recent games (from last month)
  static Future<List<ChessGame>> getRecentGames(
    String username, {
    int maxGames = 50,
  }) async {
    final archives = await getArchives(username);
    if (archives.isEmpty) return [];

    final games = <ChessGame>[];

    // Get games from recent archives until we have enough
    for (final archiveUrl in archives) {
      if (games.length >= maxGames) break;

      final archiveGames = await getGamesFromArchive(archiveUrl, username);
      games.addAll(archiveGames);
    }

    return games.take(maxGames).toList();
  }

  /// Validate that username exists
  static Future<bool> validateUsername(String username) async {
    final profile = await getProfile(username);
    return profile != null;
  }
}
