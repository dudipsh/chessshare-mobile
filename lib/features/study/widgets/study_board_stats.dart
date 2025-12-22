import 'package:flutter/material.dart';

class StudyBoardStats extends StatelessWidget {
  final int viewsCount;
  final int likesCount;
  final bool userLiked;

  const StudyBoardStats({
    super.key,
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
          _buildStatChip(Icons.visibility_outlined, viewsCount),
          const SizedBox(width: 8),
          _buildStatChip(
            userLiked ? Icons.favorite : Icons.favorite_border,
            likesCount,
            iconColor: userLiked ? Colors.red : Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, int value, {Color? iconColor}) {
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

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
