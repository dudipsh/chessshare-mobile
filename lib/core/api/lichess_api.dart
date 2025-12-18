import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../features/games/models/chess_game.dart';

class LichessApi {
  static const String _baseUrl = 'https://lichess.org/api';

  /// Get player profile
  static Future<Map<String, dynamic>?> getProfile(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/$username'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('LichessApi.getProfile error: $e');
      return null;
    }
  }

  /// Get player games (NDJSON format)
  static Future<List<ChessGame>> getGames(
    String username, {
    int max = 50,
    bool rated = true,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/games/user/$username?max=$max&rated=$rated&opening=true&pgnInJson=true',
        ),
        headers: {'Accept': 'application/x-ndjson'},
      );

      if (response.statusCode == 200) {
        final lines = response.body.split('\n').where((l) => l.isNotEmpty);
        final games = <ChessGame>[];

        for (final line in lines) {
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            games.add(ChessGame.fromLichess(json, username));
          } catch (e) {
            print('Error parsing Lichess game: $e');
          }
        }

        return games;
      }
      return [];
    } catch (e) {
      print('LichessApi.getGames error: $e');
      return [];
    }
  }

  /// Get a single game by ID
  static Future<ChessGame?> getGame(String gameId, String playerUsername) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/game/$gameId?pgnInJson=true'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ChessGame.fromLichess(json, playerUsername);
      }
      return null;
    } catch (e) {
      print('LichessApi.getGame error: $e');
      return null;
    }
  }

  /// Validate that username exists
  static Future<bool> validateUsername(String username) async {
    final profile = await getProfile(username);
    return profile != null;
  }

  /// Get games by IDs
  static Future<List<ChessGame>> getGamesByIds(
    List<String> gameIds,
    String playerUsername,
  ) async {
    if (gameIds.isEmpty) return [];

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/games/export/_ids'),
        headers: {
          'Accept': 'application/x-ndjson',
          'Content-Type': 'text/plain',
        },
        body: gameIds.join(','),
      );

      if (response.statusCode == 200) {
        final lines = response.body.split('\n').where((l) => l.isNotEmpty);
        final games = <ChessGame>[];

        for (final line in lines) {
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            games.add(ChessGame.fromLichess(json, playerUsername));
          } catch (e) {
            print('Error parsing Lichess game: $e');
          }
        }

        return games;
      }
      return [];
    } catch (e) {
      print('LichessApi.getGamesByIds error: $e');
      return [];
    }
  }
}
