import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/supabase_service.dart';
import '../../../core/database/local_database.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/study_board.dart';

/// State for study history (recently viewed boards)
class StudyHistoryState {
  final List<StudyBoard> boards;
  final bool isLoading;
  final bool isSyncing;
  final String? error;

  const StudyHistoryState({
    this.boards = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.error,
  });

  StudyHistoryState copyWith({
    List<StudyBoard>? boards,
    bool? isLoading,
    bool? isSyncing,
    String? error,
  }) {
    return StudyHistoryState(
      boards: boards ?? this.boards,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error,
    );
  }
}

/// Provider for study history (from server's board_view_history table)
class StudyHistoryNotifier extends StateNotifier<StudyHistoryState> {
  final String? _userId;

  StudyHistoryNotifier(this._userId) : super(const StudyHistoryState()) {
    if (_userId != null && !_userId.startsWith('guest_')) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    // Step 1: Load from local cache first (instant UI)
    await _loadFromCache();

    // Step 2: Sync with server in background
    _syncWithServer();
  }

  /// Load from local cache
  Future<void> _loadFromCache() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final rows = await LocalDatabase.getBoardViewHistory(limit: 50);
      if (!mounted) return;

      final boards = <StudyBoard>[];
      for (final row in rows) {
        try {
          final boardData = row['board_data'] as String;
          final json = jsonDecode(boardData) as Map<String, dynamic>;
          boards.add(StudyBoard.fromJson(json));
        } catch (e) {
          debugPrint('Failed to parse board from history cache: $e');
        }
      }

      state = state.copyWith(boards: boards, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sync with server using RPC function
  Future<void> _syncWithServer() async {
    final userId = _userId;
    if (userId == null || userId.startsWith('guest_')) return;
    if (!mounted) return;

    state = state.copyWith(isSyncing: true);

    try {
      // Step 1: Get view history using RPC function
      final historyResponse = await SupabaseService.client
          .rpc('get_user_view_history');

      if (!mounted) return;

      final boardIds = (historyResponse as List)
          .map((r) => r['board_id'] as String)
          .toList();

      if (boardIds.isEmpty) {
        state = state.copyWith(boards: [], isSyncing: false);
        await LocalDatabase.clearBoardViewHistory();
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

      // Order boards by view history order
      final orderedBoards = <StudyBoard>[];
      for (final id in boardIds) {
        if (boardMap.containsKey(id)) {
          orderedBoards.add(boardMap[id]!);
        }
      }

      // Update local cache
      await LocalDatabase.clearBoardViewHistory();
      for (final board in orderedBoards) {
        await LocalDatabase.recordBoardView(board.id, jsonEncode(board.toJson()));
      }

      state = state.copyWith(boards: orderedBoards, isSyncing: false);
    } catch (e) {
      debugPrint('Failed to sync history from server: $e');
      if (!mounted) return;
      state = state.copyWith(isSyncing: false);
    }
  }

  /// Record a board view using RPC function
  Future<void> recordView(StudyBoard board) async {
    final userId = _userId;
    if (userId == null || userId.startsWith('guest_')) return;

    try {
      // Update local state immediately (optimistic)
      if (mounted) {
        final updatedBoards = [
          board,
          ...state.boards.where((b) => b.id != board.id),
        ];
        state = state.copyWith(boards: updatedBoards);
      }

      // Update local cache
      await LocalDatabase.recordBoardView(board.id, jsonEncode(board.toJson()));

      // Record to server using RPC function
      await SupabaseService.client.rpc('record_board_view', params: {
        'p_board_id': board.id,
        'p_user_id': userId,
      });

      debugPrint('Recorded view for board: ${board.id}');
    } catch (e) {
      debugPrint('Failed to record board view: $e');
    }
  }

  /// Remove a board from history
  Future<void> removeFromHistory(String boardId) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      // Update local state
      if (mounted) {
        final updatedBoards = state.boards.where((b) => b.id != boardId).toList();
        state = state.copyWith(boards: updatedBoards);
      }

      // Remove from local cache
      await LocalDatabase.deleteBoardFromHistory(boardId);

      // Remove from server
      await SupabaseService.client
          .from('board_view_history')
          .delete()
          .eq('user_id', userId)
          .eq('board_id', boardId);
    } catch (e) {
      debugPrint('Failed to remove board from history: $e');
    }
  }

  /// Clear all history
  Future<void> clearHistory() async {
    final userId = _userId;
    if (userId == null) return;

    try {
      // Update local state
      if (mounted) {
        state = state.copyWith(boards: []);
      }

      // Clear local cache
      await LocalDatabase.clearBoardViewHistory();

      // Clear from server
      await SupabaseService.client
          .from('board_view_history')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Failed to clear history: $e');
    }
  }

  /// Refresh from server
  Future<void> refresh() async {
    await _syncWithServer();
  }
}

/// Study history provider
final studyHistoryProvider =
    StateNotifierProvider<StudyHistoryNotifier, StudyHistoryState>((ref) {
  final userId = ref.watch(authProvider).profile?.id;
  return StudyHistoryNotifier(userId);
});
