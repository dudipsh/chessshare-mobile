import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/widgets/design_components.dart';
import '../../gamification/widgets/level_badge.dart';
import '../models/study_board.dart';
import '../providers/study_history_provider.dart';
import '../providers/study_likes_provider.dart';
import '../providers/study_provider.dart';
import 'study/study_board_grid.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _showSearch = false;
  int _selectedTabIndex = 0;
  int _myStudiesFilter = 0; // 0 = public, 1 = private

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Listen to animation for real-time tab updates during swipe
    _tabController.animation?.addListener(_onTabAnimation);
  }

  void _onTabAnimation() {
    // Update selected tab during swipe animation
    final animationValue = _tabController.animation?.value ?? 0;
    final newIndex = animationValue.round();
    if (newIndex != _selectedTabIndex) {
      setState(() => _selectedTabIndex = newIndex);
    }
  }

  @override
  void dispose() {
    _tabController.animation?.removeListener(_onTabAnimation);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyListProvider);
    final historyState = ref.watch(studyHistoryProvider);
    final likesState = ref.watch(studyLikesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search studies...',
                  hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  border: InputBorder.none,
                ),
                onSubmitted: (q) => ref.read(studyListProvider.notifier).search(q),
              )
            : const Text('Study'),
        actions: [
          // Show gamification badges
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Row(
              children: [
                LevelBadge(compact: true),
                SizedBox(width: 4),
                StreakBadge(compact: true),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  ref.read(studyListProvider.notifier).refresh();
                }
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildPillTab(0, 'Explore', isDark),
                const SizedBox(width: 8),
                _buildPillTab(1, 'My Studies', isDark),
                const SizedBox(width: 8),
                _buildPillTab(2, 'History', isDark),
                const SizedBox(width: 8),
                _buildPillTab(3, 'Liked', isDark),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Explore tab
          StudyBoardGrid(
            boards: state.publicBoards,
            isLoading: state.isLoading,
          ),
          // My Studies tab
          _buildMyStudiesTab(state, isDark),
          // History tab
          _buildHistoryTab(historyState, isDark),
          // Liked tab
          _buildLikedTab(likesState, isDark),
        ],
      ),
    );
  }

  Widget _buildMyStudiesTab(StudyListState state, bool isDark) {
    if (state.isLoading && state.myBoards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.myBoards.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.folder_outlined,
        title: 'No studies yet',
        subtitle: 'Create your own studies on chessshare.com\nand they will appear here',
        isDark: isDark,
        action: OutlinedButton.icon(
          onPressed: () {
            // Could open web URL
          },
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Open ChessShare'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
      );
    }

    // Determine which boards to show based on filter
    final List<StudyBoard> boardsToShow;
    if (state.hasBothTypes) {
      boardsToShow = _myStudiesFilter == 0 ? state.myPublicBoards : state.myPrivateBoards;
    } else if (state.hasOnlyPublic) {
      boardsToShow = state.myPublicBoards;
    } else {
      boardsToShow = state.myPrivateBoards;
    }

    return Column(
      children: [
        // Compact stats header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildMiniStat(Icons.library_books, '${state.myBoards.length}', 'studies', AppColors.primary, isDark),
              const SizedBox(width: 16),
              _buildMiniStat(Icons.visibility, _formatCount(state.myBoards.fold(0, (sum, b) => sum + b.viewsCount)), 'views', isDark ? Colors.grey[400]! : Colors.grey[600]!, isDark),
              const SizedBox(width: 16),
              _buildMiniStat(Icons.favorite, _formatCount(state.myBoards.fold(0, (sum, b) => sum + b.likesCount)), 'likes', Colors.red[400]!, isDark),
            ],
          ),
        ),
        // Public/Private filter tabs (only show if both types exist)
        if (state.hasBothTypes)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip(
                  0,
                  'Public',
                  Icons.public,
                  state.myPublicBoards.length,
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  1,
                  'Private',
                  Icons.lock,
                  state.myPrivateBoards.length,
                  isDark,
                ),
              ],
            ),
          ),
        Expanded(
          child: StudyBoardGrid(
            boards: boardsToShow,
            isLoading: false,
            isMine: true,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(int index, String label, IconData icon, int count, bool isDark) {
    final isSelected = _myStudiesFilter == index;

    return GestureDetector(
      onTap: () => setState(() => _myStudiesFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primary.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.15))
              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F0)),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : (isDark ? Colors.grey[700] : Colors.grey[300]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }

  Widget _buildPillTab(int index, String label, bool isDark) {
    final isSelected = _selectedTabIndex == index;

    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
        setState(() => _selectedTabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : Colors.black87)
              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F0)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(StudyHistoryState state, bool isDark) {
    if (state.isLoading && state.boards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.boards.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.history,
        title: 'No history yet',
        subtitle: 'Boards you view will appear here',
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(studyHistoryProvider.notifier).refresh(),
      child: Column(
        children: [
          // Compact header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SyncIndicator(
                  isSyncing: state.isSyncing,
                  message: 'Syncing...',
                  isDark: isDark,
                ),
                if (!state.isSyncing)
                  Text(
                    '${state.boards.length} boards viewed',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showClearHistoryDialog(),
                  icon: Icon(Icons.delete_outline, size: 16, color: Colors.red[400]),
                  label: Text('Clear', style: TextStyle(color: Colors.red[400], fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StudyBoardGrid(
              boards: state.boards,
              isLoading: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedTab(StudyLikesState state, bool isDark) {
    if (state.isLoading && state.boards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.boards.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.favorite_border,
        title: 'No liked boards',
        subtitle: 'Tap the heart on boards to save them here',
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(studyLikesProvider.notifier).refresh(),
      child: Column(
        children: [
          // Compact header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SyncIndicator(
                  isSyncing: state.isSyncing,
                  message: 'Syncing...',
                  isDark: isDark,
                ),
                if (!state.isSyncing)
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 16, color: Colors.red[400]),
                      const SizedBox(width: 4),
                      Text(
                        '${state.boards.length} liked boards',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: StudyBoardGrid(
              boards: state.boards,
              isLoading: false,
            ),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear History',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Are you sure you want to clear your viewing history?',
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(studyHistoryProvider.notifier).clearHistory();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
