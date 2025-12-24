import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../study/models/study_board.dart';
import '../../models/profile_data.dart';

enum BoardFilter { all, public, private }

class BoardsTab extends StatefulWidget {
  final List<UserBoard> boards;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isDark;
  final VoidCallback? onLoadMore;
  final bool isOwnProfile;

  const BoardsTab({
    super.key,
    required this.boards,
    required this.isLoading,
    this.isLoadingMore = false,
    this.hasMore = true,
    required this.isDark,
    this.onLoadMore,
    this.isOwnProfile = true,
  });

  @override
  State<BoardsTab> createState() => _BoardsTabState();
}

class _BoardsTabState extends State<BoardsTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  BoardFilter _selectedFilter = BoardFilter.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Near bottom, load more
      if (!widget.isLoadingMore && widget.hasMore && widget.onLoadMore != null) {
        widget.onLoadMore!();
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<UserBoard> get _filteredBoards {
    return widget.boards.where((board) {
      // Apply visibility filter (only for own profile)
      if (widget.isOwnProfile) {
        if (_selectedFilter == BoardFilter.public && !board.isPublic) {
          return false;
        }
        if (_selectedFilter == BoardFilter.private && board.isPublic) {
          return false;
        }
      }
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        return board.title.toLowerCase().contains(_searchQuery);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.boards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.boards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No boards yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      );
    }

    final filteredBoards = _filteredBoards;

    return Column(
      children: [
        // Search and filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              // Search field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search boards...',
                  hintStyle: TextStyle(
                    color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            size: 18,
                            color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: widget.isDark ? Colors.grey[850] : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: widget.isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              // Filter chips (only for own profile)
              if (widget.isOwnProfile) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildFilterChip(BoardFilter.all, 'All'),
                    const SizedBox(width: 8),
                    _buildFilterChip(BoardFilter.public, 'Public'),
                    const SizedBox(width: 8),
                    _buildFilterChip(BoardFilter.private, 'Private'),
                    const Spacer(),
                    Text(
                      '${filteredBoards.length} boards',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // Boards grid
        Expanded(
          child: filteredBoards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No boards match your search'
                            : 'No ${_selectedFilter == BoardFilter.public ? 'public' : 'private'} boards',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredBoards.length + (widget.isLoadingMore ? 2 : 0),
                  itemBuilder: (context, index) {
                    if (index >= filteredBoards.length) {
                      // Loading indicator at bottom
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final userBoard = filteredBoards[index];
                    return _BoardCard(
                      board: userBoard,
                      isDark: widget.isDark,
                      onTap: () {
                        // Convert UserBoard to minimal StudyBoard for navigation
                        final studyBoard = StudyBoard(
                          id: userBoard.id,
                          title: userBoard.title,
                          ownerId: '', // Will be loaded in StudyBoardScreen
                          coverImageUrl: userBoard.coverImageUrl,
                          isPublic: userBoard.isPublic,
                          viewsCount: userBoard.viewsCount,
                          likesCount: userBoard.likesCount,
                          userLiked: false,
                          variations: [],
                          createdAt: userBoard.createdAt,
                          updatedAt: userBoard.createdAt,
                        );
                        context.pushNamed('study-board', extra: studyBoard);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(BoardFilter filter, String label) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (widget.isDark ? Colors.grey[850] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (widget.isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (widget.isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final UserBoard board;
  final bool isDark;
  final VoidCallback? onTap;

  const _BoardCard({required this.board, required this.isDark, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: board.coverImageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(
                          board.coverImageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => _buildChessPlaceholder(),
                        ),
                      )
                    : _buildChessPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.visibility, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text('${board.viewsCount}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      const SizedBox(width: 8),
                      Icon(board.isPublic ? Icons.public : Icons.lock, size: 14, color: Colors.grey[500]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChessPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mini chess board pattern
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
            ),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
              ),
              itemCount: 16,
              itemBuilder: (_, index) {
                final row = index ~/ 4;
                final col = index % 4;
                final isLight = (row + col) % 2 == 0;
                return Container(
                  color: isLight
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.5),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '♟',
            style: TextStyle(
              fontSize: 20,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
