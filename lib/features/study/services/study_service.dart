import 'package:flutter/foundation.dart';

import '../../../core/api/supabase_service.dart';
import '../models/study_board.dart';

/// Service for study/board operations
class StudyService {
  // In-memory cache for study boards
  static final Map<String, _CachedBoard> _boardCache = {};
  static final Map<String, List<StudyBoard>> _publicBoardsCache = {};
  static DateTime? _publicBoardsCacheTime;
  static const _cacheDuration = Duration(minutes: 5);
  static const _boardCacheDuration = Duration(minutes: 10);

  /// Clear all caches
  static void clearCache() {
    _boardCache.clear();
    _publicBoardsCache.clear();
    _publicBoardsCacheTime = null;
  }

  /// Check if public boards cache is valid
  static bool _isPublicBoardsCacheValid() {
    if (_publicBoardsCacheTime == null) return false;
    return DateTime.now().difference(_publicBoardsCacheTime!) < _cacheDuration;
  }

  /// Check if board cache is valid
  static bool _isBoardCacheValid(String boardId) {
    final cached = _boardCache[boardId];
    if (cached == null) return false;
    return DateTime.now().difference(cached.cachedAt) < _boardCacheDuration;
  }
  /// Get public boards with progress using RPC
  static Future<List<StudyBoard>> getPublicBoards({
    int limit = 20,
    String? userId,
    String? lastBoardId,
    int? lastViewsCount,
    bool forceRefresh = false,
  }) async {
    // Check cache for first page (no pagination params)
    final cacheKey = userId ?? 'anonymous';
    if (!forceRefresh && lastBoardId == null && _isPublicBoardsCacheValid()) {
      final cached = _publicBoardsCache[cacheKey];
      if (cached != null && cached.isNotEmpty) {
        debugPrint('Using cached public boards');
        return cached;
      }
    }

    // For non-authenticated users (guest or no user), use fallback directly
    // This avoids RPC issues with unauthenticated requests
    final isGuest = userId == null || userId.startsWith('guest_');
    bool isAuthenticated = false;
    try {
      isAuthenticated = SupabaseService.isAuthenticated;
    } catch (e) {
      debugPrint('Supabase not initialized: $e');
    }

    if (isGuest || !isAuthenticated) {
      debugPrint('StudyService: Using fallback for non-authenticated user (isGuest=$isGuest, isAuth=$isAuthenticated, supabaseReady=${SupabaseService.isReady})');
      final boards = await _getPublicBoardsFallback(limit: limit);
      debugPrint('StudyService: Fallback returned ${boards.length} boards');

      // Cache first page
      if (lastBoardId == null && boards.isNotEmpty) {
        _publicBoardsCache[cacheKey] = boards;
        _publicBoardsCacheTime = DateTime.now();
        debugPrint('Cached ${boards.length} public boards (fallback)');
      }

      return boards;
    }

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

      final boards = (response as List).map((j) => StudyBoard.fromRpcJson(j)).toList();

      // Cache first page
      if (lastBoardId == null) {
        _publicBoardsCache[cacheKey] = boards;
        _publicBoardsCacheTime = DateTime.now();
        debugPrint('Cached ${boards.length} public boards');
      }

      return boards;
    } catch (e) {
      debugPrint('Error fetching public boards: $e');
      // Fallback to direct query if RPC fails
      return _getPublicBoardsFallback(limit: limit);
    }
  }

  /// Fallback method for getting public boards with retry logic
  static Future<List<StudyBoard>> _getPublicBoardsFallback({int limit = 20, int retryCount = 0}) async {
    const maxRetries = 3;

    // Wait for Supabase to be ready before querying
    if (!SupabaseService.isReady) {
      debugPrint('StudyService: Waiting for Supabase to be ready...');
      final isReady = await SupabaseService.waitUntilReady();
      if (!isReady) {
        debugPrint('StudyService: Supabase not ready after timeout');
        return [];
      }
    }

    try {
      debugPrint('StudyService: Fetching public boards via fallback (attempt ${retryCount + 1})...');
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

      final boards = (response as List).map((j) => StudyBoard.fromJson(j)).toList();
      debugPrint('StudyService: Fallback successfully fetched ${boards.length} boards');
      return boards;
    } catch (e) {
      debugPrint('StudyService: Error in fallback (attempt ${retryCount + 1}): $e');

      // Retry on 401 errors (might be timing issue)
      if (retryCount < maxRetries && e.toString().contains('401')) {
        debugPrint('StudyService: Retrying after 401 error...');
        await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
        return _getPublicBoardsFallback(limit: limit, retryCount: retryCount + 1);
      }

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
  static Future<StudyBoard?> getBoard(
    String boardId, {
    String? userId,
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh && _isBoardCacheValid(boardId)) {
      final cached = _boardCache[boardId]!;
      debugPrint('Using cached board: $boardId');
      return cached.board;
    }

    try {
      // Use RPC to get board with progress
      final response = await SupabaseService.client
          .rpc('get_board_with_progress', params: {
        'p_board_id': boardId,
        'p_user_id': userId,
      });

      if (response != null) {
        final board = StudyBoard.fromRpcJson(response as Map<String, dynamic>);
        // Cache the board
        _boardCache[boardId] = _CachedBoard(board: board, cachedAt: DateTime.now());
        debugPrint('Cached board: $boardId');
        return board;
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
    // Wait for Supabase to be ready before querying
    if (!SupabaseService.isReady) {
      debugPrint('StudyService: Waiting for Supabase to be ready (single board)...');
      final isReady = await SupabaseService.waitUntilReady();
      if (!isReady) {
        debugPrint('StudyService: Supabase not ready after timeout');
        return null;
      }
    }

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
    // Wait for Supabase to be ready before querying
    if (!SupabaseService.isReady) {
      debugPrint('StudyService: Waiting for Supabase to be ready (search)...');
      final isReady = await SupabaseService.waitUntilReady();
      if (!isReady) {
        debugPrint('StudyService: Supabase not ready after timeout');
        return [];
      }
    }

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

  /// Invalidate cache for a specific board (call after progress updates)
  static void invalidateBoardCache(String boardId) {
    _boardCache.remove(boardId);
  }
}

/// Helper class for caching boards with timestamp
class _CachedBoard {
  final StudyBoard board;
  final DateTime cachedAt;

  _CachedBoard({required this.board, required this.cachedAt});
}
