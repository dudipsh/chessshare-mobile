import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../models/study_board.dart';
import '../../widgets/study_board_cover.dart';
import '../../widgets/study_board_footer.dart';
import '../../widgets/study_board_stats.dart';

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
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  StudyBoardCover(imageUrl: board.coverImageUrl ?? _defaultCover, isDark: isDark),
                  _buildGradientOverlay(),
                  _buildPlayButton(),
                  if (board.variations.isNotEmpty) _buildVariationsBadge(),
                  StudyBoardStats(
                    viewsCount: board.viewsCount,
                    likesCount: board.likesCount,
                    userLiked: board.userLiked,
                  ),
                ],
              ),
            ),
          ),
          StudyBoardFooter(
            title: board.title,
            ownerName: board.ownerName,
            ownerAvatarUrl: board.ownerAvatarUrl,
            ownerId: board.ownerId,
            isDark: isDark,
          ),
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
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
            stops: const [0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return Positioned.fill(
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
          child: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 28),
        ),
      ),
    );
  }

  Widget _buildVariationsBadge() {
    return Positioned(
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
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
