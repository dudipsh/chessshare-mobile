import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/study_board.dart';
import '../../providers/study_provider.dart';
import 'study_board_card.dart';

class StudyBoardGrid extends ConsumerStatefulWidget {
  final List<StudyBoard> boards;
  final bool isLoading;
  final bool isMine;

  const StudyBoardGrid({
    super.key,
    required this.boards,
    required this.isLoading,
    this.isMine = false,
  });

  @override
  ConsumerState<StudyBoardGrid> createState() => _StudyBoardGridState();
}

class _StudyBoardGridState extends ConsumerState<StudyBoardGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.isMine) return;

    final state = ref.read(studyListProvider);
    if (state.isLoadingMore || !state.hasMorePublic) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(studyListProvider.notifier).loadMorePublic();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyListProvider);

    if (widget.isLoading && widget.boards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.boards.isEmpty) {
      return _buildEmptyState();
    }

    final itemCount = widget.boards.length + (state.hasMorePublic && !widget.isMine ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () => ref.read(studyListProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: itemCount,
        itemBuilder: (ctx, i) {
          if (i >= widget.boards.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SizedBox(
              height: 240, // Fixed height for consistent card sizing (includes footer)
              child: StudyBoardCard(board: widget.boards[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isMine ? Icons.folder_outlined : Icons.library_books_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(widget.isMine ? 'No studies yet' : 'No studies found'),
          const SizedBox(height: 8),
          Text(
            widget.isMine ? 'Create studies on chessshare.com' : 'Try a search',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }
}
