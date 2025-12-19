import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/study_board.dart';
import '../services/study_service.dart';

/// State for study list
class StudyListState {
  final List<StudyBoard> publicBoards;
  final List<StudyBoard> myBoards;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const StudyListState({
    this.publicBoards = const [],
    this.myBoards = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  StudyListState copyWith({
    List<StudyBoard>? publicBoards,
    List<StudyBoard>? myBoards,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return StudyListState(
      publicBoards: publicBoards ?? this.publicBoards,
      myBoards: myBoards ?? this.myBoards,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasBoards => publicBoards.isNotEmpty || myBoards.isNotEmpty;
}

/// Provider for study list
class StudyListNotifier extends StateNotifier<StudyListState> {
  final String? _userId;

  StudyListNotifier(this._userId) : super(const StudyListState()) {
    loadBoards();
  }

  Future<void> loadBoards() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final publicBoards = await StudyService.getPublicBoards();
      if (!mounted) return;

      List<StudyBoard> myBoards = [];

      if (_userId != null && !_userId.startsWith('guest_')) {
        myBoards = await StudyService.getMyBoards(_userId);
        if (!mounted) return;
      }

      state = state.copyWith(
        publicBoards: publicBoards,
        myBoards: myBoards,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> search(String query) async {
    if (!mounted) return;
    state = state.copyWith(searchQuery: query, isLoading: true);

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
