import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../models/study_board.dart';

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
                  _CoverImage(imageUrl: board.coverImageUrl ?? _defaultCover, isDark: isDark),
                  _GradientOverlay(),
                  const _PlayButton(),
                  if (board.variations.isNotEmpty)
                    _VariationsBadge(count: board.variations.length),
                  _StatsRow(
                    viewsCount: board.viewsCount,
                    likesCount: board.likesCount,
                    userLiked: board.userLiked,
                  ),
                ],
              ),
            ),
          ),
          _CardFooter(
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
}

class _CoverImage extends StatelessWidget {
  final String imageUrl;
  final bool isDark;

  const _CoverImage({required this.imageUrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        child: const Center(child: Icon(Icons.image, size: 32, color: Colors.grey)),
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
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
}

class _PlayButton extends StatelessWidget {
  const _PlayButton();

  @override
  Widget build(BuildContext context) {
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
}

class _VariationsBadge extends StatelessWidget {
  final int count;

  const _VariationsBadge({required this.count});

  @override
  Widget build(BuildContext context) {
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
          '$count lines',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int viewsCount;
  final int likesCount;
  final bool userLiked;

  const _StatsRow({
    required this.viewsCount,
    required this.likesCount,
    required this.userLiked,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          _StatChip(icon: Icons.visibility_outlined, value: viewsCount),
          const SizedBox(width: 8),
          _StatChip(
            icon: userLiked ? Icons.favorite : Icons.favorite_border,
            value: likesCount,
            iconColor: userLiked ? Colors.red : Colors.white,
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

  const _StatChip({required this.icon, required this.value, this.iconColor});

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

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
          Icon(icon, size: 12, color: iconColor ?? Colors.white),
          const SizedBox(width: 3),
          Text(
            _formatCount(value),
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  final String title;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String? ownerId;
  final bool isDark;

  const _CardFooter({
    required this.title,
    required this.ownerName,
    required this.ownerAvatarUrl,
    required this.ownerId,
    required this.isDark,
  });

  void _navigateToAuthorProfile(BuildContext context) {
    if (ownerId == null) return;

    // Build query parameters for name and avatar
    final queryParams = <String, String>{};
    if (ownerName != null) queryParams['name'] = ownerName!;
    if (ownerAvatarUrl != null) queryParams['avatar'] = ownerAvatarUrl!;

    context.pushNamed(
      'user-profile',
      pathParameters: {'userId': ownerId!},
      queryParameters: queryParams,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clickable avatar
          GestureDetector(
            onTap: ownerId != null ? () => _navigateToAuthorProfile(context) : null,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
              child: ownerAvatarUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: ownerAvatarUrl!,
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
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ownerName != null)
                  GestureDetector(
                    onTap: ownerId != null ? () => _navigateToAuthorProfile(context) : null,
                    child: Text(
                      ownerName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
