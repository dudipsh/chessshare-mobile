import 'package:flutter/foundation.dart';

import '../../../core/api/supabase_service.dart';
import '../models/study_board.dart';

/// Service for study/board operations
class StudyService {
  /// Get public boards with progress using RPC
  static Future<List<StudyBoard>> getPublicBoards({
    int limit = 20,
    String? userId,
    String? lastBoardId,
    int? lastViewsCount,
  }) async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_public_boards_paginated_with_progress',
        params: {
          'page_limit': limit,
          'last_board_id': lastBoardId,
          'last_views_count': lastViewsCount,
          'p_user_id': userId,
        },
      );

      if (response == null) return [];

      return (response as List).map((j) => StudyBoard.fromRpcJson(j)).toList();
    } catch (e) {
      debugPrint('Error fetching public boards: $e');
      // Fallback to direct query if RPC fails
      return _getPublicBoardsFallback(limit: limit);
    }
  }

  /// Fallback method for getting public boards
  static Future<List<StudyBoard>> _getPublicBoardsFallback({int limit = 20}) async {
    try {
      final response = await SupabaseService.client
          .from('boards')
          .select('''
            id, title, description, owner_id, cover_image_url,
            is_public, views_count, likes_count, starting_fen,
            created_at, updated_at,
            author:profiles!owner_id(full_name, avatar_url),
            variations:board_variations(id, board_id, name, pgn, starting_fen, player_color, position)
          ''')
          .eq('is_public', true)
          .order('views_count', ascending: false)
          .limit(limit);

      return (response as List).map((j) => StudyBoard.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error in fallback: $e');
      return [];
    }
  }

  /// Get user's boards
  static Future<List<StudyBoard>> getMyBoards(String userId) async {
    try {
      final response = await SupabaseService.client
          .from('boards')
          .select('''
            id, title, description, owner_id, cover_image_url,
            is_public, views_count, likes_count, starting_fen,
            created_at, updated_at,
            variations:board_variations(id, board_id, name, pgn, starting_fen, player_color, position)
          ''')
          .eq('owner_id', userId)
          .order('updated_at', ascending: false);

      return (response as List).map((j) => StudyBoard.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error fetching my boards: $e');
      return [];
    }
  }

  /// Get a single board with progress using RPC
  static Future<StudyBoard?> getBoard(String boardId, {String? userId}) async {
    try {
      // Use RPC to get board with progress
      final response = await SupabaseService.client
          .rpc('get_board_with_progress', params: {
        'p_board_id': boardId,
        'p_user_id': userId,
      });

      if (response != null) {
        return StudyBoard.fromRpcJson(response as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching board with RPC: $e');
      // Fallback: get board without progress
      return _getBoardFallback(boardId);
    }
  }

  /// Fallback method for getting a single board
  static Future<StudyBoard?> _getBoardFallback(String boardId) async {
    try {
      final response = await SupabaseService.client
          .from('boards')
          .select('''
            id, title, description, owner_id, cover_image_url,
            is_public, views_count, likes_count, starting_fen,
            created_at, updated_at,
            author:profiles!owner_id(full_name, avatar_url),
            variations:board_variations(id, board_id, name, pgn, starting_fen, player_color, position)
          ''')
          .eq('id', boardId)
          .maybeSingle();

      return response != null ? StudyBoard.fromJson(response) : null;
    } catch (e) {
      debugPrint('Error in fallback: $e');
      return null;
    }
  }

  /// Search boards
  static Future<List<StudyBoard>> searchBoards(String query) async {
    try {
      final response = await SupabaseService.client
          .from('boards')
          .select('''
            id, title, description, owner_id, cover_image_url,
            is_public, views_count, likes_count, starting_fen,
            created_at, updated_at,
            author:profiles!owner_id(full_name, avatar_url),
            variations:board_variations(id, board_id, name, pgn, starting_fen, player_color, position)
          ''')
          .eq('is_public', true)
          .ilike('title', '%$query%')
          .order('views_count', ascending: false)
          .limit(20);

      return (response as List).map((j) => StudyBoard.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error searching boards: $e');
      return [];
    }
  }

  /// Like a board
  static Future<bool> likeBoard(String boardId, String userId) async {
    try {
      await SupabaseService.client.from('board_likes').insert({
        'board_id': boardId,
        'profile_id': userId,
      });
      return true;
    } catch (e) {
      debugPrint('Error liking board: $e');
      return false;
    }
  }

  /// Unlike a board
  static Future<bool> unlikeBoard(String boardId, String userId) async {
    try {
      await SupabaseService.client
          .from('board_likes')
          .delete()
          .eq('board_id', boardId)
          .eq('profile_id', userId);
      return true;
    } catch (e) {
      debugPrint('Error unliking board: $e');
      return false;
    }
  }
}
