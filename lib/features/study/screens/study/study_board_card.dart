import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/study_board.dart';
import '../../widgets/study_board_cover.dart';

class StudyBoardCard extends StatelessWidget {
  final StudyBoard board;

  const StudyBoardCard({super.key, required this.board});

  static const _defaultCover = 'https://images.unsplash.com/photo-1529699211952-734e80c4d42b?w=400&h=250&fit=crop';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.pushNamed('study-board', extra: board),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section with badges and stats
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  StudyBoardCover(imageUrl: board.coverImageUrl ?? _defaultCover, isDark: isDark),
                  _buildGradientOverlay(),
                  // Featured/Lines badge at top right
                  _buildTopBadge(),
                  // Stats at bottom left
                  _buildStatsOverlay(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Category tag
          _buildCategoryTag(isDark),
          const SizedBox(height: 6),
          // Title
          Text(
            board.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Description
          if (board.description != null && board.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              board.description!,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
            stops: const [0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBadge() {
    final hasVariations = board.variations.isNotEmpty;
    final badgeText = hasVariations ? 'FEATURED' : 'STUDY';

    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          badgeText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverlay() {
    return Positioned(
      bottom: 12,
      left: 12,
      child: Row(
        children: [
          _buildStatChip(Icons.visibility_outlined, board.viewsCount),
          const SizedBox(width: 8),
          _buildStatChip(
            board.userLiked ? Icons.favorite : Icons.favorite_border,
            board.likesCount,
            iconColor: board.userLiked ? Colors.red : Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, int value, {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? Colors.white),
          const SizedBox(width: 4),
          Text(
            _formatCount(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTag(bool isDark) {
    // Infer category from title or use default
    final category = _inferCategory(board.title);

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _getCategoryColor(category),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          category.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _getCategoryColor(category),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String _inferCategory(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('opening') ||
        lowerTitle.contains('defense') ||
        lowerTitle.contains('gambit') ||
        lowerTitle.contains('sicilian') ||
        lowerTitle.contains('french') ||
        lowerTitle.contains('caro') ||
        lowerTitle.contains('ruy lopez') ||
        lowerTitle.contains('italian')) {
      return 'Opening Theory';
    } else if (lowerTitle.contains('endgame') ||
        lowerTitle.contains('rook ending') ||
        lowerTitle.contains('pawn ending')) {
      return 'Endgame';
    } else if (lowerTitle.contains('tactic') ||
        lowerTitle.contains('puzzle') ||
        lowerTitle.contains('checkmate')) {
      return 'Tactics';
    } else if (lowerTitle.contains('strategy') || lowerTitle.contains('positional')) {
      return 'Strategy';
    }
    return 'Study';
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'opening theory':
        return const Color(0xFF4CAF50); // Green
      case 'endgame':
        return const Color(0xFF9C27B0); // Purple
      case 'tactics':
        return const Color(0xFFFF9800); // Orange
      case 'strategy':
        return const Color(0xFF2196F3); // Blue
      default:
        return const Color(0xFF607D8B); // Blue-grey
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
