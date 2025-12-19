import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../models/study_board.dart';
import '../providers/study_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyListProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search studies...',
                  border: InputBorder.none,
                ),
                onSubmitted: (q) =>
                    ref.read(studyListProvider.notifier).search(q),
              )
            : const Text('Study'),
        actions: [
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Explore'), Tab(text: 'My Studies')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BoardGrid(boards: state.publicBoards, isLoading: state.isLoading),
          _BoardGrid(
              boards: state.myBoards, isLoading: state.isLoading, isMine: true),
        ],
      ),
    );
  }
}

class _BoardGrid extends ConsumerWidget {
  final List<StudyBoard> boards;
  final bool isLoading;
  final bool isMine;

  const _BoardGrid({
    required this.boards,
    required this.isLoading,
    this.isMine = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading && boards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (boards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMine ? Icons.folder_outlined : Icons.library_books_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(isMine ? 'No studies yet' : 'No studies found'),
            const SizedBox(height: 8),
            Text(
              isMine ? 'Create studies on chessshare.com' : 'Try a search',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(studyListProvider.notifier).refresh(),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: boards.length,
        itemBuilder: (ctx, i) => StudyBoardCard(board: boards[i]),
      ),
    );
  }
}

/// Beautiful board card matching web design
class StudyBoardCard extends StatelessWidget {
  final StudyBoard board;

  const StudyBoardCard({super.key, required this.board});

  static const _defaultCover = 'https://images.unsplash.com/photo-1529699211952-734e80c4d42b?w=400&h=250&fit=crop';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        context.pushNamed('study-board', extra: board);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Image with overlay
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image
                  CachedNetworkImage(
                    imageUrl: board.coverImageUrl ?? _defaultCover,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image, size: 32, color: Colors.grey),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Center(
                        child: Icon(
                          Icons.library_books,
                          size: 40,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),

                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Play button overlay
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ),
                  ),

                  // Variations badge
                  if (board.variations.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${board.variations.length} lines',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  // Stats at bottom
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      children: [
                        _StatChip(
                          icon: Icons.visibility_outlined,
                          value: board.viewsCount,
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          icon: board.userLiked ? Icons.favorite : Icons.favorite_border,
                          value: board.likesCount,
                          iconColor: board.userLiked ? Colors.red : Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Card footer
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author avatar
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                  child: board.ownerAvatarUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: board.ownerAvatarUrl!,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.person,
                              size: 16,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 16,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                ),
                const SizedBox(width: 8),

                // Title and author
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Author name
                      if (board.ownerName != null)
                        Text(
                          board.ownerName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      // Title
                      Text(
                        board.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color? iconColor;

  const _StatChip({
    required this.icon,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: iconColor ?? Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            _formatCount(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
    return count.toString();
  }
}
