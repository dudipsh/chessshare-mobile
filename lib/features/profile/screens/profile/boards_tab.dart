import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../models/profile_data.dart';

class BoardsTab extends StatelessWidget {
  final List<UserBoard> boards;
  final bool isLoading;
  final bool isDark;

  const BoardsTab({
    super.key,
    required this.boards,
    required this.isLoading,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (boards.isEmpty) {
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

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: boards.length,
      itemBuilder: (context, index) => _BoardCard(board: boards[index], isDark: isDark),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final UserBoard board;
  final bool isDark;

  const _BoardCard({required this.board, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: board.coverImageUrl != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(board.coverImageUrl!, fit: BoxFit.cover, width: double.infinity),
                    )
                  : const Center(child: Icon(Icons.dashboard, size: 40, color: AppColors.primary)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  board.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
    );
  }
}
