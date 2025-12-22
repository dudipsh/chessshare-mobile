import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/supabase_service.dart';
import '../../../core/database/local_database.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/study_board.dart';

/// State for liked boards
class StudyLikesState {
  final List<StudyBoard> boards;
  final Set<String> likedBoardIds;
  final bool isLoading;
  final bool isSyncing;
  final String? error;

  const StudyLikesState({
    this.boards = const [],
    this.likedBoardIds = const {},
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
  });

  StudyLikesState copyWith({
    List<StudyBoard>? boards,
    Set<String>? likedBoardIds,
    bool? isLoading,
    bool? isSyncing,
    String? error,
  }) {
    return StudyLikesState(
      boards: boards ?? this.boards,
      likedBoardIds: likedBoardIds ?? this.likedBoardIds,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
    );
  }

  bool isLiked(String boardId) => likedBoardIds.contains(boardId);
}

/// Provider for liked boards with local-first caching
class StudyLikesNotifier extends StateNotifier<StudyLikesState> {
  final String? _userId;

  StudyLikesNotifier(this._userId) : super(const StudyLikesState()) {
    if (_userId != null && !_userId.startsWith('guest_')) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    // Step 1: Load from cache first (instant UI)
    await _loadFromCache();

    // Step 2: Sync with server in background
    _syncWithServer();
  }

  /// Load liked boards from local cache
  Future<void> _loadFromCache() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final rows = await LocalDatabase.getLikedBoards(limit: 100);
      if (!mounted) return;

      final boards = <StudyBoard>[];
      final likedIds = <String>{};

      for (final row in rows) {
        try {
          final boardData = row['board_data'] as String;
          final json = jsonDecode(boardData) as Map<String, dynamic>;
          final board = StudyBoard.fromJson(json);
          boards.add(board);
          likedIds.add(board.id);
        } catch (e) {
          debugPrint('Failed to parse liked board from cache: $e');
        }
      }

      state = state.copyWith(
        boards: boards,
        likedBoardIds: likedIds,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sync liked boards with server using RPC function
  Future<void> _syncWithServer() async {
    final userId = _userId;
    if (userId == null || userId.startsWith('guest_')) return;
    if (!mounted) return;

    state = state.copyWith(isSyncing: true);

    try {
      // Step 1: Get liked board IDs using RPC function
      final likesResponse = await SupabaseService.client
          .rpc('get_user_liked_boards');

      if (!mounted) return;

      final boardIds = (likesResponse as List)
          .map((r) => r['board_id'] as String)
          .toList();

      if (boardIds.isEmpty) {
        state = state.copyWith(
          boards: [],
          likedBoardIds: {},
          isSyncing: false,
        );
        await LocalDatabase.clearLikedBoardsCache();
        return;
      }

      // Step 2: Fetch board details for these IDs
      final boardsResponse = await SupabaseService.client
          .from('boards')
          .select('''
            id, title, description, owner_id, cover_image_url,
            is_public, views_count, likes_count, starting_fen,
            created_at, updated_at,
            author:profiles!owner_id(full_name, avatar_url),
            variations:board_variations(id, board_id, name, pgn, starting_fen, player_color, position)
          ''')
          .inFilter('id', boardIds);

      if (!mounted) return;

      // Create a map for quick lookup
      final boardMap = <String, StudyBoard>{};
      for (final row in boardsResponse as List) {
        final board = StudyBoard.fromJson(row);
        boardMap[board.id] = board;
      }

      // Order boards by likes order and build cache data
      final orderedBoards = <StudyBoard>[];
      final likedIds = <String>{};
      final cacheData = <Map<String, dynamic>>[];

      for (int i = 0; i < boardIds.length; i++) {
        final id = boardIds[i];
        if (boardMap.containsKey(id)) {
          final board = boardMap[id]!;
          orderedBoards.add(board);
          likedIds.add(id);
          cacheData.add({
            'board_id': id,
            'board_data': jsonEncode(board.toJson()),
            'liked_at': DateTime.now().millisecondsSinceEpoch - i, // Preserve order
          });
        }
      }

      // Update cache
      await LocalDatabase.syncLikedBoards(cacheData);

      state = state.copyWith(
        boards: orderedBoards,
        likedBoardIds: likedIds,
        isSyncing: false,
      );
    } catch (e) {
      debugPrint('Failed to sync liked boards: $e');
      if (!mounted) return;
      state = state.copyWith(isSyncing: false);
    }
  }

  /// Toggle like for a board using RPC function (optimistic update)
  Future<void> toggleLike(StudyBoard board) async {
    final userId = _userId;
    if (userId == null || userId.startsWith('guest_')) return;

    final wasLiked = state.isLiked(board.id);

    // Optimistic update
    if (wasLiked) {
      // Unlike
      final newBoards = state.boards.where((b) => b.id != board.id).toList();
      final newIds = Set<String>.from(state.likedBoardIds)..remove(board.id);
      state = state.copyWith(boards: newBoards, likedBoardIds: newIds);
      await LocalDatabase.removeLikedBoard(board.id);
    } else {
      // Like
      final newBoards = [board, ...state.boards];
      final newIds = Set<String>.from(state.likedBoardIds)..add(board.id);
      state = state.copyWith(boards: newBoards, likedBoardIds: newIds);
      await LocalDatabase.addLikedBoard(board.id, jsonEncode(board.toJson()));
    }

    try {
      // Call server RPC to toggle like
      final result = await SupabaseService.client.rpc('toggle_board_like', params: {
        'p_board_id': board.id,
      });

      final serverLiked = result['liked'] as bool;

      // Verify server state matches our optimistic update
      if (serverLiked == wasLiked && mounted) {
        // Server state doesn't match - revert
        debugPrint('Like state mismatch, reverting...');
        if (wasLiked) {
          final revertedBoards = [board, ...state.boards];
          final revertedIds = Set<String>.from(state.likedBoardIds)..add(board.id);
          state = state.copyWith(boards: revertedBoards, likedBoardIds: revertedIds);
          await LocalDatabase.addLikedBoard(board.id, jsonEncode(board.toJson()));
        } else {
          final revertedBoards = state.boards.where((b) => b.id != board.id).toList();
          final revertedIds = Set<String>.from(state.likedBoardIds)..remove(board.id);
          state = state.copyWith(boards: revertedBoards, likedBoardIds: revertedIds);
          await LocalDatabase.removeLikedBoard(board.id);
        }
      }
    } catch (e) {
      debugPrint('Failed to toggle like: $e');
      // Revert on error
      if (mounted) {
        if (wasLiked) {
          final revertedBoards = [board, ...state.boards];
          final revertedIds = Set<String>.from(state.likedBoardIds)..add(board.id);
          state = state.copyWith(boards: revertedBoards, likedBoardIds: revertedIds);
          await LocalDatabase.addLikedBoard(board.id, jsonEncode(board.toJson()));
        } else {
          final revertedBoards = state.boards.where((b) => b.id != board.id).toList();
          final revertedIds = Set<String>.from(state.likedBoardIds)..remove(board.id);
          state = state.copyWith(boards: revertedBoards, likedBoardIds: revertedIds);
          await LocalDatabase.removeLikedBoard(board.id);
        }
      }
    }
  }

  /// Refresh from server
  Future<void> refresh() async {
    await _syncWithServer();
  }
}

/// Study likes provider
final studyLikesProvider =
    StateNotifierProvider<StudyLikesNotifier, StudyLikesState>((ref) {
  final userId = ref.watch(authProvider).profile?.id;
  return StudyLikesNotifier(userId);
});
