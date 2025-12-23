import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/study_board.dart';
import '../services/study_service.dart';

/// State for study list
class StudyListState {
  final List<StudyBoard> publicBoards;
  final List<StudyBoard> myBoards;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMorePublic;
  final bool hasMoreMy;
  final String? error;
  final String searchQuery;

  const StudyListState({
    this.publicBoards = const [],
    this.myBoards = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMorePublic = true,
    this.hasMoreMy = true,
    this.error,
    this.searchQuery = '',
  });

  StudyListState copyWith({
    List<StudyBoard>? publicBoards,
    List<StudyBoard>? myBoards,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMorePublic,
    bool? hasMoreMy,
    String? error,
    String? searchQuery,
  }) {
    return StudyListState(
      publicBoards: publicBoards ?? this.publicBoards,
      myBoards: myBoards ?? this.myBoards,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMorePublic: hasMorePublic ?? this.hasMorePublic,
      hasMoreMy: hasMoreMy ?? this.hasMoreMy,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasBoards => publicBoards.isNotEmpty || myBoards.isNotEmpty;
}

/// Provider for study list
class StudyListNotifier extends StateNotifier<StudyListState> {
  final String? _userId;
  static const int _pageSize = 20;

  StudyListNotifier(this._userId) : super(const StudyListState()) {
    loadBoards();
  }

  Future<void> loadBoards() async {
    if (!mounted) return;
    state = state.copyWith(
      isLoading: true,
      error: null,
      hasMorePublic: true,
      hasMoreMy: true,
    );

    try {
      // Pass userId for progress tracking with timeout
      final publicBoards = await StudyService.getPublicBoards(
        userId: _userId,
        limit: _pageSize,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => <StudyBoard>[],
      );
      if (!mounted) return;

      List<StudyBoard> myBoards = [];

      if (_userId != null && !_userId.startsWith('guest_')) {
        myBoards = await StudyService.getMyBoards(_userId).timeout(
          const Duration(seconds: 15),
          onTimeout: () => <StudyBoard>[],
        );
        if (!mounted) return;
      }

      state = state.copyWith(
        publicBoards: publicBoards,
        myBoards: myBoards,
        isLoading: false,
        hasMorePublic: publicBoards.length >= _pageSize,
        hasMoreMy: false, // My boards typically don't need pagination
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more public boards (pagination)
  Future<void> loadMorePublic() async {
    if (!mounted || state.isLoadingMore || !state.hasMorePublic) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final lastBoard = state.publicBoards.isNotEmpty
          ? state.publicBoards.last
          : null;

      final moreBoards = await StudyService.getPublicBoards(
        userId: _userId,
        limit: _pageSize,
        lastBoardId: lastBoard?.id,
        lastViewsCount: lastBoard?.viewsCount,
      );

      if (!mounted) return;

      state = state.copyWith(
        publicBoards: [...state.publicBoards, ...moreBoards],
        isLoadingMore: false,
        hasMorePublic: moreBoards.length >= _pageSize,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> search(String query) async {
    if (!mounted) return;
    state = state.copyWith(
      searchQuery: query,
      isLoading: true,
      hasMorePublic: false,
    );

    if (query.isEmpty) {
      await loadBoards();
      return;
    }

    try {
      final results = await StudyService.searchBoards(query);
      if (!mounted) return;
      state = state.copyWith(
        publicBoards: results,
        isLoading: false,
        hasMorePublic: false, // Search results don't paginate
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await loadBoards();
  }
}

/// Main study list provider
final studyListProvider =
    StateNotifierProvider<StudyListNotifier, StudyListState>((ref) {
  final userId = ref.watch(authProvider).profile?.id;
  return StudyListNotifier(userId);
});

/// Filtered boards (search applied)
final filteredStudyBoardsProvider = Provider<List<StudyBoard>>((ref) {
  final state = ref.watch(studyListProvider);
  if (state.searchQuery.isEmpty) {
    return state.publicBoards;
  }
  return state.publicBoards;
});
