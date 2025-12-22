import 'package:flutter/foundation.dart';

import '../../../core/api/supabase_service.dart';
import '../../../core/database/local_database.dart';
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

  /// Fallback method for getting public boards using direct URL
  static Future<List<StudyBoard>> _getPublicBoardsFallback({int limit = 20}) async {
    try {
      debugPrint('StudyService: Fetching public boards via publicClient...');
      // Use publicClient (direct URL) for anonymous queries
      final response = await SupabaseService.publicClient
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
      debugPrint('StudyService: Successfully fetched ${boards.length} boards via publicClient');
      return boards;
    } catch (e) {
      debugPrint('StudyService: Error fetching public boards: $e');
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
  /// Uses local-first pattern: returns cached data immediately, refreshes in background
  static Future<StudyBoard?> getBoard(
    String boardId, {
    String? userId,
    bool forceRefresh = false,
  }) async {
    // Step 1: Check memory cache first (fastest)
    if (!forceRefresh && _isBoardCacheValid(boardId)) {
      final cached = _boardCache[boardId]!;
      debugPrint('Using memory cached board: $boardId');
      return cached.board;
    }

    // Step 2: Check local SQLite cache
    final localBoard = await LocalDatabase.getStudyBoard(boardId);
    if (localBoard != null && !forceRefresh) {
      debugPrint('Using local SQLite cached board: $boardId');
      // Update memory cache
      _boardCache[boardId] = _CachedBoard(board: localBoard, cachedAt: DateTime.now());

      // Trigger background refresh if cache is getting old (> 1 hour)
      final cacheTime = await LocalDatabase.getStudyBoardCacheTime(boardId);
      if (cacheTime != null && DateTime.now().difference(cacheTime) > const Duration(hours: 1)) {
        _refreshBoardInBackground(boardId, userId);
      }

      return localBoard;
    }

    // Step 3: Fetch from server
    return await _fetchBoardFromServer(boardId, userId);
  }

  /// Fetch board from server and cache it
  static Future<StudyBoard?> _fetchBoardFromServer(String boardId, String? userId) async {
    try {
      // Use RPC to get board with progress
      final response = await SupabaseService.client
          .rpc('get_board_with_progress', params: {
        'p_board_id': boardId,
        'p_user_id': userId,
      });

      if (response != null) {
        final board = StudyBoard.fromRpcJson(response as Map<String, dynamic>);
        // Cache in memory
        _boardCache[boardId] = _CachedBoard(board: board, cachedAt: DateTime.now());
        // Cache in SQLite for offline access
        await LocalDatabase.saveStudyBoard(board);
        debugPrint('Fetched and cached board: $boardId');
        return board;
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching board with RPC: $e');
      // Fallback: get board without progress
      return _getBoardFallback(boardId);
    }
  }

  /// Refresh board data in background (fire and forget)
  static void _refreshBoardInBackground(String boardId, String? userId) {
    debugPrint('Background refresh for board: $boardId');
    _fetchBoardFromServer(boardId, userId).then((board) {
      if (board != null) {
        debugPrint('Background refresh completed for board: $boardId');
      }
    }).catchError((e) {
      debugPrint('Background refresh failed for board: $boardId - $e');
    });
  }

  /// Fallback method for getting a single board (uses publicClient for anonymous access)
  static Future<StudyBoard?> _getBoardFallback(String boardId) async {
    try {
      // Use publicClient for anonymous access
      final response = await SupabaseService.publicClient
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

      if (response != null) {
        final board = StudyBoard.fromJson(response);
        // Cache in SQLite for offline access
        await LocalDatabase.saveStudyBoard(board);
        return board;
      }
      return null;
    } catch (e) {
      debugPrint('Error in fallback: $e');
      // Last resort: try local cache even if expired
      return await LocalDatabase.getStudyBoard(boardId);
    }
  }

  /// Search boards (uses publicClient for public board searches)
  static Future<List<StudyBoard>> searchBoards(String query) async {
    try {
      // Use publicClient for searching public boards (works for anonymous users)
      final response = await SupabaseService.publicClient
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

  /// Toggle like on a board using RPC function
  /// Returns { liked: bool, likesCount: int } or null on error
  static Future<Map<String, dynamic>?> toggleBoardLike(String boardId) async {
    try {
      final result = await SupabaseService.client.rpc('toggle_board_like', params: {
        'p_board_id': boardId,
      });
      return result as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error toggling board like: $e');
      return null;
    }
  }

  /// Check if user liked a board using RPC function
  static Future<bool> checkBoardLiked(String boardId) async {
    try {
      final result = await SupabaseService.client.rpc('check_board_liked', params: {
        'p_board_id': boardId,
      });
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking board liked: $e');
      return false;
    }
  }

  /// Record a board view using RPC function
  static Future<void> recordBoardView(String boardId, {String? userId}) async {
    try {
      await SupabaseService.client.rpc('record_board_view', params: {
        'p_board_id': boardId,
        if (userId != null) 'p_user_id': userId,
      });
    } catch (e) {
      debugPrint('Error recording board view: $e');
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
